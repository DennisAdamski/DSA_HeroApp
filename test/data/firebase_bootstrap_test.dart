import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';

void main() {
  test('bootstrapFirebase returns available when initializer succeeds', () async {
    final result = await bootstrapFirebase(initializer: () async {});

    expect(result.isAvailable, isTrue);
    expect(result.userMessage, isNull);
    expect(result.technicalDetails, isNull);
  });

  test('bootstrapFirebase falls back to local-only mode on failure', () async {
    final result = await bootstrapFirebase(
      initializer: () async => throw StateError('boom'),
    );

    expect(result.isAvailable, isFalse);
    expect(result.userMessage, contains('Gruppen-Sync'));
    expect(result.technicalDetails, contains('boom'));
  });
}
