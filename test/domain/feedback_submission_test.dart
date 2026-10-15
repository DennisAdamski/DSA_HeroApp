import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';

void main() {
  const metadata = FeedbackBaseMetadata(
    appVersion: '1.0.1',
    buildNumber: '1',
    commit: 'abcdef0',
    builtAt: '2026-10-15T19:00:00Z',
    platform: 'windows',
  );

  test(
    'Bug serialisiert nur Bugfelder und ein bewusst gewähltes Diagnosepaket',
    () {
      const submission = BugFeedbackSubmission(
        requestId: '123e4567-e89b-42d3-a456-426614174000',
        title: 'Tabelle läuft aus dem Fenster',
        surface: FeedbackSurface.inventory,
        metadata: metadata,
        actualBehavior: 'Die Tabelle läuft am rechten Rand aus dem Fenster.',
        expectedBehavior:
            'Die Tabelle bleibt horizontal vollständig erreichbar.',
        reproductionSteps: 'Inventar auf einem schmalen Fenster öffnen.',
        diagnostics: BugDiagnostics(
          operatingSystem: 'Windows',
          operatingSystemVersion: '11',
          locale: 'de-DE',
          viewportWidth: 1280,
          viewportHeight: 720,
          devicePixelRatio: 1.25,
          layoutClass: 'desktopWide',
          interfaceVariant: 'kartograph',
          brightness: 'dark',
          tableMode: 'automatic',
          firebaseAvailable: true,
          authenticated: true,
        ),
      );

      final json = submission.toJson();
      expect(json['schemaVersion'], 1);
      expect(json['kind'], 'bug');
      expect(json['surface'], 'inventory');
      expect(
        (json['diagnostics'] as Map<String, dynamic>).keys,
        isNot(contains('email')),
      );
      expect(json, isNot(contains('problem')));
    },
  );

  test('Feature und Regelfrage verwenden getrennte Vertragsfelder', () {
    const feature = FeatureFeedbackSubmission(
      requestId: '123e4567-e89b-42d3-a456-426614174001',
      title: 'Gegnervorlagen speichern',
      surface: FeedbackSurface.combat,
      metadata: metadata,
      problem: 'Wiederkehrende Gegner müssen jedes Mal neu erfasst werden.',
      desiredBehavior: 'Gegner sollen als Vorlage gespeichert werden können.',
    );
    const rules = RulesFeedbackSubmission(
      requestId: '123e4567-e89b-42d3-a456-426614174002',
      title: 'Kombinierte Erschwernisse',
      surface: FeedbackSurface.other,
      metadata: metadata,
      question: 'Welche Erschwernis gilt in dieser kombinierten Situation?',
      source: 'WdS, Seite 42',
      interpretation: 'Ich würde beide Modifikatoren addieren.',
    );

    expect(feature.toJson()['kind'], 'feature');
    expect(
      feature.toJson(),
      containsPair('desiredBehavior', contains('Vorlage')),
    );
    expect(rules.toJson()['kind'], 'rules');
    expect(rules.toJson(), containsPair('source', 'WdS, Seite 42'));
  });
}
