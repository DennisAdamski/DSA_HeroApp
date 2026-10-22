import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/gruppen_beitrittscode.dart';
import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';

/// Fehler der Gruppenverwaltung mit einer für Nutzer lesbaren Meldung.
class GruppenException implements Exception {
  /// Erstellt den Fehler.
  const GruppenException(this.message, {this.keinZugriff = false});

  /// Erklärung für die Oberfläche.
  final String message;

  /// `true`, wenn die Regeln den Zugriff verweigern (kein Mitglied mehr).
  final bool keinZugriff;

  @override
  String toString() => message;
}

/// Grunddaten einer Gruppe aus `groups_v2/{groupId}`.
class GruppenInfo {
  /// Erstellt die Gruppeninfo.
  const GruppenInfo({
    required this.groupId,
    required this.name,
    required this.ownerUid,
    required this.joinCode,
  });

  /// Dokument-ID der Gruppe.
  final String groupId;

  /// Anzeigename.
  final String name;

  /// UID des Gruppenerstellers.
  final String ownerUid;

  /// Geheimnis für den Beitritt; nur Mitglieder können es lesen.
  final String joinCode;

  /// Teilbarer Beitrittscode.
  GruppenBeitrittscode get beitrittscode =>
      GruppenBeitrittscode(groupId: groupId, joinCode: joinCode);
}

/// Heldenkarte eines Gruppenmitglieds, geordnet nach Konto-UID.
class GruppenMitgliedKarte {
  /// Erstellt die Zuordnung.
  const GruppenMitgliedKarte({required this.uid, required this.karte});

  /// UID des Mitglieds (Dokument-ID in `hero_snapshots`).
  final String uid;

  /// Visitenkarte des Helden, mit dem das Mitglied teilnimmt.
  final HeldVisitenkarte karte;
}

/// Alles, was eine Gruppe mit ihren Mitgliedern teilt.
class GruppenInhalt {
  /// Erstellt den Inhalt.
  const GruppenInhalt({required this.mitglieder, required this.geteilte});

  /// Heldenkarten der Mitglieder (`hero_snapshots`).
  final List<GruppenMitgliedKarte> mitglieder;

  /// Gemeinsame Einträge (`shared_heroes`), von allen Mitgliedern pflegbar.
  final List<HeldVisitenkarte> geteilte;
}

/// Firebase-Sync für Heldengruppen im UID-gebundenen Format `groups_v2`.
///
/// ```text
/// groups_v2/{groupId}            name, ownerUid, joinCode
///   members/{uid}                role, joinedAt
///   hero_snapshots/{uid}         Visitenkarte des eigenen Helden
///   shared_heroes/{entryId}      gemeinsame Einträge (alle Mitglieder)
///   shared_info/notizen          gemeinsame Gruppennotizen (alle Mitglieder)
///   shared_info/regelprofil      Regelprofil-Vorgabe (nur der Besitzer schreibt)
/// ```
///
/// Die Regeln in `firestore.rules` erzwingen die Rechte; der Dienst bildet nur
/// die Abläufe darauf ab. Das gesperrte Legacy-Format `gruppen/*` wird nie
/// angefasst.
class GruppenSyncService {
  /// Erstellt den Dienst; [firestore] und [uidProvider] sind Test-Hooks.
  GruppenSyncService({
    FirebaseFirestore? firestore,
    String? Function()? uidProvider,
    String Function()? idGenerator,
    String Function()? joinCodeGenerator,
  }) : _firestoreOverride = firestore,
       _uidQuelle = uidProvider,
       _neueId = idGenerator ?? (() => const Uuid().v4()),
       _neuerJoinCode =
           joinCodeGenerator ?? GruppenBeitrittscode.erzeugeJoinCode;

