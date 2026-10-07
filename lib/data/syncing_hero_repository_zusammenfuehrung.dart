part of 'syncing_hero_repository.dart';

/// Zusammengeführte Stände eines Konflikts samt offener Entscheidungen.
class _ZusammenfuehrungsPlan {
  const _ZusammenfuehrungsPlan({
    required this.held,
    required this.zustand,
    required this.zustandGanz,
    required this.felder,
    required this.vonLokal,
    required this.vonOnline,
  });

  /// Zusammengeführter Held oder `null` bei einem reinen Zustandskonflikt.
  final HeroSheet? held;

  /// Zusammengeführter Zustand oder `null`, wenn er nicht mitläuft oder nur
  /// als Ganzes gewählt werden kann ([zustandGanz]).
  final HeroState? zustand;

  /// Wahl für einen Zustand ohne Basis, der nur als Ganzes geht.
  final SyncSeite? zustandGanz;

  /// Offene echte Konflikte.
  final List<SyncKonfliktFeld> felder;

  final int vonLokal;
  final int vonOnline;
}

/// Schlüssel des Zustands, wenn er nur als Ganzes gewählt werden kann.
const String _zustandGanzSchluessel = 'zustand:';

/// Dreiwege-Zusammenführung im Sync (ARCH-06).
///
/// Ein Konflikt wird erst gestellt, wenn beide Seiten seit der Basis
/// verschieden geändert haben. Was sich ohne Widerspruch vereinen lässt,
/// führt der Sync still zusammen; was übrig bleibt, entscheidet der Nutzer je
/// Wert („Automatisch“) oder als Ganzes („Nur Online“, „Nur Lokal“, „Beide“).
extension _Zusammenfuehrung on SyncingHeroRepository {
  /// Basis zu [key], wenn sie zur gemerkten Revision gehört.
  Future<SyncBasis?> _gueltigeBasis(SyncObjectKey key) async {
    final metadata = await metadataStore.load(key);
    if (metadata == null || metadata.isDeleted) {
      return null;
    }
    final basis = await basisStore.lade(key);
    if (basis == null || basis.revision != metadata.remoteRevision) {
      return null;
    }
    return basis;
  }

  /// Trägt eine fehlende Basis nach, solange der lokale Stand dem
  /// abgeglichenen gleicht (Abgleiche aus der Zeit vor ARCH-06).
  Future<void> _ergaenzeBasis(
    SyncObjectKey key,
    SyncMetadata metadata,
    Map<String, dynamic> inhalt,
  ) async {
    final vorhanden = await basisStore.lade(key);
    if (vorhanden != null && vorhanden.revision == metadata.remoteRevision) {
      return;
    }
    await basisStore.merke(
      key,
      SyncBasis(revision: metadata.remoteRevision, inhalt: inhalt),
    );
  }

  /// Wie [_ergaenzeBasis] für den Zustand eines Helden.
  Future<void> _ergaenzeZustandsbasis(
    String heroId,
    HeroState state,
    RemoteHeroStateRecord record,
  ) async {
    final key = _stateKey(heroId);
    final metadata = await metadataStore.load(key);
    if (metadata == null ||
        metadata.isDeleted ||
        metadata.remoteRevision != record.revision ||
        metadata.localHash != heroStateContentHash(state)) {
      return;
    }
    await _ergaenzeBasis(key, metadata, state.toJson());
  }

  /// Führt Held [lokal] und [record] still zusammen, wenn kein Wert
  /// widersprüchlich geändert wurde. `true`, wenn erledigt.
  Future<bool> _fuehreHeldStillZusammen(
    HeroSheet lokal,
    RemoteHeroRecord record,
  ) async {
    final online = record.hero;
    if (record.isDeleted || online == null) {
      return false;
    }
    final basis = await _gueltigeBasis(_heroKey(lokal.id));
    if (basis == null) {
      return false;
    }
    final zusammen = fuehreSyncZusammen(
      basis: basis.inhalt,
      lokal: lokal.toJson(),
      online: online.toJson(),
      regeln: heldZusammenfuehrungsRegeln,
    );
    if (!zusammen.vollstaendig) {
      return false;
    }
    // Hat der Nutzer inzwischen weiter gespeichert, wird nichts
    // überschrieben; dann entscheidet der Konflikt.
    final frisch = await local.loadHeroById(lokal.id);
    if (frisch == null || heroContentHash(frisch) != heroContentHash(lokal)) {
      return false;
    }
    final held = HeroSheet.fromJson(zusammen.ergebnis);
    try {
      await _schreibeHeld(held, record, lokal: frisch);
    } on SyncPreconditionException {
      return false;
    }
    return true;
  }

