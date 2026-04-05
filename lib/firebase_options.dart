// GENERIERTE DATEI — wird durch `flutterfire configure` ersetzt.
//
// Fuehre `flutterfire configure` aus, um die plattformspezifischen
// Firebase-Optionen zu generieren.  Dieser Platzhalter erlaubt die
// statische Analyse, bevor das Firebase-Projekt eingerichtet ist.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _android;
      case TargetPlatform.iOS:
        return _ios;
      case TargetPlatform.macOS:
        return _macos;
      case TargetPlatform.windows:
        return _windows;
      case TargetPlatform.linux:
        return _linux;
      case TargetPlatform.fuchsia:
        throw UnsupportedError('Fuchsia wird nicht unterstuetzt.');
    }
  }

  // TODO(setup): Ersetze diese Platzhalter durch echte Werte aus
  // `flutterfire configure`.
  static const FirebaseOptions _android = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
    storageBucket: 'PLACEHOLDER',
  );

  static const FirebaseOptions _ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
    storageBucket: 'PLACEHOLDER',
    iosBundleId: 'PLACEHOLDER',
  );

  static const FirebaseOptions _macos = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
    storageBucket: 'PLACEHOLDER',
    iosBundleId: 'PLACEHOLDER',
  );

  static const FirebaseOptions _windows = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
    storageBucket: 'PLACEHOLDER',
  );

  static const FirebaseOptions _linux = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
    storageBucket: 'PLACEHOLDER',
  );

  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: 'PLACEHOLDER',
    appId: 'PLACEHOLDER',
    messagingSenderId: 'PLACEHOLDER',
    projectId: 'PLACEHOLDER',
    storageBucket: 'PLACEHOLDER',
    authDomain: 'PLACEHOLDER',
  );
}
