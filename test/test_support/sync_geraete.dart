import 'dart:convert';

import 'package:dsa_heldenverwaltung/data/sync/in_memory_sync_metadata_store.dart';
import 'package:dsa_heldenverwaltung/data/sync/remote_hero_sync_gateway.dart';
import 'package:dsa_heldenverwaltung/data/sync/sync_basis_store.dart';
import 'package:dsa_heldenverwaltung/data/syncing_hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';

import 'fake_remote_hero_sync_gateway.dart';

/// In-Memory-Cloud, an der mehrere simulierte Geraete haengen.
///
/// Zaehlt jeden Schreibvorgang je ID, damit Tests nachweisen koennen, dass
/// eine Wiederholung nichts doppelt bucht.
class GeteilteCloud extends FakeRemoteHeroAndStateSyncGateway {
  /// Schreibvorgaenge (Speichern oder Loeschen) je Helden-ID.
  final Map<String, int> heldSchreibvorgaenge = <String, int>{};

  /// Schreibvorgaenge je Helden-ID fuer Zustandsdokumente.
  final Map<String, int> zustandSchreibvorgaenge = <String, int>{};

  /// Summe aller Schreibvorgaenge, fuer „nichts mehr geschrieben“.
  int get schreibvorgaenge {
    final helden = heldSchreibvorgaenge.values.fold(0, (a, b) => a + b);
    final zustaende = zustandSchreibvorgaenge.values.fold(0, (a, b) => a + b);
    return helden + zustaende;
  }

  // Zaehlt einen erfolgreichen Schreibvorgang.
  void _zaehle(Map<String, int> zaehler, String id) {
    zaehler[id] = (zaehler[id] ?? 0) + 1;
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    final record = await super.saveHero(
      hero,
      previousRevision: previousRevision,
    );
    _zaehle(heldSchreibvorgaenge, hero.id);
    return record;
  }

  @override
  Future<RemoteHeroRecord> speichereFremdenStand(
    Map<String, dynamic> heldJson, {
    required String? previousRevision,
  }) async {
    final record = await super.speichereFremdenStand(
      heldJson,
      previousRevision: previousRevision,
    );
    _zaehle(heldSchreibvorgaenge, record.id);
    return record;
  }

  @override
  Future<RemoteHeroRecord> deleteHero(
    String heroId, {
    required String? previousRevision,
  }) async {
    final record = await super.deleteHero(
      heroId,
      previousRevision: previousRevision,
    );
    _zaehle(heldSchreibvorgaenge, heroId);
    return record;
  }

  @override
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  }) async {
    final record = await super.saveHeroState(
      heroId,
      state,
      previousRevision: previousRevision,
    );
    _zaehle(zustandSchreibvorgaenge, heroId);
    return record;
  }

  @override
  Future<RemoteHeroStateRecord> speichereFremdenZustand(
    String heroId,
    Map<String, dynamic> zustandJson, {
    required String? previousRevision,
  }) async {
    final record = await super.speichereFremdenZustand(
      heroId,
      zustandJson,
      previousRevision: previousRevision,
    );
    _zaehle(zustandSchreibvorgaenge, heroId);
    return record;
  }

  @override
  Future<RemoteHeroStateRecord> deleteHeroState(
    String heroId, {
    required String? previousRevision,
  }) async {
    final record = await super.deleteHeroState(
      heroId,
      previousRevision: previousRevision,
    );
    _zaehle(zustandSchreibvorgaenge, heroId);
    return record;
  }
}