  /// Wie [_fuehreHeldStillZusammen] für den Laufzeitzustand.
  Future<bool> _fuehreZustandStillZusammen(
    String heroId,
    HeroState lokal,
    RemoteHeroStateRecord record,
  ) async {
    final online = record.state;
    final gateway = _stateRemote;
    if (record.isDeleted || online == null || gateway == null) {
      return false;
    }
    final basis = await _gueltigeBasis(_stateKey(heroId));
    if (basis == null) {
      return false;
    }
    final zusammen = fuehreSyncZusammen(
      basis: basis.inhalt,
      lokal: lokal.toJson(),
      online: online.toJson(),
      regeln: zustandZusammenfuehrungsRegeln,
    );
    if (!zusammen.vollstaendig) {
      return false;
    }
    final frisch = await local.loadHeroState(heroId);
    if (frisch == null ||
        heroStateContentHash(frisch) != heroStateContentHash(lokal)) {
      return false;
    }
    try {
      await _schreibeZustand(
        heroId,
        HeroState.fromJson(zusammen.ergebnis),
        record,
        lokal: frisch,
      );
    } on SyncPreconditionException {
      return false;
    }
    return true;
  }

  /// Plant die Zusammenführung des Konflikts [conflictId] mit
  /// [entscheidungen]; `null`, wenn sie nicht möglich ist.
  ///
  /// Gerechnet wird mit dem **frisch** gespeicherten lokalen Stand: Was der
  /// Nutzer seit dem Erkennen des Konflikts gespeichert hat, gehört dazu.
  Future<_ZusammenfuehrungsPlan?> _planeZusammenfuehrung(
    String conflictId,
    Map<String, SyncSeite> entscheidungen,
  ) async {
    final heldKonflikt = _heroConflicts[conflictId];
    if (heldKonflikt != null) {
      return _planeHeld(heldKonflikt, entscheidungen);
    }
    final zustandKonflikt = _stateConflicts[conflictId];
    if (zustandKonflikt != null) {
      final heroId = zustandKonflikt.remoteRecord.heroId;
      final lokal =
          await local.loadHeroState(heroId) ?? zustandKonflikt.localState;
      final zustand = await _planeZustand(
        heroId,
        lokal,
        zustandKonflikt.remoteRecord,
        entscheidungen,
        mitPraefix: false,
      );
      if (zustand == null) {
        return null;
      }
      return _ZusammenfuehrungsPlan(
        held: null,
        zustand: zustand.vollstaendig
            ? HeroState.fromJson(zustand.ergebnis)
            : null,
        zustandGanz: null,
        felder: zustand.konflikte,
        vonLokal: zustand.vonLokal,
        vonOnline: zustand.vonOnline,
      );
    }
    return null;
  }

  Future<_ZusammenfuehrungsPlan?> _planeHeld(
    _HeroConflictDetails details,
    Map<String, SyncSeite> entscheidungen,
  ) async {
    final heroId = details.localHero.id;
    final online = details.remoteRecord.hero;
    if (details.remoteRecord.isDeleted || online == null) {
      return null;
    }
    final basis = await _gueltigeBasis(_heroKey(heroId));
    if (basis == null) {
      return null;
    }
    final lokal = await local.loadHeroById(heroId) ?? details.localHero;
    final held = fuehreSyncZusammen(
      basis: basis.inhalt,
      lokal: lokal.toJson(),
      online: online.toJson(),
      regeln: heldZusammenfuehrungsRegeln,
      entscheidungen: entscheidungen,
      praefix: 'held:',
    );
    final felder = <SyncKonfliktFeld>[...held.konflikte];
    var vonLokal = held.vonLokal;
    var vonOnline = held.vonOnline;

    HeroState? zustand;
    SyncSeite? zustandGanz;
    final gebunden = _boundStateConflicts[heroId];
    if (gebunden != null) {
      final lokalerZustand =
          await local.loadHeroState(heroId) ?? gebunden.localState;
      final zusammen = await _planeZustand(
        heroId,
        lokalerZustand,
        gebunden.remoteRecord,
        entscheidungen,
        mitPraefix: true,
      );
      if (zusammen != null) {
        felder.addAll(zusammen.konflikte);
        vonLokal += zusammen.vonLokal;
        vonOnline += zusammen.vonOnline;
        if (zusammen.vollstaendig) {
          zustand = HeroState.fromJson(zusammen.ergebnis);
        }
      } else {
        // Ohne Basis lässt sich der Zustand nur als Ganzes wählen.
        zustandGanz = entscheidungen[_zustandGanzSchluessel];
        if (zustandGanz == null) {
          felder.add(
            const SyncKonfliktFeld(
              schluessel: _zustandGanzSchluessel,
              pfad: <String>['Zustand'],
              online: 'Online-Laufzeitwerte',
              lokal: 'Lokale Laufzeitwerte',
            ),
          );
        }
      }
    }
    return _ZusammenfuehrungsPlan(
      held: held.vollstaendig ? HeroSheet.fromJson(held.ergebnis) : null,
      zustand: zustand,
      zustandGanz: zustandGanz,
      felder: List<SyncKonfliktFeld>.unmodifiable(felder),
      vonLokal: vonLokal,
      vonOnline: vonOnline,
    );
  }

