import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/special_ability_picker.dart';

const _hero = HeroSheet(
  id: 'picker',
  name: 'Held',
  level: 1,
  attributes: Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
);
const _catalog = [
  SpecialAbilityDef(id: 'owned', name: 'Bekannte Gabe', gruppe: 'karmal'),
  SpecialAbilityDef(id: 'new', name: 'Neue Gabe', gruppe: 'karmal'),
];

void main() {
  testWidgets(
    'Bestand bleibt; Override und Suche gelten auch nach erneutem Öffnen',
    (tester) async {
      var hero = _hero;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSpecialAbilityPicker(
                  context: context,
                  title: 'Karmale Sonderfertigkeiten',
                  catalog: _catalog,
                  ownedNamesLower: {'bekannte gabe'},
                  verfuegbareAp: 0,
                  episch: false,
                  hero: hero,
                  onShowInapplicableChanged: (value) async {
                    hero = hero.copyWith(
                      showInapplicableSpecialAbilities: value,
                    );
                  },
                  onAdd: (_, _, _) {},
                  onRemove: (_) {},
                ),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Bekannte Gabe'), findsOneWidget);
      expect(find.text('Neue Gabe'), findsNothing);
      await tester.tap(find.text('Unpassende Sonderfertigkeiten anzeigen'));
      await tester.pumpAndSettle();
      expect(find.text('Neue Gabe'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Neue');
      await tester.pumpAndSettle();
      expect(find.text('Bekannte Gabe'), findsNothing);
      expect(find.text('Neue Gabe'), findsOneWidget);
      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Neue Gabe'), findsOneWidget);
      await tester.tap(find.text('Unpassende Sonderfertigkeiten anzeigen'));
      await tester.pumpAndSettle();
      expect(find.text('Neue Gabe'), findsNothing);
      expect(find.text('Bekannte Gabe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
