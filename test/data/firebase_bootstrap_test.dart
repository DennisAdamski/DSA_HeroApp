import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/firebase_bootstrap.dart';

void main() {
  test(
    'bootstrapFirebase returns available when initializer succeeds',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      final result = await bootstrapFirebase(initializer: () async {});

      expect(result.isAvailable, isTrue);
      expect(result.isFirestoreAvailable, isTrue);
      expect(result.userMessage, isNull);
      expect(result.firestoreUserMessage, isNull);
      expect(result.technicalDetails, isNull);
    },
  );

  test(
    'bootstrapFirebase disables Firestore on Windows without disabling Auth',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      final result = await bootstrapFirebase(initializer: () async {});

      expect(result.isAvailable, isTrue);
      expect(result.isFirestoreAvailable, isFalse);
      expect(result.firestoreUserMessage, contains('Windows'));
    },
  );

  test('bootstrapFirebase falls back to local-only mode on failure', () async {
    final result = await bootstrapFirebase(
      initializer: () async => throw StateError('boom'),
    );

    expect(result.isAvailable, isFalse);
    expect(result.isFirestoreAvailable, isFalse);
    expect(result.userMessage, contains('Konto-Sync'));
    expect(result.userMessage, contains('Cloud-Funktionen'));
    expect(result.technicalDetails, contains('boom'));
  });
}
