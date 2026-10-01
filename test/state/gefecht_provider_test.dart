import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';

void main() {
  test('Navigation, Abbruch und doppelte Auswertung behalten getrennte Sitzungen', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(gefechtProvider('a').notifier);
    controller.beginnen(6);
    expect(container.read(gefechtProvider('b')), isNull);
    expect(controller.reservieren('1'), true);
    expect(controller.reservieren('2'), false);
    controller.abbrechen('1');
    expect(container.read(gefechtProvider('a'))!.angriffeVerbraucht, 0);
    const w = Gefechtswerte(iniBasis: 10, at: 12, pa: 10, ausweichen: 8);
    final f = pruefeGefechtsaktion(container.read(gefechtProvider('a'))!, w,
      Gefechtsaktion.angriff);
    controller.reservieren('3');
    expect(controller.abschliessen('3', w, f), true);
    expect(controller.abschliessen('3', w, f), false);
    expect(container.read(gefechtProvider('a'))!.angriffeVerbraucht, 1);
    controller.beenden();
    expect(container.read(gefechtProvider('a')), isNull);
  });
}