  final FirebaseFirestore? _firestoreOverride;
  final String? Function()? _uidQuelle;
  final String Function() _neueId;
  final String Function() _neuerJoinCode;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// UID des angemeldeten Kontos; wirft, wenn niemand angemeldet ist.
  String get eigeneUid {
    final provider = _uidQuelle;
    final uid = provider != null
        ? provider()
        : FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const GruppenException(
        'Für Gruppen ist eine Anmeldung mit bestätigter E-Mail nötig.',
      );
    }
    return uid;
  }

  DocumentReference<Map<String, dynamic>> _gruppe(String groupId) =>
      _firestore.collection('groups_v2').doc(groupId);

  // ---------------------------------------------------------------------------
  // Gruppe erstellen, beitreten, lesen
  // ---------------------------------------------------------------------------

  /// Erstellt eine Gruppe mit dem angemeldeten Konto als Besitzer.
  Future<GruppenInfo> erstelleGruppe(String gruppenName) async {
    final uid = eigeneUid;
    final groupId = _neueId();
    final joinCode = _neuerJoinCode();
    final gruppe = _gruppe(groupId);
    await _geschuetzt(
      () => gruppe.set(<String, dynamic>{
        'name': gruppenName.trim(),
        'ownerUid': uid,
        'joinCode': joinCode,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      'Die Gruppe konnte nicht erstellt werden.',
    );
    try {
      // Erst nach dem Gruppendokument: Die Regeln prüfen die Besitzer-UID dort.
      await _geschuetzt(
        () => gruppe.collection('members').doc(uid).set(<String, dynamic>{
          'role': 'owner',
          'joinedAt': FieldValue.serverTimestamp(),
        }),
        'Die Gruppe konnte nicht erstellt werden.',
      );
    } on Object {
      // Keine Gruppe ohne Besitzer-Mitgliedschaft zurücklassen.
      await gruppe.delete().catchError((Object _) {});
      rethrow;
    }
    return GruppenInfo(
      groupId: groupId,
      name: gruppenName.trim(),
      ownerUid: uid,
      joinCode: joinCode,
    );
  }

  /// Tritt der Gruppe mit dem Beitrittscode bei und liefert die Gruppeninfo.
  ///
  /// Ist das Konto bereits Mitglied, bleibt die Mitgliedschaft unverändert.
  Future<GruppenInfo> tritteBei(GruppenBeitrittscode code) async {
    final uid = eigeneUid;
    final gruppe = _gruppe(code.groupId);
    final mitglied = gruppe.collection('members').doc(uid);

    var bereitsMitglied = false;
    try {
      bereitsMitglied = (await mitglied.get()).exists;
    } on FirebaseException catch (error) {
      // Kein Mitglied: Die Regeln verweigern das Lesen. Beitritt folgt.
      if (error.code != 'permission-denied') rethrow;
    }

    if (!bereitsMitglied) {
      try {
        await mitglied.set(<String, dynamic>{
          'role': 'member',
          'joinCode': code.joinCode,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          throw const GruppenException(
            'Gruppe nicht gefunden oder der Beitrittscode ist ungültig.',
          );
        }
        rethrow;
      }
    }
    return ladeGruppe(code.groupId);
  }

  /// Liest Name, Besitzer und Beitrittsgeheimnis einer Gruppe.
  Future<GruppenInfo> ladeGruppe(String groupId) async {
    final snapshot = await _geschuetzt(
      () => _gruppe(groupId).get(),
      'Die Gruppe konnte nicht geladen werden.',
    );
    final daten = snapshot.data();
    if (!snapshot.exists || daten == null) {
      throw const GruppenException('Die Gruppe existiert nicht mehr.');
    }
    return GruppenInfo(
      groupId: groupId,
      name: daten['name'] as String? ?? '',
      ownerUid: daten['ownerUid'] as String? ?? '',
      joinCode: daten['joinCode'] as String? ?? '',
    );
  }

  /// Ersetzt das Beitrittsgeheimnis (nur Besitzer) und liefert die neue Form.
  ///
  /// Wer den alten Code kennt, kann der Gruppe danach nicht mehr beitreten.
  /// Bestehende Mitglieder bleiben.
  Future<GruppenBeitrittscode> erneuereBeitrittscode(String groupId) async {
    final joinCode = _neuerJoinCode();
    await _geschuetzt(
      () => _gruppe(groupId).update(<String, dynamic>{
        'joinCode': joinCode,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      'Nur der Gruppenersteller kann den Beitrittscode erneuern.',
    );
    return GruppenBeitrittscode(groupId: groupId, joinCode: joinCode);
  }

  // ---------------------------------------------------------------------------
  // Mitgliedschaft beenden
  // ---------------------------------------------------------------------------

  /// Verlässt die Gruppe: eigene Heldenkarte und Mitgliedschaft werden gelöscht.
  ///
  /// Der Besitzer kann nicht gehen, sondern nur [loescheGruppe].
  Future<void> verlasseGruppe(String groupId) async {
    final uid = eigeneUid;
    final gruppe = _gruppe(groupId);
    // Erst die Karte, solange die Mitgliedschaft noch die Rechte gibt.
    await _geschuetzt(
      () => gruppe.collection('hero_snapshots').doc(uid).delete(),
      'Die Gruppe konnte nicht verlassen werden.',
    );
    await _geschuetzt(
      () => gruppe.collection('members').doc(uid).delete(),
      'Der Gruppenersteller kann nur die ganze Gruppe löschen.',
    );
  }

  /// Entfernt ein Mitglied samt Heldenkarte (nur Besitzer).
  Future<void> entferneMitglied(String groupId, String uid) async {
    final gruppe = _gruppe(groupId);
    await _geschuetzt(
      () => gruppe.collection('hero_snapshots').doc(uid).delete(),
      'Nur der Gruppenersteller kann Mitglieder entfernen.',
    );
    await _geschuetzt(
      () => gruppe.collection('members').doc(uid).delete(),
      'Nur der Gruppenersteller kann Mitglieder entfernen.',
    );
  }

  /// Löscht die Gruppe samt Inhalten für alle Mitglieder (nur Besitzer).
  Future<void> loescheGruppe(String groupId) async {
    final uid = eigeneUid;
    final gruppe = _gruppe(groupId);
    for (final sammlung in const <String>[
      'hero_snapshots',
      'shared_heroes',
      'shared_info',
    ]) {
      final dokumente = await _geschuetzt(
        () => gruppe.collection(sammlung).get(),
        'Nur der Gruppenersteller kann die Gruppe löschen.',
      );
      for (final dokument in dokumente.docs) {
        await _geschuetzt(
          () => dokument.reference.delete(),
          'Nur der Gruppenersteller kann die Gruppe löschen.',
        );
      }
    }
    final mitglieder = await _geschuetzt(
      () => gruppe.collection('members').get(),
      'Nur der Gruppenersteller kann die Gruppe löschen.',
    );
    // Den Besitzereintrag zuletzt: Die Besitzerrechte hängen am Gruppendokument.
    for (final dokument in mitglieder.docs.where((d) => d.id != uid)) {
      await _geschuetzt(
        () => dokument.reference.delete(),
        'Nur der Gruppenersteller kann die Gruppe löschen.',
      );
    }
    await _geschuetzt(
      () => gruppe.collection('members').doc(uid).delete(),
      'Nur der Gruppenersteller kann die Gruppe löschen.',
    );
    await _geschuetzt(
      () => gruppe.delete(),
      'Nur der Gruppenersteller kann die Gruppe löschen.',
    );
  }

  // ---------------------------------------------------------------------------
  // Eigene Heldenkarte
  // ---------------------------------------------------------------------------

  /// Veröffentlicht die Visitenkarte des eigenen Helden in der Gruppe.
  ///
  /// Je Konto gibt es eine Karte pro Gruppe: Nimmt ein Konto mit mehreren
  /// Helden teil, zeigt die Gruppe den zuletzt gepushten.
  Future<void> pushVisitenkarte(String groupId, HeldVisitenkarte karte) {
    final uid = eigeneUid;
    return _geschuetzt(
      () =>
          _gruppe(groupId)
              .collection('hero_snapshots')
              .doc(uid)
              .set(karte.toFirestoreJson()),
      'Die Heldenkarte konnte nicht in die Gruppe übertragen werden.',
    );
  }

  // ---------------------------------------------------------------------------
  // Geteilte Gruppeninfos
  // ---------------------------------------------------------------------------

  /// Legt einen gemeinsamen Eintrag an oder ändert ihn; alle Mitglieder dürfen.
  ///
  /// Der Ersteller bleibt erhalten (die Regeln verbieten, ihn zu ändern).
  Future<void> pushGeteilterHeld(String groupId, HeldVisitenkarte karte) async {
    final uid = eigeneUid;
    final eintrag = _gruppe(groupId)
        .collection('shared_heroes')
        .doc(karte.heroId);
    final vorhanden = await _geschuetzt(
      () => eintrag.get(),
      'Der gemeinsame Eintrag konnte nicht gespeichert werden.',
    );
    final daten = karte.toFirestoreJson();
    if (vorhanden.exists) {
      await _geschuetzt(
        () => eintrag.update(daten),
        'Der gemeinsame Eintrag konnte nicht gespeichert werden.',
      );
      return;
    }
    await _geschuetzt(
      () => eintrag.set(<String, dynamic>{...daten, 'createdByUid': uid}),
      'Der gemeinsame Eintrag konnte nicht gespeichert werden.',
    );
  }

  /// Löscht einen gemeinsamen Eintrag für alle Mitglieder.
  Future<void> entferneGeteiltenHeld(String groupId, String entryId) {
    return _geschuetzt(
      () => _gruppe(groupId).collection('shared_heroes').doc(entryId).delete(),
      'Der gemeinsame Eintrag konnte nicht gelöscht werden.',
    );
  }

  /// Liest die gemeinsamen Gruppennotizen (leer, wenn es noch keine gibt).
  Future<String> ladeNotizen(String groupId) async {
    final snapshot = await _geschuetzt(
      () => _gruppe(groupId).collection('shared_info').doc('notizen').get(),
      'Die Gruppennotizen konnten nicht geladen werden.',
    );
    return snapshot.data()?['text'] as String? ?? '';
  }

  /// Speichert die gemeinsamen Gruppennotizen; alle Mitglieder dürfen.
  Future<void> speichereNotizen(String groupId, String text) {
    final uid = eigeneUid;
    return _geschuetzt(
      () => _gruppe(groupId)
          .collection('shared_info')
          .doc('notizen')
          .set(<String, dynamic>{
            'text': text,
            'updatedByUid': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }),
      'Die Gruppennotizen konnten nicht gespeichert werden.',
    );
  }

  // ---------------------------------------------------------------------------
  // Regelprofil-Vorgabe (ARCH-04)
  // ---------------------------------------------------------------------------

  DocumentReference<Map<String, dynamic>> _regelVorgabe(String groupId) =>
      _gruppe(groupId).collection('shared_info').doc('regelprofil');

  /// Liest die Regelprofil-Vorgabe der Gruppe.
  ///
  /// `null`, wenn die Gruppe keine Vorgabe hat oder sie sich nicht lesen lässt
  /// (beschädigt oder von einer neueren App-Version geschrieben). Das Profil
  /// liegt als JSON-Text im Dokument: Firestore erlaubt keine verschachtelten
  /// Listen, und die Paketkopien dürfen beliebige Patches tragen.
  Future<HeroRegelProfil?> ladeRegelVorgabe(String groupId) async {
    final snapshot = await _geschuetzt(
      () => _regelVorgabe(groupId).get(),
      'Die Regelprofil-Vorgabe der Gruppe konnte nicht geladen werden.',
    );
    final text = snapshot.data()?['profilJson'];
    if (text is! String || text.isEmpty) return null;
    try {
      final roh = jsonDecode(text);
      if (roh is! Map) return null;
      final profil = HeroRegelProfil.fromJson(Map<String, dynamic>.from(roh));
      return profil.istVerstanden ? profil : null;
    } on FormatException {
      return null;
    }
  }

  /// Setzt die Regelprofil-Vorgabe der Gruppe (nur Besitzer).
  Future<void> speichereRegelVorgabe(String groupId, HeroRegelProfil profil) {
    final uid = eigeneUid;
    return _geschuetzt(
      () => _regelVorgabe(groupId).set(<String, dynamic>{
        'profilJson': jsonEncode(profil.toJson()),
        'updatedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      'Nur der Gruppenersteller kann die Regelprofil-Vorgabe ändern.',
    );
  }

  /// Entfernt die Regelprofil-Vorgabe der Gruppe (nur Besitzer).
  ///
  /// Helden, die sie bereits übernommen haben, behalten ihr Profil.
  Future<void> entferneRegelVorgabe(String groupId) {
    return _geschuetzt(
      () => _regelVorgabe(groupId).delete(),
      'Nur der Gruppenersteller kann die Regelprofil-Vorgabe entfernen.',
    );
  }

  // ---------------------------------------------------------------------------
  // Abruf
  // ---------------------------------------------------------------------------

  /// Liest Heldenkarten der Mitglieder und gemeinsame Einträge einmalig.
  Future<GruppenInhalt> ladeInhalt(String groupId) async {
    final gruppe = _gruppe(groupId);
    final snapshots = await _geschuetzt(
      () => gruppe.collection('hero_snapshots').get(),
      'Die Gruppe konnte nicht abgerufen werden.',
    );
    final geteilt = await _geschuetzt(
      () => gruppe.collection('shared_heroes').get(),
      'Die Gruppe konnte nicht abgerufen werden.',
    );
    return GruppenInhalt(
      mitglieder: <GruppenMitgliedKarte>[
        for (final doc in snapshots.docs)
          GruppenMitgliedKarte(
            uid: doc.id,
            karte: _karteAus(doc.data(), fallbackId: doc.id),
          ),
      ],
      geteilte: <HeldVisitenkarte>[
        for (final doc in geteilt.docs)
          _karteAus(doc.data(), fallbackId: doc.id, manuell: true),
      ],
    );
  }

  // Der Dokument-Schluessel ist massgeblich: `heroId` im Datensatz koennte
  // von einem anderen Mitglied beliebig gesetzt sein.
  HeldVisitenkarte _karteAus(
    Map<String, dynamic> daten, {
    required String fallbackId,
    bool manuell = false,
  }) {
    final karte = HeldVisitenkarte.fromJson(<String, dynamic>{
      ...daten,
      if (manuell) 'heroId': fallbackId,
      if (manuell) 'istManuell': true,
    });
    if (karte.heroId.isNotEmpty) return karte;
    return HeldVisitenkarte.fromJson(<String, dynamic>{
      ...daten,
      'heroId': fallbackId,
    });
  }

  // Uebersetzt verweigerte Zugriffe in eine lesbare Meldung.
  Future<T> _geschuetzt<T>(Future<T> Function() aktion, String meldung) async {
    try {
      return await aktion();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw GruppenException(meldung, keinZugriff: true);
      }
      rethrow;
    }
  }
}
