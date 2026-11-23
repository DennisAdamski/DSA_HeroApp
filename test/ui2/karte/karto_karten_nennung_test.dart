import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karte.dart';

// Die Namensnennung des Kartenmaterials darf nie gekürzt werden: Die Lizenz
// des Ulisses-Kartenpakets verlangt sie vollständig, samt Kennzeichnung als
// DSA-Fanprojekt. Vorher schnitt die schmale Ecke der Standort-Kachel sie
// nach zwei Zeilen ab („… Avesmaps (DSA-Fa…“).

final KartenKachelManifest _manifest = KartenKachelManifest(
  basis: Uri.parse('https://karten.example'),
  revision: 'r1',
  maxZoom: 6,
  nennung: const <String>[
    'Kartenmaterial © Ulisses Spiele',
    'Originalkarte: Ina Kramer',
    'Bearbeitung: Avesmaps (DSA-Fanprojekt)',
  ],
  lizenzUri: 'https://de.wiki-aventurica.de/wiki/Kartenpaket/Lizenz',
);

Finder get _nennung =>
    find.byKey(const ValueKey<String>('karto-karte-nennung'));

Future<void> _zeige(
  WidgetTester tester, {
  required double breite,
  KartenKachelManifest? manifest,
  bool knapp = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(
            width: breite,
            child: Align(
              alignment: Alignment.bottomRight,
              child: KartoKartenNennung(manifest: manifest, knapp: knapp),
            ),
          ),
        ),
      ),
    ),
  );
}

String _text(WidgetTester tester) => tester.widget<Text>(_nennung).data!;

void main() {
  testWidgets('schmale Ecke zeigt jede Pflichtzeile ungekürzt', (tester) async {
    await _zeige(tester, breite: 236, manifest: _manifest, knapp: true);

    final text = _text(tester);
    expect(text.split('\n'), <String>[
      'Kartenmaterial © Ulisses Spiele',
      'Originalkarte: Ina Kramer',
      'Bearbeitung: Avesmaps (DSA-Fanprojekt)',
      'Ortsdaten und Wege: Avesmaps (avesmaps.de)',
    ]);
    final absatz = tester.renderObject<RenderParagraph>(_nennung);
    expect(absatz.maxLines, isNull);
    expect(absatz.overflow, isNot(TextOverflow.ellipsis));
    expect(absatz.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Vollbild auf dem Handy behält auch die Lizenzadresse', (
    tester,
  ) async {
    await _zeige(tester, breite: 300, manifest: _manifest);

    final text = _text(tester);
    expect(text, contains('Bearbeitung: Avesmaps (DSA-Fanprojekt)'));
    expect(text, contains('Lizenz: https://de.wiki-aventurica.de/wiki/'));
    final absatz = tester.renderObject<RenderParagraph>(_nennung);
    expect(absatz.maxLines, isNull);
    expect(absatz.didExceedMaxLines, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ohne Nennung im Manifest gelten die Pflichtteile', (
    tester,
  ) async {
    final ohne = KartenKachelManifest(
      basis: Uri.parse('https://karten.example'),
      revision: 'r1',
      maxZoom: 6,
    );
    await _zeige(tester, breite: 236, manifest: ohne, knapp: true);

    expect(
      _text(tester).split('\n').take(3),
      KartoKartenNennung.kartenmaterialTeile,
    );
  });

  testWidgets('ohne Kartenbild nur die Ortsdaten', (tester) async {
    await _zeige(tester, breite: 236, knapp: true);

    expect(_text(tester), 'Ortsdaten und Wege: Avesmaps (avesmaps.de)');
  });
}
