import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/domain/sync_controller.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/domain/sync_object_diff.dart';
import 'package:dsa_heldenverwaltung/domain/sync_zusammenfuehrung.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/sync_conflict_gate.dart';

void main() {
  SyncConflict conflict({String id = 'hero-h-1'}) {
    return SyncConflict(
      id: id,
      objectType: SyncObjectType.hero,
      objectId: 'h-1',
      title: 'Held: Alrik',
      localSummary: 'Alrik lokal',
      remoteSummary: 'Alrik online',
      detectedAt: DateTime.utc(2026, 1, 1),
      supportsKeepBoth: true,
      localApTotal: 1100,
      localApAvailable: 20,
      remoteApTotal: 1200,
      remoteApAvailable: 5,
    );
  }

  Widget buildGate(_FakeSyncController controller, {AuthService? authService}) {
    return ProviderScope(
      overrides: [
        if (authService != null)
          authServiceProvider.overrideWithValue(authService),
      ],
      child: MaterialApp(
        home: SyncConflictGate(
          syncController: controller,
          child: const Text('App-Inhalt'),
        ),
      ),
    );
  }

  testWidgets('zeigt Feldunterschiede nach dem Aufklappen', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
      diffs: <String, SyncObjectDiff>{
        'hero-h-1': const SyncObjectDiff(
          entries: <SyncDiffEntry>[
            SyncDiffEntry(
              path: <String>['name'],
              kind: SyncDiffKind.changed,
              localValue: 'Alrik lokal',
              remoteValue: 'Alrik online',
            ),
            SyncDiffEntry(
              path: <String>['attributes', 'mu'],
              kind: SyncDiffKind.changed,
              localValue: 12,
              remoteValue: 14,
            ),
          ],
        ),
      },
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    // Kopfzeile und Zusammenfassung sind auch eingeklappt sichtbar.
    expect(find.text('Feld'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Lokal'), findsOneWidget);
    expect(find.text('AP gesamt'), findsOneWidget);
    expect(find.text('1200'), findsOneWidget);
    expect(find.text('1100'), findsOneWidget);
    expect(find.text('Unterschiede anzeigen (2)'), findsOneWidget);
    expect(find.text('Eigenschaften › MU'), findsNothing);

    await tester.tap(find.text('Unterschiede anzeigen (2)'));
    await tester.pumpAndSettle();

    // "Name" steht jetzt zweimal: als Zusammenfassung und als Diff-Zeile.
    expect(find.text('Name'), findsNWidgets(2));
    expect(find.text('Eigenschaften › MU'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Unterschiede ausblenden'), findsOneWidget);
  });

  testWidgets('trennt nur-lokale und nur-online Felder in den Spalten', (
    tester,
  ) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
      diffs: <String, SyncObjectDiff>{
        'hero-h-1': const SyncObjectDiff(
          entries: <SyncDiffEntry>[
            SyncDiffEntry(
              path: <String>['dukaten'],
              kind: SyncDiffKind.onlyLocal,
              localValue: 42,
            ),
            SyncDiffEntry(
              path: <String>['titel'],
              kind: SyncDiffKind.onlyRemote,
              remoteValue: 'Ritter',
            ),
          ],
        ),
      },
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unterschiede anzeigen (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Dukaten'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Titel'), findsOneWidget);
    expect(find.text('Ritter'), findsOneWidget);
    expect(find.text('(nicht vorhanden)'), findsNWidgets(2));
  });

  testWidgets('meldet geloeschte Online-Version statt Feldliste', (
    tester,
  ) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
      diffs: <String, SyncObjectDiff>{
        'hero-h-1': const SyncObjectDiff(remoteMissing: true),
      },
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Die Online-Version wurde gelöscht – kein Feldvergleich '
        'möglich.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Unterschiede anzeigen'), findsNothing);
  });

  testWidgets('zeigt Identisch-Hinweis bei leerem Diff', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
      diffs: <String, SyncObjectDiff>{'hero-h-1': const SyncObjectDiff()},
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(
      find.text('Beide Versionen sind inhaltlich identisch.'),
      findsOneWidget,
    );
    expect(find.textContaining('Unterschiede anzeigen'), findsNothing);
  });

  testWidgets('bleibt ohne Diff-Daten unveraendert nutzbar', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unterschiede anzeigen'), findsNothing);
    // Die Zusammenfassung bleibt auch ohne Diff als Tabelle sichtbar.
    expect(find.text('Alrik online'), findsOneWidget);
    expect(find.text('Alrik lokal'), findsOneWidget);

    await tester.tap(find.text('Nur Lokal'));
    await tester.pumpAndSettle();

    expect(controller.resolvedConflicts, [
      ('hero-h-1', SyncResolutionChoice.keepLocal),
    ]);
  });

  testWidgets('die Knöpfe folgen den Spalten: Online links, Lokal rechts', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    // Lesereihenfolge: erst die Zeile, dann von links nach rechts.
    bool vor(String a, String b) {
      final pa = tester.getTopLeft(find.text(a));
      final pb = tester.getTopLeft(find.text(b));
      return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
    }

    expect(vor('Online', 'Lokal'), isTrue);
    expect(vor('Nur Online', 'Nur Lokal'), isTrue);
    expect(vor('Nur Lokal', 'Beide behalten'), isTrue);
    // Ohne gemeinsamen Ausgangsstand gibt es kein „Automatisch“.
    expect(find.text('Automatisch'), findsNothing);
  });

  group('Automatisch (ARCH-06)', () {
    const feld = SyncKonfliktFeld(
      schluessel: 'held:dukaten',
      pfad: <String>['dukaten'],
      online: '20',
      lokal: '30',
    );

    testWidgets('zeigt nur den Widerspruch und fragt nach ihm', (tester) async {
      final controller = _FakeSyncController(
        SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
        vorschau: const <String, SyncKonfliktVorschau>{
          'hero-h-1': SyncKonfliktVorschau(
            felder: <SyncKonfliktFeld>[feld],
            vonLokal: 2,
            vonOnline: 3,
          ),
        },
      );
      addTearDown(controller.close);

      await tester.pumpWidget(buildGate(controller));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('1 Wert wurde auf beiden Geräten'),
        findsOneWidget,
      );
      expect(find.textContaining('3 Änderungen von online'), findsOneWidget);
      // Die widersprüchliche Zeile ist sofort sichtbar.
      expect(find.text('Dukaten'), findsOneWidget);

      await tester.ensureVisible(find.text('Automatisch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatisch'));
      await tester.pumpAndSettle();
      final uebernehmen = find.byKey(
        const ValueKey<String>('sync-feld-uebernehmen'),
      );
      expect(tester.widget<FilledButton>(uebernehmen).onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('sync-feld-held:dukaten-online')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(uebernehmen);
      await tester.pumpAndSettle();
      await tester.tap(uebernehmen);
      await tester.pumpAndSettle();

      expect(controller.automatisch.single.$1, 'hero-h-1');
      expect(controller.automatisch.single.$2, {
        'held:dukaten': SyncSeite.online,
      });
    });

    testWidgets('ohne Widerspruch führt es direkt zusammen', (tester) async {
      final controller = _FakeSyncController(
        SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
        vorschau: const <String, SyncKonfliktVorschau>{
          'hero-h-1': SyncKonfliktVorschau(
            felder: <SyncKonfliktFeld>[],
            vonLokal: 1,
            vonOnline: 1,
          ),
        },
      );
      addTearDown(controller.close);

      await tester.pumpWidget(buildGate(controller));
      await tester.pumpAndSettle();
      expect(find.text('Kein Wert widerspricht sich.'), findsOneWidget);

      await tester.ensureVisible(find.text('Automatisch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatisch'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('sync-feld-entscheidung')),
        findsNothing,
      );
      expect(controller.automatisch.single.$1, 'hero-h-1');
      expect(controller.automatisch.single.$2, isEmpty);
    });

    testWidgets('ein Fehler erscheint an der Karte', (tester) async {
      final controller = _FakeSyncController(
        SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
        vorschau: const <String, SyncKonfliktVorschau>{
          'hero-h-1': SyncKonfliktVorschau(
            felder: <SyncKonfliktFeld>[],
            vonLokal: 1,
            vonOnline: 1,
          ),
        },
      )..automatischFehler = StateError('Netz weg');
      addTearDown(controller.close);

      await tester.pumpWidget(buildGate(controller));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Automatisch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Automatisch'));
      await tester.pumpAndSettle();

      expect(find.text('Nicht aufgelöst: Netz weg'), findsOneWidget);
    });
  });

  testWidgets('"Später entscheiden" gibt die App frei', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();
    expect(find.text('App-Inhalt'), findsNothing);

    await tester.tap(find.text('Später entscheiden'));
    await tester.pumpAndSettle();

    expect(find.text('App-Inhalt'), findsOneWidget);
    // Zurueckstellen loest nichts auf: die Konflikte bleiben offen.
    expect(controller.resolvedConflicts, isEmpty);
  });

  testWidgets('Sammelaktion loest alle Konflikte online auf', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(
        openConflicts: <SyncConflict>[
          conflict(),
          conflict(id: 'hero-h-2'),
          conflict(id: 'hero-h-3'),
        ],
      ),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alle: Nur Online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle lösen'));
    await tester.pumpAndSettle();

    expect(controller.resolvedConflicts, [
      ('hero-h-1', SyncResolutionChoice.keepRemote),
      ('hero-h-2', SyncResolutionChoice.keepRemote),
      ('hero-h-3', SyncResolutionChoice.keepRemote),
    ]);
  });

  testWidgets('Sammelaktion fehlt bei einem einzelnen Konflikt', (
    tester,
  ) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(find.text('Alle: Nur Online'), findsNothing);
  });

  testWidgets('Abmelden meldet nach Bestaetigung ab', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
    );
    addTearDown(controller.close);
    final authService = _FakeAuthService();

    await tester.pumpWidget(buildGate(controller, authService: authService));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(authService.signOutCalls, 0);

    await tester.tap(find.text('Abmelden').last);
    await tester.pumpAndSettle();

    expect(authService.signOutCalls, 1);
    expect(controller.resolvedConflicts, isEmpty);
  });

  testWidgets('Abmelden fehlt ohne verfuegbaren Auth-Dienst', (tester) async {
    final controller = _FakeSyncController(
      SyncStatusSnapshot(openConflicts: <SyncConflict>[conflict()]),
    );
    addTearDown(controller.close);

    await tester.pumpWidget(buildGate(controller));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.logout), findsNothing);
  });
}

