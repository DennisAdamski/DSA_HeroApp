import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/sync/sync_konflikt_vorgang.dart';
import 'package:dsa_heldenverwaltung/data/vorgangsjournal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Schreibt Sync-Metadaten samt Basis (die Funktion des Repositorys).
typedef SyncMetadatenSchreiber = Future<void> Function({
  required SyncObjectKey key,
  required String localHash,
  required String remoteHash,
  required String remoteRevision,
  required bool isDeleted,
  Map<String, dynamic>? basis,
});

/// Reiht einen lokalen Schreibschritt hinter andere lokale Zugriffe auf [heroId].
typedef LokaleReihenfolge = Future<T> Function<T>(
  String heroId,
  Future<T> Function() vorgang,
);

/// Wie ein Lauf des Wiederanlaufs endete.
enum KonfliktAusgang {
  /// Alle Dokumente sind vollständig; der Journaleintrag ist entfernt.
  abgeschlossen,

  /// Eine weitere Änderung hält den Vorgang an; der Eintrag bleibt.
  blockiert,
}

/// Ergebnis eines Laufs.
class KonfliktLauf {
  /// Erzeugt das Ergebnis.
  const KonfliktLauf(this.ausgang, this.vorgang);

  /// Ausgang des Laufs.
  final KonfliktAusgang ausgang;

  /// Letzter bekannter Stand des Vorgangs (bei Blockade mit Blockade).
  final SyncKonfliktVorgang vorgang;
}

class _Blockiert implements Exception {
  const _Blockiert(this.grund);

  final String grund;
}

// Stand eines Online-Dokuments, einheitlich für Bogen und Zustand.
class _OnlineStand {
  const _OnlineStand({
    required this.revision,
    required this.hash,
    required this.hashHiesig,
    required this.geloescht,
  });

  final String revision;
  final String hash;
  final String? hashHiesig;
  final bool geloescht;
}

/// Führt einen [SyncKonfliktVorgang] wiederholbar zu Ende (ARCH-06).
///
/// Rechnet nichts fachlich: Zielfassungen stehen im Vorgang. Jeder Schritt
/// erkennt am **Inhalt** der Dokumente, ob er schon erledigt ist, und schreibt
/// online nur auf der geplanten Vorrevision. Netzfehler werden geworfen und
/// lassen den Vorgang unverändert im Journal; eine weitere Änderung ergibt
/// [KonfliktAusgang.blockiert], ohne etwas zu überschreiben.
class KonfliktWiederanlauf {
  /// Erzeugt den Ablauf.
  KonfliktWiederanlauf({
    required this.local,
    required this.remote,
    required this.stateRemote,
    required this.journal,
    required this.speichereMetadaten,
    required this.reiheLokalEin,
    DateTime Function()? uhr,
  }) : _uhr = uhr ?? DateTime.now;

  /// Lokaler Heldenspeicher (ohne Sync-Dekorator).
  final HeroRepository local;

  /// Online-Gateway für Bögen.
  final RemoteHeroSyncGateway remote;

  /// Online-Gateway für Zustände; `null`, wenn es keines gibt.
  final RemoteHeroStateSyncGateway? stateRemote;

  /// Journal, in dem der Fortschritt steht.
  final Vorgangsjournal journal;

  /// Schreibt Basis und Metadaten.
  final SyncMetadatenSchreiber speichereMetadaten;

  /// Reiht lokale Schreibzugriffe je Held ein.
  final LokaleReihenfolge reiheLokalEin;

  final DateTime Function() _uhr;

