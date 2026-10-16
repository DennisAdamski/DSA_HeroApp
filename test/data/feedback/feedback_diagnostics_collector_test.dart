import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/feedback/feedback_diagnostics_collector.dart';

void main() {
  test('sammelt nur freigegebene Build- und UI-Diagnosewerte', () {
    const collector = FeedbackDiagnosticsCollector(
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

    final diagnostics = collector.diagnostics(
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
    );

    expect(collector.metadata().toJson(), <String, dynamic>{
      'appVersion': '1.0.1',
      'buildNumber': '1',
      'commit': 'abcdef0',
      'builtAt': '2026-10-15T19:00:00Z',
      'platform': 'windows',
    });
    expect(diagnostics.toJson(), isNot(contains('deviceModel')));
    expect(diagnostics.toJson(), isNot(contains('userId')));
  });
}
