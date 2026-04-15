import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/data/hive_externe_helden_repository.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';

/// Firebase-Sync-Service fuer Heldengruppen.
///
/// Verwaltet die Firestore-Collection `gruppen/{gruppenCode}/mitglieder`
/// und synchronisiert Visitenkarten zwischen Geraeten.
class GruppenSyncService {
  GruppenSyncService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _uuid = Uuid();

  /// Aktive Listener pro gruppenCode.
  final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
  _activeListeners = {};

  // ---------------------------------------------------------------------------
  // Gruppe erstellen / pruefen
  // ---------------------------------------------------------------------------

  /// Erstellt eine neue Gruppe in Firestore und gibt den gruppenCode zurueck.
  Future<String> erstelleGruppe(String gruppenName) async {
    final gruppenCode = _uuid.v4();
    await _firestore.collection('gruppen').doc(gruppenCode).set({
      'gruppenName': gruppenName,
      'erstelltAm': FieldValue.serverTimestamp(),
    });
    return gruppenCode;
  }

  /// Prueft, ob eine Gruppe mit dem angegebenen Code in Firestore existiert.
  Future<bool> gruppeExistiert(String gruppenCode) async {
    final doc = await _firestore.collection('gruppen').doc(gruppenCode).get();
    return doc.exists;
  }

  /// Liest den Gruppennamen aus Firestore.
  Future<String> ladeGruppenName(String gruppenCode) async {
    final doc = await _firestore.collection('gruppen').doc(gruppenCode).get();
    final data = doc.data();
    return data?['gruppenName'] as String? ?? '';
  }

  // ---------------------------------------------------------------------------
  // Visitenkarte pushen / entfernen
  // ---------------------------------------------------------------------------

  /// Pusht die Visitenkarte eines lokalen Helden in eine Firestore-Gruppe.
  Future<void> pushVisitenkarte(
    String gruppenCode,
    HeldVisitenkarte karte,
  ) async {
    await _firestore
        .collection('gruppen')
        .doc(gruppenCode)
        .collection('mitglieder')
        .doc(karte.heroId)
        .set(karte.toFirestoreJson());
  }

  /// Entfernt einen Helden aus einer Firestore-Gruppe.
  Future<void> leaveGruppe(String gruppenCode, String heroId) async {
    await _firestore
        .collection('gruppen')
        .doc(gruppenCode)
        .collection('mitglieder')
        .doc(heroId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // One-Shot-Abfrage
  // ---------------------------------------------------------------------------

  /// Liest alle Mitglieder einer Gruppe als One-Shot-Abfrage.
  Future<List<HeldVisitenkarte>> fetchMitglieder(String gruppenCode) async {
    final snapshot = await _firestore
        .collection('gruppen')
        .doc(gruppenCode)
        .collection('mitglieder')
        .get();
    return snapshot.docs
        .map((doc) => HeldVisitenkarte.fromJson(doc.data()))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Echtzeit-Listener
  // ---------------------------------------------------------------------------

  /// Startet einen Echtzeit-Listener fuer eine Gruppe.
  ///
  /// Empfangene Mitglieder (ausser dem eigenen Helden) werden als
  /// [ExternerHeld] in das [externeHeldenRepo] geschrieben.
  ///
  /// Gibt die Listener-Subscription zurueck (wird intern auch gespeichert).
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>> listenToGruppe(
    String gruppenCode, {
    required HiveExterneHeldenRepository externeHeldenRepo,
    required String eigenerHeroId,
  }) {
    // Falls bereits ein Listener aktiv ist, diesen zuerst stoppen.
    _activeListeners[gruppenCode]?.cancel();

    final subscription = _firestore
        .collection('gruppen')
        .doc(gruppenCode)
        .collection('mitglieder')
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            if (data == null) continue;

            final heroId = data['heroId'] as String? ?? change.doc.id;
            if (heroId == eigenerHeroId) continue;

            if (change.type == DocumentChangeType.removed) {
              // Entfernter Held — nur aus lokalem Cache loeschen, wenn keine
              // andere Gruppe ihn referenziert. Das kann der Caller steuern.
              continue;
            }

            // Visitenkarte als ExternerHeld speichern.
            final karte = HeldVisitenkarte.fromJson(data);
            final externer = ExternerHeld.fromVisitenkarte(karte);
            externeHeldenRepo.save(externer);
          }
        });

    _activeListeners[gruppenCode] = subscription;
    return subscription;
  }

  /// Stoppt den Listener fuer eine bestimmte Gruppe.
  Future<void> stopListenerFuerGruppe(String gruppenCode) async {
    await _activeListeners.remove(gruppenCode)?.cancel();
  }

  /// Stoppt alle aktiven Listener.
  Future<void> stopAlleListener() async {
    for (final sub in _activeListeners.values) {
      await sub.cancel();
    }
    _activeListeners.clear();
  }

  /// Gibt Ressourcen frei.
  Future<void> dispose() async {
    await stopAlleListener();
  }
}