/// Netzanbindung eines Geraets an die [GeteilteCloud] mit Stoerungen.
///
/// Nutzdaten gehen wie bei Firestore als JSON ueber die Leitung: Geladene
/// Helden und Zustaende entstehen per `fromJson` neu.
class GeraeteRemote
    implements RemoteHeroSyncGateway, RemoteHeroStateSyncGateway {
  /// Verbindet ein Geraet mit [cloud].
  GeraeteRemote(this.cloud);

  /// Gemeinsamer Cloud-Speicher aller Geraete.
  final GeteilteCloud cloud;

  /// Jeder Zugriff scheitert mit einem Netzwerkfehler.
  bool offline = false;

  /// Anzahl Schreibvorgaenge, die noch gelingen; danach bricht die Leitung
  /// ab. `null` bedeutet unbegrenzt.
  int? schreibvorgaengeBisAbbruch;

  /// Der naechste Schreibvorgang erreicht die Cloud, seine Antwort aber
  /// nicht das Geraet (Zeitueberschreitung nach dem Commit).
  bool naechsteAntwortVerlieren = false;

  // Wirft bei getrennter Leitung.
  void _pruefeLeitung() {
    if (offline) {
      throw const SyncNetworkException('Cloud nicht erreichbar');
    }
  }

  // Prueft Leitung und Abbruchzaehler vor einem Schreibvorgang.
  void _vorSchreiben() {
    _pruefeLeitung();
    final rest = schreibvorgaengeBisAbbruch;
    if (rest == null) {
      return;
    }
    if (rest <= 0) {
      throw const SyncNetworkException('Verbindung abgebrochen');
    }
    schreibvorgaengeBisAbbruch = rest - 1;
  }

  // Liefert die Antwort eines Schreibvorgangs oder verliert sie.
  T _nachSchreiben<T>(T antwort) {
    if (naechsteAntwortVerlieren) {
      naechsteAntwortVerlieren = false;
      throw const SyncNetworkException('Zeitüberschreitung');
    }
    return antwort;
  }

  @override
  Future<List<RemoteHeroRecord>> loadAllHeroes() async {
    _pruefeLeitung();
    final records = await cloud.loadAllHeroes();
    return records.map(_ueberLeitung).toList(growable: false);
  }

  @override
  Future<RemoteHeroRecord?> loadHero(String heroId) async {
    _pruefeLeitung();
    final record = await cloud.loadHero(heroId);
    return record == null ? null : _ueberLeitung(record);
  }

  @override
  Future<RemoteHeroRecord> saveHero(
    HeroSheet hero, {
    required String? previousRevision,
  }) async {
    _vorSchreiben();
    final record = await cloud.saveHero(
      hero,
      previousRevision: previousRevision,
    );
    return _nachSchreiben(_ueberLeitung(record));
  }

  @override
  Future<RemoteHeroRecord> deleteHero(
    String heroId, {
    required String? previousRevision,
  }) async {
    _vorSchreiben();
    final record = await cloud.deleteHero(
      heroId,
      previousRevision: previousRevision,
    );
    return _nachSchreiben(record);
  }

  @override
  Stream<List<RemoteHeroRecord>> watchHeroes() {
    return const Stream<List<RemoteHeroRecord>>.empty();
  }

  @override
  Future<List<RemoteHeroStateRecord>> loadAllHeroStates() async {
    _pruefeLeitung();
    final records = await cloud.loadAllHeroStates();
    return records.map(_zustandUeberLeitung).toList(growable: false);
  }

  @override
  Future<RemoteHeroStateRecord?> loadHeroState(String heroId) async {
    _pruefeLeitung();
    final record = await cloud.loadHeroState(heroId);
    return record == null ? null : _zustandUeberLeitung(record);
  }

  @override
  Future<RemoteHeroStateRecord> saveHeroState(
    String heroId,
    HeroState state, {
    required String? previousRevision,
  }) async {
    _vorSchreiben();
    final record = await cloud.saveHeroState(
      heroId,
      state,
      previousRevision: previousRevision,
    );
    return _nachSchreiben(_zustandUeberLeitung(record));
  }

  @override
  Future<RemoteHeroStateRecord> deleteHeroState(
    String heroId, {
    required String? previousRevision,
  }) async {
    _vorSchreiben();
    final record = await cloud.deleteHeroState(
      heroId,
      previousRevision: previousRevision,
    );
    return _nachSchreiben(record);
  }

  @override
  Stream<List<RemoteHeroStateRecord>> watchHeroStates() {
    return const Stream<List<RemoteHeroStateRecord>>.empty();
  }
}