  // Zusammenführung eines Zustands; `null` ohne Basis oder Online-Stand.
  // Beim Helden mitgeführte Felder tragen den Präfix `zustand:` und im
  // Anzeigepfad „Zustand“.
  Future<SyncZusammenfuehrung?> _planeZustand(
    String heroId,
    HeroState lokal,
    RemoteHeroStateRecord record,
    Map<String, SyncSeite> entscheidungen, {
    required bool mitPraefix,
  }) async {
    final online = record.state;
    if (record.isDeleted || online == null) {
      return null;
    }
    final basis = await _gueltigeBasis(_stateKey(heroId));
    if (basis == null) {
      return null;
    }
    final zusammen = fuehreSyncZusammen(
      basis: basis.inhalt,
      lokal: lokal.toJson(),
      online: online.toJson(),
      regeln: zustandZusammenfuehrungsRegeln,
      entscheidungen: entscheidungen,
      praefix: 'zustand:',
    );
    if (!mitPraefix) {
      return zusammen;
    }
    return SyncZusammenfuehrung(
      ergebnis: zusammen.ergebnis,
      konflikte: <SyncKonfliktFeld>[
        for (final feld in zusammen.konflikte)
          SyncKonfliktFeld(
            schluessel: feld.schluessel,
            pfad: <String>['Zustand', ...feld.pfad],
            online: feld.online,
            lokal: feld.lokal,
            onlineFehlt: feld.onlineFehlt,
            lokalFehlt: feld.lokalFehlt,
          ),
      ],
      vonLokal: zusammen.vonLokal,
      vonOnline: zusammen.vonOnline,
    );
  }

  /// „Automatisch“ für einen Helden-Konflikt samt gebundenem Zustand.
  Future<void> _loeseHeldAutomatisch(
    _HeroConflictDetails details,
    Map<String, SyncSeite> entscheidungen,
  ) async {
    final plan = await _planeHeld(details, entscheidungen);
    _pruefePlan(plan);
    final heroId = details.localHero.id;
    await _schreibeHeld(plan!.held!, details.remoteRecord);
    final zustand = plan.zustand;
    if (zustand != null) {
      await local.saveHeroState(heroId, zustand);
      await _pushLocalStateWithHero(heroId, localState: zustand);
    } else if (plan.zustandGanz == SyncSeite.lokal) {
      await _pushLocalStateWithHero(
        heroId,
        localState: await _localStateForHero(heroId),
      );
    } else if (plan.zustandGanz == SyncSeite.online) {
      await _adoptRemoteStateWithHero(heroId);
    }
  }

  /// „Automatisch“ für einen eigenständigen Zustands-Konflikt.
  Future<void> _loeseZustandAutomatisch(
    _StateConflictDetails details,
    Map<String, SyncSeite> entscheidungen,
  ) async {
    final heroId = details.remoteRecord.heroId;
    final plan = await _planeZusammenfuehrung(
      _stateConflictId(heroId),
      entscheidungen,
    );
    _pruefePlan(plan);
    await _schreibeZustand(heroId, plan!.zustand!, details.remoteRecord);
  }

  void _pruefePlan(_ZusammenfuehrungsPlan? plan) {
    if (plan == null) {
      throw StateError(
        'Für diesen Konflikt fehlt der gemeinsame Ausgangsstand; bitte '
        '„Nur Online“, „Nur Lokal“ oder „Beide behalten“ wählen.',
      );
    }
    if (plan.felder.isNotEmpty) {
      throw StateError(
        'Noch nicht alle widersprüchlichen Werte sind entschieden.',
      );
    }
  }

  /// Schreibt den zusammengeführten Helden online (auf Basis von [record])
  /// und lokal und merkt ihn als neue Basis.
  Future<void> _schreibeHeld(
    HeroSheet held,
    RemoteHeroRecord record, {
    HeroSheet? lokal,
  }) async {
    final online = record.hero;
    var gespeichert = record;
    if (online == null || heroContentHash(online) != heroContentHash(held)) {
      gespeichert = await remote.saveHero(
        held,
        previousRevision: record.revision,
      );
    }
    final vorher = lokal ?? await local.loadHeroById(held.id);
    if (vorher == null || heroContentHash(vorher) != heroContentHash(held)) {
      await local.saveHero(held);
    }
    await _storeHeroMetadata(held, gespeichert);
  }

  /// Wie [_schreibeHeld] für den Laufzeitzustand.
  Future<void> _schreibeZustand(
    String heroId,
    HeroState zustand,
    RemoteHeroStateRecord record, {
    HeroState? lokal,
  }) async {
    final gateway = _stateRemote!;
    final online = record.state;
    var gespeichert = record;
    if (online == null ||
        heroStateContentHash(online) != heroStateContentHash(zustand)) {
      gespeichert = await gateway.saveHeroState(
        heroId,
        zustand,
        previousRevision: record.revision,
      );
    }
    final vorher = lokal ?? await local.loadHeroState(heroId);
    if (vorher == null ||
        heroStateContentHash(vorher) != heroStateContentHash(zustand)) {
      await local.saveHeroState(heroId, zustand);
    }
    await _storeStateMetadata(heroId, zustand, gespeichert);
  }
}
