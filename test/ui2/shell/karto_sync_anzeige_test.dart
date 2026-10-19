import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/state/sync_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_sync_anzeige.dart';

import 'karto_acceptance_support.dart';
import 'karto_test_support.dart';

SyncConflict _konflikt(String id) => SyncConflict(
  id: id,
  objectType: SyncObjectType.hero,
  objectId: id,
  title: 'Held: $id',
  localSummary: 'lokal',
  remoteSummary: 'online',
  detectedAt: DateTime.utc(2026),
);

void main() {
  final jetzt = DateTime(2026, 10, 19, 14, 30);

  group('beschreibeKartoSync', () {
    test('ohne Konto gibt es nichts anzuzeigen', () {
      expect(
        beschreibeKartoSync(const SyncStatusSnapshot(), jetzt: jetzt),
        isNull,
      );
    });

    test('Konflikte haben Vorrang vor Fehler und Abgleich', () {
      final anzeige = beschreibeKartoSync(
        SyncStatusSnapshot(
          accountId: 'u',
          isSyncing: true,
          lastFailure: const SyncFailure(
            kind: SyncErrorKind.network,
            message: 'offline',
          ),
          openConflicts: [_konflikt('a'), _konflikt('b')],
        ),
        jetzt: jetzt,
      )!;
      expect(anzeige.stufe, KartoSyncStufe.entscheidung);
      expect(anzeige.text, 'Sync: 2 Konflikte offen');
    });

    test('ein Konflikt steht im Singular', () {
      final anzeige = beschreibeKartoSync(
        SyncStatusSnapshot(accountId: 'u', openConflicts: [_konflikt('a')]),
        jetzt: jetzt,
      )!;
      expect(anzeige.text, 'Sync: 1 Konflikt offen');
    });

    test(
      'nicht abgeschlossene Entscheidungen zählen nicht als abgeglichen',
      () {
        final anzeige = beschreibeKartoSync(
          SyncStatusSnapshot(
            accountId: 'u',
            ausstehendeVorgaenge: 1,
            lastSuccessfulSync: DateTime(2026, 10, 19, 14),
          ),
          jetzt: jetzt,
        )!;
        expect(anzeige.stufe, KartoSyncStufe.entscheidung);
        expect(anzeige.text, 'Sync: Entscheidung nicht abgeschlossen');
      },
    );

    test('Fehler unterscheiden Netz, Anmeldung und Rest', () {
      KartoSyncAnzeige fehler(SyncErrorKind kind) => beschreibeKartoSync(
        SyncStatusSnapshot(
          accountId: 'u',
          lastFailure: SyncFailure(kind: kind, message: 'x'),
        ),
        jetzt: jetzt,
      )!;
      expect(
        fehler(SyncErrorKind.network).text,
        'Sync: Cloud nicht erreichbar',
      );
      expect(fehler(SyncErrorKind.network).icon, Icons.cloud_off_outlined);
      expect(fehler(SyncErrorKind.auth).text, 'Sync: Anmeldung erneuern');
      expect(fehler(SyncErrorKind.decode).text, 'Sync fehlgeschlagen');
      expect(fehler(SyncErrorKind.unknown).stufe, KartoSyncStufe.fehler);
    });

    test('laufender Abgleich ist ruhig und gekennzeichnet', () {
      final anzeige = beschreibeKartoSync(
        const SyncStatusSnapshot(accountId: 'u', isSyncing: true),
        jetzt: jetzt,
      )!;
      expect(anzeige.stufe, KartoSyncStufe.ruhig);
      expect(anzeige.laeuft, isTrue);
      expect(anzeige.text, 'Sync läuft …');
    });

    test('ohne bisherigen Abgleich und mit Zeitpunkt', () {
      expect(
        beschreibeKartoSync(
          const SyncStatusSnapshot(accountId: 'u'),
          jetzt: jetzt,
        )!.text,
        'Sync: noch nicht abgeglichen',
      );
      expect(
        beschreibeKartoSync(
          SyncStatusSnapshot(
            accountId: 'u',
            lastSuccessfulSync: DateTime(2026, 10, 19, 9, 5),
          ),
          jetzt: jetzt,
        )!.text,
        'Abgeglichen um 09:05',
      );
      expect(
        beschreibeKartoSync(
          SyncStatusSnapshot(
            accountId: 'u',
            lastSuccessfulSync: DateTime(2026, 10, 3, 21, 45),
          ),
          jetzt: jetzt,
        )!.text,
        'Abgeglichen am 03.10. 21:45',
      );
    });
  });

  group('Workspace', () {
    Future<void> pumpMitStatus(
      WidgetTester tester,
      SyncStatusSnapshot status, {
      Size size = const Size(1440, 1000),
    }) async {
      await pumpAcceptanceWorkspace(
        tester,
        repository: AcceptanceRepository(heroes: [testHero()]),
        selectedHeroId: 'rondra',
        size: size,
        overrides: [
          syncStatusProvider.overrideWith((ref) => Stream.value(status)),
        ],
      );
    }

    testWidgets('ohne Konto erscheint kein Eintrag', (tester) async {
      await pumpMitStatus(tester, const SyncStatusSnapshot());
      expect(find.byKey(const ValueKey('karto-sync-anzeige')), findsNothing);
    });

    testWidgets('breit steht der Stand im Navigationsfuß', (tester) async {
      await pumpMitStatus(
        tester,
        SyncStatusSnapshot(accountId: 'u', openConflicts: [_konflikt('a')]),
      );
      expect(find.byKey(const ValueKey('karto-sync-anzeige')), findsOneWidget);
      expect(find.text('Sync: 1 Konflikt offen'), findsOneWidget);
    });

    testWidgets('schmal trägt die AppBar das Symbol mit Tooltip', (
      tester,
    ) async {
      await pumpMitStatus(
        tester,
        SyncStatusSnapshot(accountId: 'u', lastSuccessfulSync: DateTime.now()),
        size: const Size(390, 800),
      );
      expect(find.byKey(const ValueKey('karto-sync-anzeige')), findsOneWidget);
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      expect(find.textContaining('Abgeglichen'), findsNothing);
      final knopf = tester.widget<IconButton>(
        find.byKey(const ValueKey('karto-sync-anzeige')),
      );
      expect(knopf.tooltip, startsWith('Abgeglichen '));
    });
  });
}