  /// Führt [start] aus, soweit es noch nicht erledigt ist.
  Future<KonfliktLauf> fuehreAus(SyncKonfliktVorgang start) async {
    var vorgang = start;
    Future<void> ersetze(int index, SyncKonfliktDokument dokument) async {
      final liste = List<SyncKonfliktDokument>.of(vorgang.dokumente);
      liste[index] = dokument;
      vorgang = vorgang.kopiere(dokumente: liste);
      await journal.merke(vorgang.id, vorgang.toJson());
    }

    try {
      // 1. Die Kopie liegt zuerst lokal: Bis dahin bleibt das Original
      //    unangetastet, die lokalen Daten also zurückholbar.
      for (var i = 0; i < vorgang.dokumente.length; i++) {
        if (vorgang.dokumente[i].istKopie) {
          await _lokal(vorgang.dokumente[i], (d) => ersetze(i, d));
        }
      }
      // 2. Original: online vor lokal, Bogen vor Zustand.
      for (var i = 0; i < vorgang.dokumente.length; i++) {
        if (!vorgang.dokumente[i].istKopie) {
          await _remote(vorgang.dokumente[i], (d) => ersetze(i, d));
          await _lokal(vorgang.dokumente[i], (d) => ersetze(i, d));
        }
      }
      // 3. Kopie online.
      for (var i = 0; i < vorgang.dokumente.length; i++) {
        if (vorgang.dokumente[i].istKopie) {
          await _remote(vorgang.dokumente[i], (d) => ersetze(i, d));
        }
      }
      // 4. Basis und Metadaten, erst wenn alle Dokumente vollständig sind.
      for (var i = 0; i < vorgang.dokumente.length; i++) {
        await _meta(vorgang.dokumente[i], (d) => ersetze(i, d));
      }
    } on _Blockiert catch (blockiert) {
      vorgang = vorgang.kopiere(
        blockade: SyncKonfliktBlockade(grund: blockiert.grund, seit: _uhr()),
      );
      await journal.merke(vorgang.id, vorgang.toJson());
      return KonfliktLauf(KonfliktAusgang.blockiert, vorgang);
    }
    // 5. Zuletzt: Erst jetzt ist die Entscheidung abgeschlossen.
    await journal.erledige(vorgang.id);
    return KonfliktLauf(KonfliktAusgang.abgeschlossen, vorgang);
  }

  // Legt die Zielfassung lokal ab, wenn der lokale Stand noch der Ausgangs-
  // fassung entspricht; eine dritte Fassung ist eine neue Nutzeränderung.
  Future<void> _lokal(
    SyncKonfliktDokument dokument,
    Future<void> Function(SyncKonfliktDokument) speichere,
  ) async {
    if (dokument.lokalErledigt) {
      return;
    }
    await reiheLokalEin<void>(dokument.id, () async {
      final aktuell = await _lokalerHash(dokument);
      if (aktuell == dokument.zielHash) {
        return;
      }
      if (aktuell == dokument.ausgangHash) {
        await _schreibeLokal(dokument);
        return;
      }
      if (dokument.istKopie) {
        // Eine Kopie, die der Nutzer inzwischen weiterbearbeitet hat, bleibt
        // wie sie ist; die Zielfassung geht online, die Änderung folgt als
        // gewöhnlicher Push.
        return;
      }
      throw const _Blockiert(SyncKonfliktBlockade.lokalGeaendert);
    });
    await speichere(dokument.kopiere(lokalErledigt: true));
  }

  Future<String?> _lokalerHash(SyncKonfliktDokument dokument) async {
    switch (dokument.art) {
      case SyncKonfliktDokumentArt.held:
        final held = await local.loadHeroById(dokument.id);
        return held == null ? null : heroContentHash(held);
      case SyncKonfliktDokumentArt.zustand:
        final zustand = await local.loadHeroState(dokument.id);
        return zustand == null ? null : heroStateContentHash(zustand);
    }
  }

  Future<void> _schreibeLokal(SyncKonfliktDokument dokument) {
    switch (dokument.art) {
      case SyncKonfliktDokumentArt.held:
        return local.saveHero(HeroSheet.fromJson(_kopie(dokument.ziel)));
      case SyncKonfliktDokumentArt.zustand:
        return local.saveHeroState(
          dokument.id,
          HeroState.fromJson(_kopie(dokument.ziel)),
        );
    }
  }

