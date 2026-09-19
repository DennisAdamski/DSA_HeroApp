import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Laedt die Kartograph-Schriften in die Testumgebung.
///
/// Noetig, weil `flutter test` ohne Zutun eine Ersatzschrift verwendet. Alles,
/// was Schriftschnitte oder Zeichenbreiten prueft, braucht die echten Dateien
/// - sonst misst der Test die Ersatzschrift und haette denselben Ausgang,
/// egal was in `pubspec.yaml` steht.
Future<void> ladeKartoSchriften() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _lade('Spectral', <String>[
    'assets/fonts/spectral/Spectral-Regular.ttf',
    'assets/fonts/spectral/Spectral-Medium.ttf',
    'assets/fonts/spectral/Spectral-SemiBold.ttf',
    'assets/fonts/spectral/Spectral-Italic.ttf',
  ]);
  await _lade('InterTight', <String>[
    'assets/fonts/inter_tight/InterTight-Variable.ttf',
  ]);
}

Future<void> _lade(String familie, List<String> pfade) async {
  final loader = FontLoader(familie);
  for (final pfad in pfade) {
    final datei = File(pfad);
    if (!datei.existsSync()) {
      throw StateError('Schriftdatei fehlt: $pfad');
    }
    final bytes = await datei.readAsBytes();
    loader.addFont(
      Future<ByteData>.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await loader.load();
}
