import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';

import '../../rules/gefecht_ansagen_paket2_test.dart' as melee;
import '../../rules/gefecht_laden_rules_test.dart' as ranged;
import '../shell/karto_test_support.dart';

// Große Testfläche hält alle Felder sichtbar; die echte Dialogstruktur bleibt bestehen.
Future<void> _dialog(
  WidgetTester tester,
  HeroComputedSnapshot snapshot, {
  Gefechtszustand zustand = const Gefechtszustand(iniWurf: 6, dk: 'N'),
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GefechtAktionsdialog(
          zustand: zustand,
          werte: snapshot,
          katalog: testCatalog,
          aktion: Gefechtsaktion.angriff,
          titel: 'Angreifen',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Sendet weitere Zeichen über dieselbe Tastaturverbindung ohne erneutes Fokussieren.
Future<void> _tippen(WidgetTester tester, Finder feld) async {
  await tester.ensureVisible(feld);
  await tester.tap(feld);
  await tester.pumpAndSettle();
  final edit = find.descendant(of: feld, matching: find.byType(EditableText));
  final state = tester.state<EditableTextState>(edit);
  for (final text in ['1', '12', '-', '1', '12']) {
    expect(tester.testTextInput.isVisible, true);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.state<EditableTextState>(edit), same(state));
    expect(state.widget.focusNode.hasFocus, true);
    expect(state.widget.controller.text, text);
    expect(state.widget.controller.selection.baseOffset, text.length);
  }
}

void main() {
  for (final label in ['Finte', 'Wuchtschlag', 'Weitere Erschwernis']) {
    testWidgets(
      'I1 $label behält Tastatur und Cursor bei dynamischen Meldungen',
      (t) async {
        await _dialog(t, melee.ansageSnapshot());
        final feld = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await _tippen(t, feld);
        expect(t.takeException(), isNull);
      },
    );
  }
  for (final label in [
    'Fernkampfansage',
    'Entfernung in Schritt',
    'Situationszuschlag',
  ]) {
    testWidgets('I1 FK $label behält inkrementelle Eingabe', (t) async {
      await _dialog(
        t,
        ranged.ladeSnapshot(),
        zustand: const Gefechtszustand(
          iniWurf: 6,
          kontext: Gefechtskontext(entfernung: 5, situationsZuschlag: 0),
        ),
      );
      final feld = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await _tippen(t, feld);
      expect(t.takeException(), isNull);
    });
  }
  for (final aenderung in ['Geschoss', 'Profil', 'Unverändert']) {
    final geaendert = aenderung != 'Unverändert';
    testWidgets(
      'I2 Dialog: $aenderung, bekannte Entladung bleibt verbindlich',
      (t) async {
        final alt = ranged.ladeSnapshot();
        final zustand = bestaetigeGefechtsLadung(
          const Gefechtszustand(
            iniWurf: 6,
            kontext: Gefechtskontext(entfernung: 5, situationsZuschlag: 0),
          ),
          alt.hero.combatConfig.selectedWeapon,
          false,
        );
        var aktuell = ranged.ladeSnapshot(
          geschoss: aenderung == 'Geschoss' ? 1 : 0,
        );
        if (aenderung == 'Profil') {
          final config = aktuell.hero.combatConfig;
          final waffe = config.selectedWeapon.copyWith(tpFlat: 9);
          aktuell = buildHeroComputedSnapshot(
            hero: aktuell.hero.copyWith(
              combatConfig: config.copyWith(weapons: [waffe]),
            ),
            state: const HeroState.empty(),
            catalog: testCatalog,
            epicAdvantagesActive: false,
          );
        }
        await _dialog(t, aktuell, zustand: zustand);
        final feld = find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<bool> &&
              w.decoration.labelText == 'Waffe geladen / wurfbereit?',
        );
        if (geaendert) {
          await t.ensureVisible(feld);
          await t.tap(feld);
          await t.pumpAndSettle();
          await t.tap(find.text('Ja').last);
          await t.pumpAndSettle();
          expect(
            find.textContaining('Ladezustand dieser Waffe bestätigen.'),
            findsNothing,
          );
          expect(
            t
                .widget<FilledButton>(
                  find.byKey(const ValueKey('gefecht-auftrag-starten')),
                )
                .onPressed,
            isNotNull,
          );
        } else {
          expect(
            t.widget<DropdownButtonFormField<bool>>(feld).onChanged,
            isNull,
          );
          expect(
            t
                .widget<FilledButton>(
                  find.byKey(const ValueKey('gefecht-auftrag-starten')),
                )
                .onPressed,
            isNull,
          );
          expect(find.textContaining('Waffe ist nicht geladen'), findsWidgets);
        }
      },
    );
  }
}
