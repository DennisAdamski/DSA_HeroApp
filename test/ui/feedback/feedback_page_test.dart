import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_client.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_diagnostics_collector.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_pending_store.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/feedback/feedback_controller.dart';
import 'package:dsa_heldenverwaltung/state/feedback/feedback_providers.dart';
import 'package:dsa_heldenverwaltung/ui_shared/feedback/feedback_page.dart';
import 'package:dsa_heldenverwaltung/ui_shared/feedback/feedback_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Vorschau neutralisiert Erwähnungen und zeigt den öffentlichen Bereich',
    () {
      const submission = FeatureFeedbackSubmission(
        requestId: '123e4567-e89b-42d3-a456-426614174001',
        title: 'Wunsch für @team',
        surface: FeedbackSurface.combat,
        metadata: FeedbackBaseMetadata(
          appVersion: '1.0.1',
          buildNumber: '1',
          commit: 'abcdef0',
          builtAt: '2026-10-15T19:00:00Z',
          platform: 'windows',
        ),
        problem: 'Das Problem betrifft aktuell @alle am Spieltisch.',
        desiredBehavior: 'Eine Lösung soll den Ablauf deutlich vereinfachen.',
      );

      final preview = formatFeedbackPreview(submission);
      expect(preview, contains('@\u200bteam'));
      expect(preview, contains('@\u200balle'));
      expect(preview, contains('- Bereich: Kampf'));
    },
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    AuthUser? user = const AuthUser(uid: 'account-a', email: null),
    FeedbackGateway? gateway,
    Size size = const Size(800, 700),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final activeGateway = gateway ?? _FakeGateway();
    final controller = FeedbackController(
      gateway: activeGateway,
      pendingStore: FeedbackPendingStore(_MemoryStorage()),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authUserProvider.overrideWith((ref) => Stream<AuthUser?>.value(user)),
          feedbackControllerProvider.overrideWithValue(controller),
          feedbackDiagnosticsCollectorProvider.overrideWith((ref) async {
            return const FeedbackDiagnosticsCollector(
              runtime: FeedbackRuntimeInfo(
                appVersion: '1.0.1',
                buildNumber: '1',
                commit: 'abcdef0',
                builtAt: '2026-10-15T19:00:00Z',
                platform: 'windows',
                operatingSystem: 'Windows',
                operatingSystemVersion: '11 24H2',
              ),
            );
          }),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: const FeedbackPage(initialSurface: FeedbackSurface.combat),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('verlangt eine bestehende App-Anmeldung', (tester) async {
    await pumpPage(tester, user: null);
    expect(find.textContaining('anmelden'), findsOneWidget);
    expect(find.text('Vorschau öffnen'), findsNothing);
  });

  testWidgets(
    'Bug zeigt geführte Felder und abwählbare Diagnose in der Vorschau',
    (tester) async {
      await pumpPage(tester);
      expect(find.text('Was ist passiert?'), findsOneWidget);
      expect(find.text('Was wurde erwartet?'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Diagnosedaten mitsenden'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Diagnosedaten mitsenden'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('feedback-title')),
        'Angriff bricht unerwartet ab',
      );
      await tester.enterText(
        find.byKey(const ValueKey('feedback-primary')),
        'Der Angriff schließt den Dialog ohne Ergebnis.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('feedback-secondary')),
        'Der Angriff soll das vollständige Ergebnis anzeigen.',
      );
      await tester.scrollUntilVisible(
        find.text('Vorschau öffnen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Vorschau öffnen'));
      await tester.pumpAndSettle();

      expect(find.text('Öffentliche Vorschau'), findsOneWidget);
      expect(find.textContaining('Windows 11 24H2'), findsOneWidget);
      expect(find.textContaining('öffentlich'), findsWidgets);
    },
  );

  testWidgets('Feature verwendet Problem und Zielzustand ohne Bugdiagnose', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('feedback-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feature-Anfrage').last);
    await tester.pumpAndSettle();

    expect(find.text('Welches Problem möchtest du lösen?'), findsOneWidget);
    expect(
      find.text('Wie soll es idealerweise funktionieren?'),
      findsOneWidget,
    );
    expect(find.text('Diagnosedaten mitsenden'), findsNothing);
    expect(find.byKey(const ValueKey('feedback-optional')), findsNothing);
  });

  testWidgets('Regelfrage bietet optionale Fundstelle und eigene Auslegung', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const ValueKey('feedback-kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regelfrage').last);
    await tester.pumpAndSettle();

    expect(find.text('Welche Regelfrage möchtest du klären?'), findsOneWidget);
    expect(find.text('Regelwerk/Fundstelle (optional)'), findsOneWidget);
    expect(find.text('Eigene Auslegung (optional)'), findsOneWidget);
  });

  testWidgets('abgewählte Bugdiagnose fehlt vollständig in der Vorschau', (
    tester,
  ) async {
    await pumpPage(tester);
    await _fillBug(tester);
    await tester.scrollUntilVisible(
      find.text('Diagnosedaten mitsenden'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Diagnosedaten mitsenden'));
    await tester.scrollUntilVisible(
      find.text('Vorschau öffnen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Vorschau öffnen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('## Diagnose'), findsNothing);
    expect(find.textContaining('Windows 11 24H2'), findsNothing);
  });

  testWidgets(
    'Senden ist gegen Doppelklick geschützt und zeigt die Issue-Nummer',
    (tester) async {
      final gateway = _FakeGateway();
      await pumpPage(tester, gateway: gateway);
      await tester.enterText(
        find.byKey(const ValueKey('feedback-title')),
        'Angriff bricht unerwartet ab',
      );
      await tester.enterText(
        find.byKey(const ValueKey('feedback-primary')),
        'Der Angriff schließt den Dialog ohne Ergebnis.',
      );
      await tester.enterText(
        find.byKey(const ValueKey('feedback-secondary')),
        'Der Angriff soll das vollständige Ergebnis anzeigen.',
      );
      await tester.scrollUntilVisible(
        find.text('Vorschau öffnen'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Vorschau öffnen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jetzt senden'));
      await tester.tap(find.text('Jetzt senden'), warnIfMissed: false);
      await tester.pump();
      expect(gateway.submitCalls, 1);

      gateway.complete();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('#23'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('#23'), findsOneWidget);
    },
  );

  testWidgets('Fehler hält Vorschau und Formulareingaben offen', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await pumpPage(tester, gateway: gateway);
    await _fillBug(tester);
    await tester.scrollUntilVisible(
      find.text('Vorschau öffnen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Vorschau öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jetzt senden'));
    gateway.fail();
    await tester.pumpAndSettle();

    expect(find.textContaining('Eingaben bleiben erhalten'), findsOneWidget);
    await tester.tap(find.text('Zurück'));
    await tester.pumpAndSettle();
    final title = tester.widget<TextFormField>(
      find.byKey(const ValueKey('feedback-title')),
    );
    expect(title.controller?.text, 'Angriff bricht unerwartet ab');
  });

  testWidgets('uncertain ist kein Erfolg und bietet eine Statusprüfung', (
    tester,
  ) async {
    final gateway = _FakeGateway();
    await pumpPage(tester, gateway: gateway);
    await _fillBug(tester);
    await tester.scrollUntilVisible(
      find.text('Vorschau öffnen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Vorschau öffnen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jetzt senden'));
    gateway.completeUncertain();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Status prüfen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Versandstatus noch unklar'), findsOneWidget);
    expect(find.textContaining('Feedback eingegangen'), findsNothing);
    expect(find.text('Status prüfen'), findsOneWidget);
  });

  testWidgets('Formular bleibt bei 320 Pixeln und großer Schrift scrollbar', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(320, 600), textScale: 1.8);
    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsWidgets);
  });
}

Future<void> _fillBug(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('feedback-title')),
    'Angriff bricht unerwartet ab',
  );
  await tester.enterText(
    find.byKey(const ValueKey('feedback-primary')),
    'Der Angriff schließt den Dialog ohne Ergebnis.',
  );
  await tester.enterText(
    find.byKey(const ValueKey('feedback-secondary')),
    'Der Angriff soll das vollständige Ergebnis anzeigen.',
  );
}

class _FakeGateway implements FeedbackGateway {
  final completer = Completer<FeedbackResult>();
  int submitCalls = 0;

  @override
  Future<FeedbackResult> submit(FeedbackSubmission submission) {
    submitCalls += 1;
    return completer.future;
  }

  void complete() {
    completer.complete(
      FeedbackResult(
        requestId: '123e4567-e89b-42d3-a456-426614174001',
        status: FeedbackResultStatus.created,
        issueNumber: 23,
        issueUrl: Uri.parse('https://github.test/issues/23'),
      ),
    );
  }

  void completeUncertain() {
    completer.complete(
      const FeedbackResult(
        requestId: '123e4567-e89b-42d3-a456-426614174001',
        status: FeedbackResultStatus.uncertain,
      ),
    );
  }

  void fail() {
    completer.completeError(StateError('simulated transport failure'));
  }

  @override
  Future<FeedbackResult> status(String requestId) async => FeedbackResult(
    requestId: requestId,
    status: FeedbackResultStatus.uncertain,
  );
}

class _MemoryStorage implements FeedbackPendingStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
