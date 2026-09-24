import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ein in `pubspec.yaml` deklarierter Schriftschnitt.
typedef Schnitt = ({String familie, String pfad, String merkmal});

/// Liest den `fonts:`-Abschnitt aus `pubspec.yaml`.
///
/// Bewusst ein kleiner eigener Parser statt einer YAML-Abhaengigkeit: der
/// Abschnitt ist flach, stabil und kurz, und der Test soll ohne zusaetzliches
/// Paket laufen.
List<Schnitt> leseSchnitte() {
  final zeilen = File('pubspec.yaml').readAsLinesSync();
  final schnitte = <Schnitt>[];
  var imAbschnitt = false;
  var familie = '';
  String? offenerPfad;
  var merkmal = 'regular';

  void abgeben() {
    if (offenerPfad != null) {
      schnitte.add((familie: familie, pfad: offenerPfad!, merkmal: merkmal));
      offenerPfad = null;
      merkmal = 'regular';
    }
  }

  for (final zeile in zeilen) {
    final rumpf = zeile.trimLeft();
    final einzug = zeile.length - rumpf.length;
    if (rumpf.startsWith('#') || rumpf.isEmpty) continue;

    if (!imAbschnitt) {
      if (einzug == 2 && rumpf == 'fonts:') imAbschnitt = true;
      continue;
    }
    // Ein Schluessel auf gleicher oder geringerer Ebene beendet den Abschnitt.
    if (einzug <= 2) break;

    if (rumpf.startsWith('- family:')) {
      abgeben();
      familie = rumpf.substring('- family:'.length).trim();
    } else if (rumpf.startsWith('- asset:')) {
      abgeben();
      offenerPfad = rumpf.substring('- asset:'.length).trim();
    } else if (rumpf.startsWith('weight:')) {
      merkmal = 'weight ${rumpf.substring('weight:'.length).trim()}';
    } else if (rumpf.startsWith('style:')) {
      merkmal = 'style ${rumpf.substring('style:'.length).trim()}';
    }
  }
  abgeben();
  return schnitte;
}

void main() {
  // Nur die Familien der neuen Oberflaeche. Merriweather und Cinzel tragen
  // den Fehler noch, den dieser Test verhindern soll: ihre Eintraege fuer
  // Regular und 700 zeigen auf dieselbe Datei, der Fettschnitt liefert also
  // dieselben Glyphen. Beide fallen mit der alten Oberflaeche weg; dann wird
  // dieser Test auf alle Familien erweitert.
  const gepruefteFamilien = <String>{'Spectral', 'InterTight'};

  test('kein Schnitt teilt sich seine Datei mit einem anderen', () {
    final schnitte = leseSchnitte()
        .where((s) => gepruefteFamilien.contains(s.familie))
        .toList();
    expect(
      schnitte,
      isNotEmpty,
      reason: 'Die neuen Familien fehlen in pubspec.yaml.',
    );

    final nachFamilie = <String, List<Schnitt>>{};
    for (final s in schnitte) {
      nachFamilie.putIfAbsent(s.familie, () => <Schnitt>[]).add(s);
    }

    for (final eintrag in nachFamilie.entries) {
      final pfade = eintrag.value.map((s) => s.pfad).toList();
      final doppelte = <String>{};
      final gesehen = <String>{};
      for (final p in pfade) {
        if (!gesehen.add(p)) doppelte.add(p);
      }
      expect(
        doppelte,
        isEmpty,
        reason:
            'Familie ${eintrag.key} deklariert ${doppelte.join(", ")} '
            'mehrfach. Ein zweiter Eintrag auf dieselbe Datei registriert '
            'einen Schnitt, der dieselben Glyphen liefert - der Fettschnitt '
            'existiert dann nicht, er wird nur behauptet.',
      );
    }
  });

  test('jede deklarierte Schriftdatei liegt auch auf der Platte', () {
    for (final s in leseSchnitte()) {
      expect(
        File(s.pfad).existsSync(),
        isTrue,
        reason: '${s.familie} (${s.merkmal}) verweist auf ${s.pfad}.',
      );
    }
  });

  test('Spectral bringt vier eigene Schnitte mit', () {
    final spectral = leseSchnitte().where((s) => s.familie == 'Spectral');
    expect(spectral.map((s) => s.merkmal).toSet(), <String>{
      'regular',
      'weight 500',
      'weight 600',
      'style italic',
    });
  });

  test('Inter Tight ist genau einmal deklariert', () {
    // Die Familie liegt nur variabel vor. Das Gewicht setzt die Typo-Rolle
    // ueber fontVariations; ein zweiter Eintrag mit `weight:` waere genau der
    // Fehler aus dem ersten Test.
    final inter = leseSchnitte().where((s) => s.familie == 'InterTight');
    expect(inter, hasLength(1));
    expect(inter.single.merkmal, 'regular');
  });
}
