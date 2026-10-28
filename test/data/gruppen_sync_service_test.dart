import 'dart:convert';
import 'dart:math';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/domain/gruppen_beitrittscode.dart';
import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';

HeldVisitenkarte _karte(String heroId, {String name = 'Alrik'}) {
  return HeldVisitenkarte(
    heroId: heroId,
    name: name,
    exportedAt: DateTime.utc(2026, 1, 1),
  );
}

GruppenSyncService _dienst(
  FakeFirebaseFirestore firestore,
  String uid, {
  List<String> ids = const <String>[],
  List<String> codes = const <String>[],
}) {
  final idQueue = List<String>.of(ids);
  final codeQueue = List<String>.of(codes);
  return GruppenSyncService(
    firestore: firestore,
    uidProvider: () => uid,
    idGenerator: () => idQueue.removeAt(0),
    joinCodeGenerator: () => codeQueue.removeAt(0),
  );
}

void main() {
  group('GruppenBeitrittscode', () {
    test('Textform lässt sich lesen und schreiben', () {
      const code = GruppenBeitrittscode(
        groupId: '1234-abcd-5678',
        joinCode: 'ABCD2345EFGH',
      );
      expect(code.text, '1234-abcd-5678.ABCD2345EFGH');
      expect(GruppenBeitrittscode.parse(' ${code.text} \n'), code);
    });

    test('unvollständige Eingaben werden abgelehnt', () {
      for (final eingabe in <String>[
        '',
        'nur-die-id',
        '.CODE',
        'id.',
        'a/b.CODE',
        'id.CO DE',
      ]) {
        expect(GruppenBeitrittscode.parse(eingabe), isNull, reason: eingabe);
      }
    });

    test('erzeugte Geheimnisse sind lang genug und unverwechselbar', () {
      final code = GruppenBeitrittscode.erzeugeJoinCode(random: Random(1));
      expect(code, hasLength(GruppenBeitrittscode.joinCodeLaenge));
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]+$')));
      expect(
        GruppenBeitrittscode.erzeugeJoinCode(),
        isNot(GruppenBeitrittscode.erzeugeJoinCode()),
      );
    });
  });

  group('GruppenSyncService', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    test(
      'erstellt Gruppe mit Beitrittscode und Besitzer-Mitgliedschaft',
      () async {
        final dienst = _dienst(
          firestore,
          'owner',
          ids: <String>['gruppe-1'],
          codes: <String>['CODE1234ABCD'],
        );

        final info = await dienst.erstelleGruppe('  Die Silberfüchse ');

        expect(info.groupId, 'gruppe-1');
        expect(info.name, 'Die Silberfüchse');
        expect(info.beitrittscode.text, 'gruppe-1.CODE1234ABCD');
        final gruppe = await firestore.doc('groups_v2/gruppe-1').get();
        expect(gruppe.data(), containsPair('ownerUid', 'owner'));
        expect(gruppe.data(), containsPair('joinCode', 'CODE1234ABCD'));
        final mitglied = await firestore
            .doc('groups_v2/gruppe-1/members/owner')
            .get();
        expect(mitglied.data(), containsPair('role', 'owner'));
      },
    );

    test('Beitritt trägt das Konto als Mitglied mit Code ein', () async {
      await _dienst(
        firestore,
        'owner',
        ids: <String>['g'],
        codes: <String>['GEHEIM123456'],
      ).erstelleGruppe('Runde');

      final info = await _dienst(firestore, 'spieler').tritteBei(
        const GruppenBeitrittscode(groupId: 'g', joinCode: 'GEHEIM123456'),
      );

      expect(info.name, 'Runde');
      final mitglied = await firestore.doc('groups_v2/g/members/spieler').get();
      expect(mitglied.data(), containsPair('role', 'member'));
      expect(mitglied.data(), containsPair('joinCode', 'GEHEIM123456'));
    });

    test('Beitritt zu einem Mitglied lässt den Eintrag unverändert', () async {
      final dienst = _dienst(
        firestore,
        'owner',
        ids: <String>['g'],
        codes: <String>['GEHEIM123456'],
      );
      await dienst.erstelleGruppe('Runde');

      await dienst.tritteBei(
        const GruppenBeitrittscode(groupId: 'g', joinCode: 'egal'),
      );

      final mitglied = await firestore.doc('groups_v2/g/members/owner').get();
      expect(mitglied.data(), containsPair('role', 'owner'));
      expect(mitglied.data(), isNot(contains('joinCode')));
    });

    test('Erneuern ändert das Beitrittsgeheimnis', () async {
      final dienst = _dienst(
        firestore,
        'owner',
        ids: <String>['g'],
        codes: <String>['ALT123456789', 'NEU123456789'],
      );
      await dienst.erstelleGruppe('Runde');

      final neu = await dienst.erneuereBeitrittscode('g');

      expect(neu.text, 'g.NEU123456789');
      expect((await dienst.ladeGruppe('g')).joinCode, 'NEU123456789');
    });

    test(
      'Heldenkarte, geteilte Einträge und Notizen laufen über Firestore',
      () async {
        final besitzer = _dienst(
          firestore,
          'owner',
          ids: <String>['g'],
          codes: <String>['CODE12345678'],
        );
        await besitzer.erstelleGruppe('Runde');
        final spieler = _dienst(firestore, 'spieler');
        await spieler.tritteBei(
          const GruppenBeitrittscode(groupId: 'g', joinCode: 'CODE12345678'),
        );

        await besitzer.pushVisitenkarte(
          'g',
          _karte('hero-owner', name: 'Alrik'),
        );
        await spieler.pushVisitenkarte(
          'g',
          _karte('hero-spieler', name: 'Rondra'),
        );
        await spieler.pushGeteilterHeld(
          'g',
          HeldVisitenkarte(
            heroId: 'npc-1',
            name: 'Begleiter',
            exportedAt: DateTime.utc(2026, 1, 2),
            istManuell: true,
            notizen: 'Packesel',
          ),
        );
        await besitzer.speichereNotizen('g', 'Treffpunkt: Gasthaus');

        final inhalt = await besitzer.ladeInhalt('g');
        expect(
          {for (final m in inhalt.mitglieder) m.uid: m.karte.name},
          {'owner': 'Alrik', 'spieler': 'Rondra'},
        );
        expect(inhalt.geteilte.single.heroId, 'npc-1');
        expect(inhalt.geteilte.single.istManuell, isTrue);
        expect(inhalt.geteilte.single.notizen, 'Packesel');
        expect(await spieler.ladeNotizen('g'), 'Treffpunkt: Gasthaus');
      },
    );

    test(
      'geteilter Eintrag behält den Ersteller bei Änderung durch andere',
      () async {
        final besitzer = _dienst(
          firestore,
          'owner',
          ids: <String>['g'],
          codes: <String>['CODE12345678'],
        );
        await besitzer.erstelleGruppe('Runde');
        final spieler = _dienst(firestore, 'spieler');
        await spieler.tritteBei(
          const GruppenBeitrittscode(groupId: 'g', joinCode: 'CODE12345678'),
        );

        await spieler.pushGeteilterHeld('g', _karte('npc', name: 'Alt'));
        await besitzer.pushGeteilterHeld('g', _karte('npc', name: 'Neu'));

        final eintrag = await firestore
            .doc('groups_v2/g/shared_heroes/npc')
            .get();
        expect(eintrag.data(), containsPair('name', 'Neu'));
        expect(eintrag.data(), containsPair('createdByUid', 'spieler'));

        await besitzer.entferneGeteiltenHeld('g', 'npc');
        expect((await besitzer.ladeInhalt('g')).geteilte, isEmpty);
      },
    );

    test('Dokument-ID gilt, wenn die Karte keine heroId trägt', () async {
      await firestore.doc('groups_v2/g/hero_snapshots/uid-x').set({
        'name': 'Ohne ID',
        'exportedAt': '2026-01-01T00:00:00.000Z',
      });
      await firestore.doc('groups_v2/g/shared_heroes/npc-9').set({
        'heroId': 'fremde-id',
        'name': 'Geteilt',
        'exportedAt': '2026-01-01T00:00:00.000Z',
      });

      final inhalt = await _dienst(firestore, 'x').ladeInhalt('g');

      expect(inhalt.mitglieder.single.karte.heroId, 'uid-x');
      // Der Dokumentschlüssel zählt, nicht die vom Ersteller gesetzte ID.
      expect(inhalt.geteilte.single.heroId, 'npc-9');
    });

    test('Verlassen löscht Heldenkarte und Mitgliedschaft', () async {
      final besitzer = _dienst(
        firestore,
        'owner',
        ids: <String>['g'],
        codes: <String>['CODE12345678'],
      );
      await besitzer.erstelleGruppe('Runde');
      final spieler = _dienst(firestore, 'spieler');
      await spieler.tritteBei(
        const GruppenBeitrittscode(groupId: 'g', joinCode: 'CODE12345678'),
      );
      await spieler.pushVisitenkarte('g', _karte('hero-spieler'));

      await spieler.verlasseGruppe('g');

      expect(
        (await firestore.doc('groups_v2/g/members/spieler').get()).exists,
        isFalse,
      );
      expect(
        (await firestore.doc('groups_v2/g/hero_snapshots/spieler').get())
            .exists,
        isFalse,
      );
      expect((await firestore.doc('groups_v2/g').get()).exists, isTrue);
    });

    test('Besitzer entfernt Mitglieder und löscht die ganze Gruppe', () async {
      final besitzer = _dienst(
        firestore,
        'owner',
        ids: <String>['g'],
        codes: <String>['CODE12345678'],
      );
      await besitzer.erstelleGruppe('Runde');
      final spieler = _dienst(firestore, 'spieler');
      await spieler.tritteBei(
        const GruppenBeitrittscode(groupId: 'g', joinCode: 'CODE12345678'),
      );
      await spieler.pushVisitenkarte('g', _karte('hero-spieler'));
      await besitzer.pushGeteilterHeld('g', _karte('npc'));
      await besitzer.speichereNotizen('g', 'Notiz');

      await besitzer.entferneMitglied('g', 'spieler');
      expect(
        (await firestore.doc('groups_v2/g/members/spieler').get()).exists,
        isFalse,
      );

      await besitzer.loescheGruppe('g');

      expect((await firestore.doc('groups_v2/g').get()).exists, isFalse);
      for (final sammlung in <String>[
        'members',
        'hero_snapshots',
        'shared_heroes',
        'shared_info',
      ]) {
        expect(
          (await firestore.collection('groups_v2/g/$sammlung').get()).docs,
          isEmpty,
          reason: sammlung,
        );
      }
    });

    group('Regelprofil-Vorgabe', () {
      final profil = HeroRegelProfil(
        catalogVersion: 'house_rules_v1',
        pakete: [
          HeroRegelProfilPaket(
            paketId: 'epic_rules_v1',
            pruefsumme: 'abc',
            manifest: const <String, Object?>{
              'id': 'epic_rules_v1',
              'title': 'Epische Regeln',
              // Verschachtelte Listen sind in Firestore-Feldern verboten.
              'patches': <Object?>[
                <Object?>[1, 2],
              ],
            },
          ),
        ],
      );

      GruppenSyncService besitzer() => _dienst(
        firestore,
        'owner',
        ids: <String>['g'],
        codes: <String>['GEHEIM123456'],
      );

      test('ohne Vorgabe gibt es keine', () async {
        final dienst = besitzer();
        await dienst.erstelleGruppe('Runde');

        expect(await dienst.ladeRegelVorgabe('g'), isNull);
      });

      test(
        'Besitzer setzt die Vorgabe, Mitglieder lesen dasselbe Profil',
        () async {
          final dienst = besitzer();
          await dienst.erstelleGruppe('Runde');
          await dienst.speichereRegelVorgabe('g', profil);
          final mitglied = _dienst(firestore, 'spieler');
          await mitglied.tritteBei(
            const GruppenBeitrittscode(groupId: 'g', joinCode: 'GEHEIM123456'),
          );

          final geladen = await mitglied.ladeRegelVorgabe('g');

          expect(geladen, profil);
          expect(
            geladen!.pakete.single.manifest,
            profil.pakete.single.manifest,
          );
          final doc = await firestore
              .doc('groups_v2/g/shared_info/regelprofil')
              .get();
          expect(doc.data(), containsPair('updatedByUid', 'owner'));
          expect(doc.data()!['profilJson'], isA<String>());
        },
      );

      test('Entfernen löscht die Vorgabe', () async {
        final dienst = besitzer();
        await dienst.erstelleGruppe('Runde');
        await dienst.speichereRegelVorgabe('g', profil);

        await dienst.entferneRegelVorgabe('g');

        expect(await dienst.ladeRegelVorgabe('g'), isNull);
      });

      test('beschädigte oder zu neue Vorgaben zählen als keine', () async {
        final dienst = besitzer();
        await dienst.erstelleGruppe('Runde');
        final ziel = firestore.doc('groups_v2/g/shared_info/regelprofil');

        await ziel.set(<String, dynamic>{'profilJson': '{kaputt'});
        expect(await dienst.ladeRegelVorgabe('g'), isNull);

        await ziel.set(<String, dynamic>{'profilJson': '[1,2]'});
        expect(await dienst.ladeRegelVorgabe('g'), isNull);

        await ziel.set(<String, dynamic>{
          'profilJson': jsonEncode(profil.copyWith(formatVersion: 99).toJson()),
        });
        expect(await dienst.ladeRegelVorgabe('g'), isNull);
      });
    });

    test('ohne Anmeldung gibt es eine verständliche Meldung', () async {
      final dienst = GruppenSyncService(
        firestore: firestore,
        uidProvider: () => null,
      );

      await expectLater(
        dienst.erstelleGruppe('Runde'),
        throwsA(isA<GruppenException>()),
      );
    });
  });
}
