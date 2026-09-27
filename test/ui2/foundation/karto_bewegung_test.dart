import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';

void main() {
  Future<Duration> dauerBei(WidgetTester tester, {required bool aus}) async {
    late Duration ergebnis;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: aus),
        child: Builder(
          builder: (context) {
            ergebnis = kartoDauer(context, Bewegung.mittel);
            return const SizedBox();
          },
        ),
      ),
    );
    return ergebnis;
  }

  testWidgets('Bewegung laeuft mit ihrer Dauer', (tester) async {
    expect(await dauerBei(tester, aus: false), Bewegung.mittel);
  });

  testWidgets('abgeschaltete Bewegung liefert null', (tester) async {
    // Unter Windows "Animationen anzeigen: aus", unter iOS "Bewegung
    // reduzieren". Jede Animation der neuen Oberflaeche nimmt ihre Dauer
    // ueber kartoDauer und steht dann sofort am Ziel.
    expect(await dauerBei(tester, aus: true), Duration.zero);
  });
}
