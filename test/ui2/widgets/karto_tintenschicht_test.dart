import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

/// Kacheln auf Kartograph-Flaechen zeichnen Tinte und Hintergrund auf dem
/// naechsten `Material`. Papier und Flaeche sind farbige Boxen; ohne eigene
/// transparente Materialschicht verschwaende beides darunter, und Flutter
/// meldet "ListTile background color or ink splashes may be invisible".
void main() {
  Future<bool> zeige(
    WidgetTester tester,
    Brightness helligkeit,
    Widget Function(Widget kachel) flaeche,
  ) async {
    var wert = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: helligkeit,
          centerAppBarTitle: false,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => flaeche(
              // Genau die Form des gemeldeten Schalters im Faehigkeitenbaum.
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Unpassende Sonderfertigkeiten anzeigen'),
                value: wert,
                onChanged: (neu) => setState(() => wert = neu),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    return wert;
  }

  void materialDazwischen(WidgetTester tester, Type flaeche) {
    final zwischen = find.descendant(
      of: find.byType(flaeche),
      matching: find.ancestor(
        of: find.byType(ListTile),
        matching: find.byType(Material),
      ),
    );
    expect(zwischen, findsWidgets);
  }

  for (final helligkeit in Brightness.values) {
    testWidgets('Kachel direkt auf dem Papier (${helligkeit.name})', (
      tester,
    ) async {
      final wert = await zeige(
        tester,
        helligkeit,
        (kachel) => KartoPapier(child: kachel),
      );
      expect(tester.takeException(), isNull);
      materialDazwischen(tester, KartoPapier);
      expect(wert, isTrue);
    });

    testWidgets('Kachel direkt in einer Flaeche (${helligkeit.name})', (
      tester,
    ) async {
      final wert = await zeige(
        tester,
        helligkeit,
        (kachel) =>
            KartoFlaeche(innen: const EdgeInsets.all(16), child: kachel),
      );
      expect(tester.takeException(), isNull);
      materialDazwischen(tester, KartoFlaeche);
      expect(wert, isTrue);
    });
  }
}