  // Legt die Zielfassung online ab. Entspricht der Online-Inhalt schon dem
  // Ziel (verlorene Antwort), gilt der Schritt als erledigt; sonst darf nur auf
  // der geplanten Vorrevision geschrieben werden.
  Future<void> _remote(
    SyncKonfliktDokument dokument,
    Future<void> Function(SyncKonfliktDokument) speichere,
  ) async {
    if (dokument.remoteErledigt) {
      return;
    }
    for (var versuch = 0; versuch < 2; versuch++) {
      final stand = await _ladeOnline(dokument);
      if (stand != null &&
          !stand.geloescht &&
          (stand.hash == dokument.zielHash ||
              stand.hashHiesig == dokument.zielHash)) {
        await speichere(
          dokument.kopiere(
            remoteErledigt: true,
            onlineRevision: stand.revision,
            onlineHash: stand.hash,
          ),
        );
        return;
      }
      if (stand?.revision != dokument.vorRevision) {
        throw const _Blockiert(SyncKonfliktBlockade.onlineGeaendert);
      }
      try {
        final gespeichert = await _schreibeOnline(dokument);
        await speichere(
          dokument.kopiere(
            remoteErledigt: true,
            onlineRevision: gespeichert.revision,
            onlineHash: gespeichert.hash,
          ),
        );
        return;
      } on SyncPreconditionException {
        // Zwischen Lesen und Schreiben hat jemand geschrieben: neu bewerten.
      }
    }
    throw const _Blockiert(SyncKonfliktBlockade.onlineGeaendert);
  }

  Future<_OnlineStand?> _ladeOnline(SyncKonfliktDokument dokument) async {
    switch (dokument.art) {
      case SyncKonfliktDokumentArt.held:
        final record = await remote.loadHero(dokument.id);
        if (record == null) {
          return null;
        }
        final held = record.hero;
        return _OnlineStand(
          revision: record.revision,
          hash: record.contentHash.isNotEmpty
              ? record.contentHash
              : (held == null ? '' : heroContentHash(held)),
          hashHiesig: held == null ? null : heroContentHash(held),
          geloescht: record.isDeleted,
        );
      case SyncKonfliktDokumentArt.zustand:
        final record = await _zustandGateway.loadHeroState(dokument.id);
        if (record == null) {
          return null;
        }
        final zustand = record.state;
        return _OnlineStand(
          revision: record.revision,
          hash: record.contentHash.isNotEmpty
              ? record.contentHash
              : (zustand == null ? '' : heroStateContentHash(zustand)),
          hashHiesig: zustand == null ? null : heroStateContentHash(zustand),
          geloescht: record.isDeleted,
        );
    }
  }

  Future<({String revision, String hash})> _schreibeOnline(
    SyncKonfliktDokument dokument,
  ) async {
    switch (dokument.art) {
      case SyncKonfliktDokumentArt.held:
        final gespeichert = await remote.saveHero(
          HeroSheet.fromJson(_kopie(dokument.ziel)),
          previousRevision: dokument.vorRevision,
        );
        return (revision: gespeichert.revision, hash: gespeichert.contentHash);
      case SyncKonfliktDokumentArt.zustand:
        final gespeichert = await _zustandGateway.saveHeroState(
          dokument.id,
          HeroState.fromJson(_kopie(dokument.ziel)),
          previousRevision: dokument.vorRevision,
        );
        return (revision: gespeichert.revision, hash: gespeichert.contentHash);
    }
  }

  RemoteHeroStateSyncGateway get _zustandGateway {
    final gateway = stateRemote;
    if (gateway == null) {
      throw StateError('Der Vorgang enthält einen Zustand ohne Gateway.');
    }
    return gateway;
  }

  // Führt Basis und Metadaten nach. `localHash` ist der Hash der Zielfassung,
  // nie der aktuelle lokale: Was der Nutzer danach noch ändert, bleibt so als
  // ausstehender Push erkennbar.
  Future<void> _meta(
    SyncKonfliktDokument dokument,
    Future<void> Function(SyncKonfliktDokument) speichere,
  ) async {
    if (dokument.metaErledigt) {
      return;
    }
    final revision = dokument.onlineRevision;
    if (revision != null) {
      final key = SyncObjectKey(
        type: dokument.art == SyncKonfliktDokumentArt.held
            ? SyncObjectType.hero
            : SyncObjectType.heroState,
        id: dokument.id,
      );
      if (dokument.onlineGeloescht) {
        await speichereMetadaten(
          key: key,
          localHash: '',
          remoteHash: '',
          remoteRevision: revision,
          isDeleted: true,
        );
      } else {
        await speichereMetadaten(
          key: key,
          localHash: dokument.zielHash,
          remoteHash: dokument.onlineHash ?? dokument.zielHash,
          remoteRevision: revision,
          isDeleted: false,
          basis: _kopie(dokument.ziel),
        );
      }
    }
    await speichere(dokument.kopiere(metaErledigt: true));
  }

  static Map<String, dynamic> _kopie(Map<String, dynamic> json) {
    return Map<String, dynamic>.of(json);
  }
}