// Serialisiert einen Helden-Datensatz wie Firestore ueber JSON.
RemoteHeroRecord _ueberLeitung(RemoteHeroRecord record) {
  final hero = record.hero;
  return RemoteHeroRecord(
    id: record.id,
    hero: hero == null ? null : heldUeberJson(hero),
    revision: record.revision,
    contentHash: record.contentHash,
    isDeleted: record.isDeleted,
    updatedAt: record.updatedAt,
  );
}

// Serialisiert einen Zustands-Datensatz wie Firestore ueber JSON.
RemoteHeroStateRecord _zustandUeberLeitung(RemoteHeroStateRecord record) {
  final state = record.state;
  return RemoteHeroStateRecord(
    heroId: record.heroId,
    state: state == null ? null : zustandUeberJson(state),
    revision: record.revision,
    contentHash: record.contentHash,
    isDeleted: record.isDeleted,
    updatedAt: record.updatedAt,
  );
}

/// Schickt einen Helden einmal durch `toJson`/`fromJson`, wie Hive und
/// Firestore es tun.
HeroSheet heldUeberJson(HeroSheet hero) {
  final json = jsonDecode(jsonEncode(hero.toJson())) as Map<String, dynamic>;
  return HeroSheet.fromJson(json);
}

/// Wie [heldUeberJson] fuer den Laufzeitzustand.
HeroState zustandUeberJson(HeroState state) {
  final json = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
  return HeroState.fromJson(json);
}

/// Lokaler Speicher, der wie Hive nur JSON haelt.
///
/// `FakeRepository` gaebe dieselbe Objektinstanz zurueck; Hive dagegen
/// laedt jeden Helden per `fromJson` neu, und genau dabei greifen die
/// Kompatibilitaetspfade (Befund ARCH-07-B1 fiel erst dadurch im Sync auf).
class JsonHeroRepository extends FakeRepository {
  @override
  Future<void> saveHero(HeroSheet hero) => super.saveHero(heldUeberJson(hero));

  @override
  Future<void> saveHeroState(String heroId, HeroState state) {
    return super.saveHeroState(heroId, zustandUeberJson(state));
  }
}

/// Ein simuliertes Geraet mit eigenem lokalen Speicher und Sync-Metadaten.
class SyncTestGeraet {
  /// Verbindet ein neues, leeres Geraet mit [cloud].
  SyncTestGeraet(GeteilteCloud cloud) : remote = GeraeteRemote(cloud) {
    _verbinde();
  }

  /// Netzanbindung mit steuerbaren Stoerungen.
  final GeraeteRemote remote;

  /// Lokaler Heldenspeicher; ueberlebt [neustart].
  final JsonHeroRepository lokal = JsonHeroRepository();

  /// Lokale Sync-Metadaten; ueberleben [neustart].
  final InMemorySyncMetadataStore metadaten = InMemorySyncMetadataStore();

  /// Basisstaende fuer die Zusammenfuehrung; ueberleben [neustart].
  final SpeicherSyncBasisStore basis = SpeicherSyncBasisStore();

  /// Das Repository, das die App an dieser Stelle benutzt.
  late SyncingHeroRepository repo;

  // Baut das Sync-Repository wie der App-Start ohne Live-Listener.
  void _verbinde() {
    repo = SyncingHeroRepository(
      local: lokal,
      remote: remote,
      metadataStore: metadaten,
      basisStore: basis,
      accountId: 'konto-1',
      startRemoteListener: false,
    );
  }

  /// Simuliert einen App-Neustart: Speicher bleiben, offene Konflikte und
  /// Statusmeldungen (nur im Speicher) gehen verloren.
  Future<void> neustart() async {
    await repo.close();
    _verbinde();
  }

  /// Offene Konflikte laut Sync-Status.
  List<SyncConflict> get konflikte => repo.currentStatus.openConflicts;

  /// Inhalts-Hash des lokal gespeicherten Helden.
  Future<String> heldHash(String heroId) async {
    return heroContentHash((await lokal.loadHeroById(heroId))!);
  }
}