class _FakeAuthService implements AuthService {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  AuthUser? get currentUser => const AuthUser(uid: 'user-1', email: null);

  @override
  Stream<AuthUser?> watchUser() =>
      Stream<AuthUser?>.value(const AuthUser(uid: 'user-1', email: null));

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }
}

class _FakeSyncController extends AppSyncController {
  _FakeSyncController(
    SyncStatusSnapshot initial, {
    this._diffs = const <String, SyncObjectDiff>{},
    this._vorschau = const <String, SyncKonfliktVorschau>{},
  }) : _current = initial;

  final Map<String, SyncKonfliktVorschau> _vorschau;
  final List<(String, Map<String, SyncSeite>)> automatisch =
      <(String, Map<String, SyncSeite>)>[];
  Object? automatischFehler;

  @override
  Future<SyncKonfliktVorschau?> konfliktVorschau(String conflictId) async =>
      _vorschau[conflictId];

  @override
  Future<void> resolveConflictAutomatisch(
    String conflictId,
    Map<String, SyncSeite> entscheidungen,
  ) async {
    final fehler = automatischFehler;
    if (fehler != null) {
      throw fehler;
    }
    automatisch.add((conflictId, entscheidungen));
  }

  final StreamController<SyncStatusSnapshot> _controller =
      StreamController<SyncStatusSnapshot>.broadcast();
  final Map<String, SyncObjectDiff> _diffs;
  final SyncStatusSnapshot _current;
  final List<(String, SyncResolutionChoice)> resolvedConflicts =
      <(String, SyncResolutionChoice)>[];

  @override
  SyncStatusSnapshot get currentStatus => _current;

  @override
  Stream<SyncStatusSnapshot> watchStatus() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> syncNow() async {}

  @override
  Future<void> resolveConflict(
    String conflictId,
    SyncResolutionChoice resolution,
  ) async {
    resolvedConflicts.add((conflictId, resolution));
  }

  @override
  SyncObjectDiff? conflictDiff(String conflictId) => _diffs[conflictId];

  Future<void> close() => _controller.close();
}
