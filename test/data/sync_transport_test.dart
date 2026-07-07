import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/sync/sync_transport.dart';

void main() {
  test('usesRestFirestoreSyncTransport is true on Windows', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    expect(usesRestFirestoreSyncTransport(), isTrue);
  });

  test('usesRestFirestoreSyncTransport is false on Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    expect(usesRestFirestoreSyncTransport(), isFalse);
  });
}
