part of 'syncing_hero_repository.dart';

/// Dauerhafte Konfliktentscheidungen des Konto-Syncs (ARCH-06).
///
/// Eine Entscheidung über einen Helden betrifft mehrere Dokumente (Bogen,
/// Zustand, bei „Beide behalten“ zusätzlich die Kopie). Sie wird vor dem
/// ersten Schreibzugriff als [SyncKonfliktVorgang] im [Vorgangsjournal]
/// abgelegt und von [KonfliktWiederanlauf] über inhaltsgeprüfte, wiederholbare
/// Schritte vollendet. Bis dahin sind die betroffenen IDs für normalen Sync
/// gesperrt; Neustart, Netzfehler und verlorene Antworten verändern die
/// gewählte Fassung nicht.
extension _KonfliktVorgaenge on SyncingHeroRepository {
  /// Ob [id] gerade zu einer Konfliktentscheidung gehört.
  ///
  /// Ein Journaleintrag, dessen IDs sich nicht bestimmen lassen, sperrt
  /// vorsorglich jeden schreibenden Sync.
  bool _istGesperrt(String id) {
    return _gesperrteIds.contains(id) ||
        _laufendeEntscheidungen.containsKey(id) ||
        _unbekannteVorgaenge.values.any(
          (eintrag) => eintrag.reservierteIds.isEmpty,
        );
  }

  /// Vorgänge, die noch nicht abgeschlossen sind und nicht auf eine
  /// Nutzerentscheidung warten, sowie nicht ausführbare Einträge.
  int get _ausstehendeVorgaenge {
    final offen = _vorgaenge.values.where((v) => v.blockade == null).length;
    return offen + _unbekannteVorgaenge.length;
  }

  KonfliktWiederanlauf get _wiederanlauf {
    return KonfliktWiederanlauf(
      local: local,
      remote: remote,
      stateRemote: _stateRemote,
      journal: journal,
      speichereMetadaten: _saveMetadata,
      reiheLokalEin: <T>(heroId, vorgang) => _lokaleReihenfolge.reiheEin<T>(
        speicher: this,
        heroId: heroId,
        vorgang: vorgang,
      ),
    );
  }

