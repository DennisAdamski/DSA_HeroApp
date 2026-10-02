import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ziehen_rules.dart';

void main() {
  test(
    'Schnellziehen bucht freie Marke und bestätigte Rücken-/Schilddauer',
    () {
      expect(
        gefechtsZiehplan(Ziehposition.guertel, schnellziehen: false).dauer,
        1,
      );
      expect(
        gefechtsZiehplan(Ziehposition.ruecken, schnellziehen: false).dauer,
        2,
      );
      expect(
        gefechtsZiehplan(
          Ziehposition.schildRuecken,
          schnellziehen: false,
        ).dauer,
        5,
      );
      expect(
        gefechtsZiehplan(Ziehposition.guertel, schnellziehen: true).freieMarke,
        true,
      );
      expect(
        gefechtsZiehplan(Ziehposition.ruecken, schnellziehen: true).dauer,
        1,
      );
      expect(
        gefechtsZiehplan(Ziehposition.schildRuecken, schnellziehen: true).dauer,
        3,
      );
    },
  );
}
