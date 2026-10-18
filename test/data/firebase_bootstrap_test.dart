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
      expect(result.isAccountSyncAvailable, isTrue);
      expect(result.userMessage, isNull);
      expect(result.firestoreUserMessage, isNull);
      expect(result.technicalDetails, isNull);
    },
  );

  test(
    'bootstrapFirebase separates Windows account sync from native Firestore',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      final result = await bootstrapFirebase(initializer: () async {});

      expect(result.isAvailable, isTrue);
      expect(result.isFirestoreAvailable, isFalse);
      expect(result.isAccountSyncAvailable, isTrue);
      expect(result.firestoreUserMessage, contains('Konto-Sync'));
    },
  );

  test('bootstrapFirebase falls back to local-only mode on failure', () async {
    final result = await bootstrapFirebase(
      initializer: () async => throw StateError('boom'),
    );

    expect(result.isAvailable, isFalse);
    expect(result.isFirestoreAvailable, isFalse);
    expect(result.isAccountSyncAvailable, isFalse);
    expect(result.userMessage, contains('Konto-Sync'));
    expect(result.userMessage, contains('Cloud-Funktionen'));
    expect(result.technicalDetails, contains('boom'));
  });

  test('App Check stays inactive on Windows without a debug token', () {
    final shouldActivate = shouldActivateFirebaseAppCheck(
      isWeb: false,
      platform: TargetPlatform.windows,
      hasWindowsDebugToken: false,
    );

    expect(shouldActivate, isFalse);
  });

  test('App Check activates on Windows when a debug token is configured', () {
    final shouldActivate = shouldActivateFirebaseAppCheck(
      isWeb: false,
      platform: TargetPlatform.windows,
      hasWindowsDebugToken: true,
    );

    expect(shouldActivate, isTrue);
  });

  test('App Check activates on supported native and web platforms', () {
    final android = shouldActivateFirebaseAppCheck(
      isWeb: false,
      platform: TargetPlatform.android,
      hasWindowsDebugToken: false,
    );
    final web = shouldActivateFirebaseAppCheck(
      isWeb: true,
      platform: TargetPlatform.windows,
      hasWindowsDebugToken: false,
    );

    expect(android, isTrue);
    expect(web, isTrue);
  });
}
