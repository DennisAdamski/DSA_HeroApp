import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelraster.dart';

void main() {
  test('Spaltenzahl folgt der Breite und endet bei vier', () {
    expect(kartoRasterSpalten(299, luecke: 16), 1);
    expect(kartoRasterSpalten(616, luecke: 16), 2);
    expect(kartoRasterSpalten(615, luecke: 16), 1);
    expect(kartoRasterSpalten(932, luecke: 16), 3);
    expect(kartoRasterSpalten(4000, luecke: 16), kRasterSpaltenMax);
    expect(kartoRasterSpalten(double.infinity), 1);
  });

  test('Spannen werden auf die Spaltenzahl gekappt', () {
    expect(kartoRasterSpanne(SpielkachelBreite.schmal, 3), 1);
    expect(kartoRasterSpanne(SpielkachelBreite.mittel, 3), 2);
    expect(kartoRasterSpanne(SpielkachelBreite.mittel, 1), 1);
    expect(kartoRasterSpanne(SpielkachelBreite.voll, 3), 3);
  });

  Future<void> zeige(
    WidgetTester tester,
    double breite,
    List<(SpielkachelBreite, double)> kacheln,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: breite,
            child: KartoKachelraster(
              luecke: 10,
              children: [
                for (final (i, (art, hoehe)) in kacheln.indexed)
                  KartoRasterKachel(
                    breite: art,
                    child: SizedBox(key: ValueKey<int>(i), height: hoehe),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Rect lage(WidgetTester tester, int i) =>
      tester.getRect(find.byKey(ValueKey<int>(i)));

  testWidgets('dicht gepackt: eine kurze Kachel füllt die Lücke', (
    tester,
  ) async {
    // 3 Spalten à 300 bei 10 Lücke.
    await zeige(tester, 920, const [
      (SpielkachelBreite.voll, 50),
      (SpielkachelBreite.mittel, 200),
      (SpielkachelBreite.schmal, 80),
      (SpielkachelBreite.schmal, 80),
      (SpielkachelBreite.schmal, 40),
    ]);
    expect(lage(tester, 0), const Rect.fromLTWH(0, 0, 920, 50));
    expect(lage(tester, 1), const Rect.fromLTWH(0, 60, 610, 200));
    expect(lage(tester, 2), const Rect.fromLTWH(620, 60, 300, 80));
    expect(lage(tester, 3), const Rect.fromLTWH(620, 150, 300, 80));
    // Rechts ist bei 240 frei, links erst bei 270: die Kachel rückt nach rechts.
    expect(lage(tester, 4), const Rect.fromLTWH(620, 240, 300, 40));
    final raster = tester.getSize(find.byType(KartoKachelraster));
    expect(raster.height, 280);
  });

  testWidgets('eine Spalte: alles untereinander in voller Breite', (
    tester,
  ) async {
    await zeige(tester, 360, const [
      (SpielkachelBreite.mittel, 30),
      (SpielkachelBreite.schmal, 20),
    ]);
    expect(lage(tester, 0), const Rect.fromLTWH(0, 0, 360, 30));
    expect(lage(tester, 1), const Rect.fromLTWH(0, 40, 360, 20));
  });

  testWidgets('volle Breite wartet auf die tiefste Spalte', (tester) async {
    await zeige(tester, 610, const [
      (SpielkachelBreite.schmal, 100),
      (SpielkachelBreite.schmal, 30),
      (SpielkachelBreite.voll, 20),
    ]);
    expect(lage(tester, 2), const Rect.fromLTWH(0, 110, 610, 20));
  });
}