  /// Liest das Journal und setzt die Sperren neu.
  ///
  /// Ein nicht lesbares Journal sperrt den schreibenden Sync, statt ihn ohne
  /// Kenntnis offener Vorgänge laufen zu lassen.
  Future<void> _ladeJournal() async {
    final vorgaenge = <String, SyncKonfliktVorgang>{};
    final unbekannt = <String, SyncKonfliktUnbekannt>{};
    try {
      final offene = await journal.offene();
      for (final MapEntry(key: id, value: eintrag) in offene.entries) {
        switch (SyncKonfliktVorgang.lies(id, eintrag, kontoId: accountId)) {
          case null:
            break;
          case SyncKonfliktGueltig(:final vorgang):
            vorgaenge[id] = vorgang;
          case final SyncKonfliktUnbekannt eintrag:
            unbekannt[id] = eintrag;
        }
      }
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'syncing_hero_repository',
          context: ErrorDescription('Vorgangsjournal nicht lesbar'),
        ),
      );
      unbekannt['journal'] = SyncKonfliktUnbekannt(
        journalId: 'journal',
        reservierteIds: const <String>{},
        grund: 'Das Vorgangsjournal ist nicht lesbar.',
      );
    }
    _vorgaenge
      ..clear()
      ..addAll(vorgaenge);
    _unbekannteVorgaenge
      ..clear()
      ..addAll(unbekannt);
    _berechneSperren();
  }

  // Leitet Sperren und Statuszahl aus dem gelesenen Journal ab.
  void _berechneSperren() {
    _gesperrteIds
      ..clear()
      ..addAll(<String>{
        for (final vorgang in _vorgaenge.values) ...vorgang.betroffeneIds,
        for (final eintrag in _unbekannteVorgaenge.values)
          ...eintrag.reservierteIds,
      });
    final anzahl = _ausstehendeVorgaenge;
    if (anzahl != _status.ausstehendeVorgaenge) {
      _emitStatus(_status.copyWith(ausstehendeVorgaenge: anzahl));
    }
  }

  /// Führt beim Abgleich zu Ende, was Konfliktentscheidungen offen ließen.
  ///
  /// Jeder Vorgang für sich: Ein Netzfehler oder Fehler in einem lässt die
  /// anderen weiterlaufen. Der Eintrag bleibt dann im Journal; der nächste
  /// Abgleich versucht denselben Vorgang erneut.
  Future<void> _nimmKonfliktVorgaengeAuf() async {
    await _journalBereit;
    await _ladeJournal();
    for (final eintrag in _unbekannteVorgaenge.values) {
      _melde(
        SyncFailure(
          kind: SyncErrorKind.unknown,
          message:
              'Ein Journaleintrag einer Konfliktentscheidung '
              '(${eintrag.journalId}) kann nicht ausgeführt werden: '
              '${eintrag.grund}',
          occurredAt: DateTime.now().toUtc(),
        ),
      );
    }
    for (final vorgang in List<SyncKonfliktVorgang>.of(_vorgaenge.values)) {
      if (_laufendeEntscheidungen.containsKey(vorgang.originalId)) {
        continue;
      }
      try {
        if (vorgang.blockade != null) {
          if (!_heroConflicts.containsKey(
            _heroConflictId(vorgang.originalId),
          )) {
            await _oeffneKonfliktAusVorgang(vorgang);
          }
          continue;
        }
        if (await _fuehreVorgangAus(vorgang)) {
          await _holeNachAbschluss(vorgang.betroffeneIds);
        }
      } on Object catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'syncing_hero_repository',
            context: ErrorDescription(
              'Konfliktentscheidung zu ${vorgang.originalId} konnte nicht '
              'abgeschlossen werden',
            ),
          ),
        );
        _melde(
          SyncFailure.fromError(error, occurredAt: DateTime.now().toUtc()),
        );
      }
    }
  }

  void _melde(SyncFailure fehler) {
    _emitStatus(_status.copyWith(lastFailure: fehler));
  }

  /// Entscheidet den Helden-Konflikt [details].
  ///
  /// `true`: ausgeführt und abgeschlossen. `false`: nicht ausgeführt, weil der
  /// Konflikt mit einem neueren Stand neu gestellt oder der Vorgang angehalten
  /// wurde. Netzfehler erreichen den Aufrufer; der Vorgang bleibt dann im
  /// Journal. Ein zweiter Aufruf während des ersten teilt dessen Ergebnis.
  Future<bool> _entscheideHeld(
    _HeroConflictDetails details,
    SyncKonfliktAktion aktion,
    Map<String, SyncSeite> entscheidungen,
  ) {
    final heroId = details.localHero.id;
    final laufend = _laufendeEntscheidungen[heroId];
    if (laufend != null) {
      return laufend;
    }
    final lauf = _entscheideHeldMitSperre(details, aktion, entscheidungen);
    _laufendeEntscheidungen[heroId] = lauf;
    return lauf;
  }

  Future<bool> _entscheideHeldMitSperre(
    _HeroConflictDetails details,
    SyncKonfliktAktion aktion,
    Map<String, SyncSeite> entscheidungen,
  ) async {
    final heroId = details.localHero.id;
    final ids = <String>{heroId};
    final bool erledigt;
    try {
      erledigt = await _entscheideHeldEinmal(
        details,
        aktion,
        entscheidungen,
        ids,
      );
    } finally {
      _laufendeEntscheidungen.remove(heroId);
    }
    if (erledigt) {
      await _holeNachAbschluss(ids);
    }
    return erledigt;
  }

  Future<bool> _entscheideHeldEinmal(
    _HeroConflictDetails details,
    SyncKonfliktAktion aktion,
    Map<String, SyncSeite> entscheidungen,
    Set<String> ids,
  ) async {
    final heroId = details.localHero.id;
    await _journalBereit;
    final record = details.remoteRecord;
    if (aktion == SyncKonfliktAktion.nurOnline &&
        (record.isDeleted || record.hero == null)) {
      // Online gelöscht: bewusst nicht Teil des Konfliktvertrags.
      await _uebernimmOnlineLoeschung(details);
      return true;
    }
    // Laufende Zustands-Uploads erst abwarten: Sie würden sonst die Online-
    // Revision verändern, auf der die Entscheidung geplant wird.
    await _zustandsUploads.warteAufAlle();
    final bestehender = _vorgaenge[SyncKonfliktVorgang.schluessel(heroId)];
    if (bestehender != null) {
      ids.addAll(bestehender.betroffeneIds);
      if (bestehender.blockade == null && bestehender.aktion == aktion) {
        // Wiederholung oder Doppelklick: der gesicherte Entschluss gilt.
        return _fuehreVorgangAus(bestehender);
      }
    }
    final vorgang = await _planeVorgang(
      details,
      aktion,
      entscheidungen,
      bestehender,
    );
    if (vorgang == null) {
      return false;
    }
    ids.addAll(vorgang.betroffeneIds);
    // Erst gesichert, dann geschrieben: Scheitert die Ablage, beginnt kein
    // Dokumentzugriff.
    await journal.merke(vorgang.id, vorgang.toJson());
    _vorgaenge[vorgang.id] = vorgang;
    _berechneSperren();
    return _fuehreVorgangAus(vorgang);
  }

  /// Führt [vorgang] aus. `true`, wenn er abgeschlossen ist.
  Future<bool> _fuehreVorgangAus(SyncKonfliktVorgang vorgang) async {
    final lauf = await _wiederanlauf.fuehreAus(vorgang);
    switch (lauf.ausgang) {
      case KonfliktAusgang.abgeschlossen:
        _vorgaenge.remove(vorgang.id);
        _berechneSperren();
        _boundStateConflicts.remove(vorgang.originalId);
        final conflictId = _heroConflictId(vorgang.originalId);
        _heroConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _removeConflictFromStatus(conflictId);
        return true;
      case KonfliktAusgang.blockiert:
        _vorgaenge[vorgang.id] = lauf.vorgang;
        _berechneSperren();
        await _oeffneKonfliktAusVorgang(lauf.vorgang);
        return false;
    }
  }

  /// Stellt den Konflikt zu einem angehaltenen Vorgang mit frischen Ständen.
  ///
  /// Beide Seiten stammen aus dem Hier und Jetzt; bereits online abgelegte
  /// Teile der früheren Entscheidung stehen dabei auf der Online-Seite. Der
  /// Journaleintrag bleibt als Sperre bestehen, bis neu entschieden ist.
  Future<void> _oeffneKonfliktAusVorgang(SyncKonfliktVorgang vorgang) async {
    final heroId = vorgang.originalId;
    final frisch = await remote.loadHero(heroId);
    if (frisch == null) {
      return;
    }
    final geladen = await local.loadHeroById(heroId);
    final lokalHeld =
        geladen ??
        HeroSheet.fromJson(
          Map<String, dynamic>.of(
            vorgang.dokumente
                .firstWhere(
                  (d) => d.art == SyncKonfliktDokumentArt.held && !d.istKopie,
                )
                .ziel,
          ),
        );
    final stateGateway = _stateRemote;
    final lokalZustand = await local.loadHeroState(heroId);
    final frischZustand = stateGateway == null
        ? null
        : await stateGateway.loadHeroState(heroId);
    final zustandStrittig =
        lokalZustand != null &&
        frischZustand != null &&
        (frischZustand.isDeleted ||
            frischZustand.state == null ||
            !isSyncContentIdentical(
              lokalZustand.toJson(),
              frischZustand.state!.toJson(),
            ));

    final onlineHeld = frisch.hero;
    if (!frisch.isDeleted &&
        onlineHeld != null &&
        geladen != null &&
        !zustandStrittig &&
        isSyncContentIdentical(geladen.toJson(), onlineHeld.toJson())) {
      // Beide Seiten stimmen inzwischen überein: nichts mehr zu entscheiden.
      await _adoptRemoteHero(onlineHeld, frisch, localHero: geladen);
      final onlineZustand = frischZustand?.state;
      if (frischZustand != null &&
          onlineZustand != null &&
          !frischZustand.isDeleted &&
          lokalZustand != null) {
        await _adoptRemoteState(
          heroId,
          onlineZustand,
          frischZustand,
          localState: lokalZustand,
        );
      }
      await journal.erledige(vorgang.id);
      _vorgaenge.remove(vorgang.id);
      _berechneSperren();
      return;
    }

    final conflictId = _heroConflictId(heroId);
    _heroConflicts.remove(conflictId);
    _conflictDiffCache.remove(conflictId);
    _boundStateConflicts.remove(heroId);
    _removeConflictFromStatus(conflictId);
    await _openHeroConflict(
      localHero: lokalHeld,
      remoteRecord: frisch,
      localTimestamp: lokalHeld.lastModified,
      hinweis: _blockadeHinweis(vorgang),
      ohneAutomatik: true,
    );
    if (zustandStrittig) {
      _boundStateConflicts[heroId] = _BoundStateConflict(
        localState: lokalZustand,
        remoteRecord: frischZustand,
      );
    }
  }

  String _blockadeHinweis(SyncKonfliktVorgang vorgang) {
    final aktion = switch (vorgang.aktion) {
      SyncKonfliktAktion.nurLokal => 'Nur Lokal',
      SyncKonfliktAktion.nurOnline => 'Nur Online',
      SyncKonfliktAktion.beideBehalten => 'Beide behalten',
      SyncKonfliktAktion.automatisch => 'Automatisch',
    };
    final grund = switch (vorgang.blockade?.grund) {
      SyncKonfliktBlockade.lokalGeaendert =>
        'dieser Held lokal weiter geändert wurde',
      SyncKonfliktBlockade.onlineGeaendert =>
        'er inzwischen online anderweitig geändert wurde',
      _ => 'sich die Daten inzwischen geändert haben',
    };
    return 'Die frühere Entscheidung „$aktion“ wurde nicht abgeschlossen, '
        'weil $grund. Bitte mit dem aktuellen Stand erneut entscheiden.';
  }

  /// Holt nach, was Listener während der Sperre verworfen haben.
  Future<void> _holeNachAbschluss(Set<String> ids) async {
    for (final id in ids) {
      try {
        final held = await remote.loadHero(id);
        if (held != null) {
          await _applyRemoteHeroRecord(held);
        }
        final stateGateway = _stateRemote;
        final zustand = stateGateway == null
            ? null
            : await stateGateway.loadHeroState(id);
        if (zustand != null) {
          await _applyRemoteStateRecord(zustand);
        }
      } on Object {
        // Der nächste Abgleich holt es nach.
      }
    }
  }

  // Meldet, dass sich der Online-Stand seit dem Anzeigen geändert hat.
  void _meldeGeaenderteOnlineFassung() {
    _melde(
      SyncFailure(
        kind: SyncErrorKind.conflict,
        message:
            'Der Online-Stand hat sich geändert. Bitte die Entscheidung mit '
            'dem aktuellen Stand erneut prüfen.',
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Plant die Entscheidung vollständig; `null`, wenn stattdessen der Konflikt
  /// mit einem neueren Stand neu gestellt wurde.
  Future<SyncKonfliktVorgang?> _planeVorgang(
    _HeroConflictDetails details,
    SyncKonfliktAktion aktion,
    Map<String, SyncSeite> entscheidungen,
    SyncKonfliktVorgang? bestehender,
  ) async {
    final heroId = details.localHero.id;
    final stateGateway = _stateRemote;
    final frischHeld = await remote.loadHero(heroId);
    final gebunden = _boundStateConflicts[heroId];
    final frischZustand = stateGateway == null
        ? null
        : await stateGateway.loadHeroState(heroId);

    // Hat sich online seit dem Anzeigen etwas geändert, entscheidet der
    // Nutzer erneut über den aktuellen Stand.
    if (frischHeld == null ||
        frischHeld.revision != details.remoteRecord.revision) {
      if (bestehender != null) {
        await _oeffneKonfliktAusVorgang(bestehender);
      } else if (frischHeld != null) {
        final conflictId = _heroConflictId(heroId);
        _heroConflicts.remove(conflictId);
        _conflictDiffCache.remove(conflictId);
        _boundStateConflicts.remove(heroId);
        _removeConflictFromStatus(conflictId);
        await _openHeroConflict(
          localHero: await local.loadHeroById(heroId) ?? details.localHero,
          remoteRecord: frischHeld,
          localTimestamp: details.localHero.lastModified,
        );
      }
      _meldeGeaenderteOnlineFassung();
      return null;
    }
    if (gebunden != null &&
        frischZustand != null &&
        frischZustand.revision != gebunden.remoteRecord.revision) {
      _boundStateConflicts[heroId] = _BoundStateConflict(
        localState: gebunden.localState,
        remoteRecord: frischZustand,
      );
      _meldeGeaenderteOnlineFassung();
      return null;
    }

    // Lokal frisch: Was der Nutzer seit dem Erkennen gespeichert hat, gehört
    // zur Entscheidung.
    final geladenerHeld = await local.loadHeroById(heroId);
    final heldAusgang = geladenerHeld == null
        ? null
        : heroContentHash(geladenerHeld);
    final lokalHeld = geladenerHeld ?? details.localHero;
    final geladenerZustand = await local.loadHeroState(heroId);
    final zustandAusgang = geladenerZustand == null
        ? null
        : heroStateContentHash(geladenerZustand);
    final lokalZustand = geladenerZustand ?? gebunden?.localState;

    final onlineHeld = frischHeld.isDeleted ? null : frischHeld.hero;
    final dokumente = <SyncKonfliktDokument>[];

    void lokalDurchsetzen() {
      dokumente.add(
        _heldOnlineSchreiben(
          lokalHeld,
          frischHeld,
          heldAusgang,
          lokalSchreiben: false,
        ),
      );
      if (stateGateway != null && lokalZustand != null) {
        dokumente.add(
          _zustandOnlineSchreiben(
            heroId,
            lokalZustand,
            frischZustand,
            zustandAusgang,
            lokalSchreiben: false,
          ),
        );
      }
    }

    void onlineUebernehmen() {
      dokumente.add(
        _heldOnlineUebernehmen(onlineHeld!, frischHeld, heldAusgang),
      );
      if (frischZustand != null) {
        dokumente.add(
          _zustandOnlineUebernehmen(heroId, frischZustand, zustandAusgang),
        );
      }
    }

    var kopieId = bestehender?.kopieId;
    switch (aktion) {
      case SyncKonfliktAktion.nurLokal:
        lokalDurchsetzen();
      case SyncKonfliktAktion.nurOnline:
        onlineUebernehmen();
      case SyncKonfliktAktion.beideBehalten:
        if (onlineHeld == null) {
          lokalDurchsetzen();
          break;
        }
        onlineUebernehmen();
        kopieId ??= const Uuid().v4();
        final kopie = lokalHeld.copyWith(
          id: kopieId,
          name: '${lokalHeld.name} (lokale Kopie)',
        );
        dokumente.add(
          SyncKonfliktDokument.plane(
            art: SyncKonfliktDokumentArt.held,
            id: kopie.id,
            ziel: kopie.toJson(),
            zielHash: heroContentHash(kopie),
            ausgangHash: null,
            lokalSchreiben: true,
            remoteSchreiben: true,
            istKopie: true,
          ),
        );
        // Der Zustand folgt seinem Helden: Die lokalen Laufzeitwerte gehören
        // zur Kopie, das Original trägt ab jetzt die Online-Werte.
        if (lokalZustand != null) {
          dokumente.add(
            SyncKonfliktDokument.plane(
              art: SyncKonfliktDokumentArt.zustand,
              id: kopie.id,
              ziel: lokalZustand.toJson(),
              zielHash: heroStateContentHash(lokalZustand),
              ausgangHash: null,
              lokalSchreiben: true,
              remoteSchreiben: stateGateway != null,
              istKopie: true,
            ),
          );
        }
      case SyncKonfliktAktion.automatisch:
        final plan = await _planeHeld(details, entscheidungen);
        _pruefePlan(plan);
        dokumente.add(
          _heldOnlineSchreiben(
            plan!.held!,
            frischHeld,
            heldAusgang,
            lokalSchreiben: true,
          ),
        );
        final zustand = plan.zustand;
        if (zustand != null) {
          dokumente.add(
            _zustandOnlineSchreiben(
              heroId,
              zustand,
              frischZustand,
              zustandAusgang,
              lokalSchreiben: true,
            ),
          );
        } else if (plan.zustandGanz == SyncSeite.lokal) {
          if (stateGateway != null && lokalZustand != null) {
            dokumente.add(
              _zustandOnlineSchreiben(
                heroId,
                lokalZustand,
                frischZustand,
                zustandAusgang,
                lokalSchreiben: false,
              ),
            );
          }
        } else if (plan.zustandGanz == SyncSeite.online) {
          if (frischZustand != null) {
            dokumente.add(
              _zustandOnlineUebernehmen(heroId, frischZustand, zustandAusgang),
            );
          }
        }
    }

    return SyncKonfliktVorgang(
      kontoId: accountId,
      begonnen: DateTime.now().toUtc(),
      originalId: heroId,
      kopieId: kopieId,
      aktion: aktion,
      dokumente: List<SyncKonfliktDokument>.unmodifiable(dokumente),
    );
  }

  // Bogen, der online durchgesetzt wird (lokale oder zusammengeführte Fassung).
  SyncKonfliktDokument _heldOnlineSchreiben(
    HeroSheet ziel,
    RemoteHeroRecord online,
    String? ausgangHash, {
    required bool lokalSchreiben,
  }) {
    final zielHash = heroContentHash(ziel);
    final gleich =
        !online.isDeleted &&
        (_remoteHeroHash(online) == zielHash ||
            (online.hero != null && heroContentHash(online.hero!) == zielHash));
    return SyncKonfliktDokument.plane(
      art: SyncKonfliktDokumentArt.held,
      id: ziel.id,
      ziel: ziel.toJson(),
      zielHash: zielHash,
      ausgangHash: ausgangHash,
      lokalSchreiben: lokalSchreiben,
      remoteSchreiben: !gleich,
      vorRevision: online.revision,
      onlineRevision: gleich ? online.revision : null,
      onlineHash: gleich ? _remoteHeroHash(online) : null,
    );
  }

  // Online-Bogen, der lokal übernommen wird.
  SyncKonfliktDokument _heldOnlineUebernehmen(
    HeroSheet onlineHeld,
    RemoteHeroRecord online,
    String? ausgangHash,
  ) {
    return SyncKonfliktDokument.plane(
      art: SyncKonfliktDokumentArt.held,
      id: onlineHeld.id,
      ziel: onlineHeld.toJson(),
      zielHash: heroContentHash(onlineHeld),
      ausgangHash: ausgangHash,
      lokalSchreiben: true,
      remoteSchreiben: false,
      onlineRevision: online.revision,
      onlineHash: _remoteHeroHash(online),
    );
  }

  // Zustand, der online durchgesetzt wird; ein fehlendes oder gelöschtes
  // Online-Dokument wird auf seiner Revision (oder neu) angelegt.
  SyncKonfliktDokument _zustandOnlineSchreiben(
    String heroId,
    HeroState ziel,
    RemoteHeroStateRecord? online,
    String? ausgangHash, {
    required bool lokalSchreiben,
  }) {
    final zielHash = heroStateContentHash(ziel);
    final gleich =
        online != null &&
        !online.isDeleted &&
        (_remoteStateHash(online) == zielHash ||
            (online.state != null &&
                heroStateContentHash(online.state!) == zielHash));
    return SyncKonfliktDokument.plane(
      art: SyncKonfliktDokumentArt.zustand,
      id: heroId,
      ziel: ziel.toJson(),
      zielHash: zielHash,
      ausgangHash: ausgangHash,
      lokalSchreiben: lokalSchreiben,
      remoteSchreiben: !gleich,
      vorRevision: online?.revision,
      onlineRevision: gleich ? online.revision : null,
      onlineHash: gleich ? _remoteStateHash(online) : null,
    );
  }

  // Online-Zustand, der lokal übernommen wird; ein Tombstone ergibt die leere
  // lokale Darstellung.
  SyncKonfliktDokument _zustandOnlineUebernehmen(
    String heroId,
    RemoteHeroStateRecord online,
    String? ausgangHash,
  ) {
    final zustand = online.state;
    final geloescht = online.isDeleted || zustand == null;
    final ziel = geloescht ? const HeroState.empty() : zustand;
    return SyncKonfliktDokument.plane(
      art: SyncKonfliktDokumentArt.zustand,
      id: heroId,
      ziel: ziel.toJson(),
      zielHash: heroStateContentHash(ziel),
      ausgangHash: ausgangHash,
      lokalSchreiben: true,
      remoteSchreiben: false,
      onlineRevision: online.revision,
      onlineHash: geloescht ? null : _remoteStateHash(online),
      onlineGeloescht: geloescht,
    );
  }
}
