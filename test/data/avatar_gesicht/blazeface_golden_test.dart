import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_modell.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_rechenkern.dart';

/// Pinnt den Dart-Rechenkern gegen Googles offizielle LiteRT-Laufzeit.
///
/// Die Sollwerte stammen aus `tool/avatar_gesicht/reference_outputs.py`. Faellt
/// dieser Test, rechnet der Kern falsch — die Fixtures werden dann **nicht**
/// angepasst, sondern der Kern repariert.
void main() {
  const fixtures = 'test/fixtures/avatar_gesicht';

  late BlazeFaceModell modell;
  late Map<String, dynamic> referenz;
  late Float32List eingabe;

  setUpAll(() {
    modell = BlazeFaceModell.ausBytes(
      File(kBlazeFaceModellAsset).readAsBytesSync(),
    );
    referenz = jsonDecode(
      File('$fixtures/mona_lisa_128_referenz.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final rgb = File('$fixtures/mona_lisa_128.rgb').readAsBytesSync();
    eingabe = Float32List(rgb.length);
    for (var i = 0; i < rgb.length; i++) {
      eingabe[i] = rgb[i] / 127.5 - 1.0;
    }
  });

  test('Modell-Asset beschreibt 128er-Eingabe und 896 Anker', () {
    expect(modell.formen[modell.eingabe], [1, 128, 128, 3]);
    expect(modell.formen[modell.regressoren], [1, 896, 16]);
    expect(modell.formen[modell.klassifikatoren], [1, 896, 1]);
    expect(
      modell.ops.map((op) => op.typ).toSet(),
      containsAll(<String>['CONV_2D', 'DEPTHWISE_CONV_2D', 'PAD', 'ADD']),
    );
  });

  test('Rohausgaben stimmen mit der LiteRT-Referenz ueberein', () async {
    final ausgabe = await BlazeFaceRechenkern(modell).rechne(eingabe);

    final logits = (referenz['logits'] as List<dynamic>).cast<num>();
    expect(ausgabe.logits.length, logits.length);
    var maxLogitAbweichung = 0.0;
    for (var i = 0; i < logits.length; i++) {
      final abweichung = (ausgabe.logits[i] - logits[i]).abs();
      if (abweichung > maxLogitAbweichung) maxLogitAbweichung = abweichung;
    }
    expect(maxLogitAbweichung, lessThan(2e-3));

    final regressoren = referenz['regressoren'] as Map<String, dynamic>;
    for (final eintrag in regressoren.entries) {
      final anker = int.parse(eintrag.key);
      final soll = (eintrag.value as List<dynamic>).cast<num>();
      for (var k = 0; k < 16; k++) {
        expect(
          ausgabe.regressoren[anker * 16 + k],
          closeTo(soll[k].toDouble(), 5e-3),
          reason: 'Anker $anker, Koordinate $k',
        );
      }
    }
  });
}
