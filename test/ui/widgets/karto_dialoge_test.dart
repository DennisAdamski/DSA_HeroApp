import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_vital_block.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/animated_dice_row.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Bausteine der Dialoge am Spieltisch in beiden Oberflaechen.
void main() {
  final klassisch = buildAppTheme(
    brightness: Brightness.light,
    centerAppBarTitle: false,
  );
  final kartograph = buildKartoCompatTheme(
    buildKartoTheme(brightness: Brightness.light, centerAppBarTitle: false),
  );

  Future<void> zeige(
    WidgetTester tester,
    ThemeData theme,
    Widget kind, {
    bool ohneAnimation = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: ohneAnimation),
          child: child!,
        ),
        home: Scaffold(body: Center(child: kind)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget vital() => SizedBox(
    width: 380,
    child: InspectorVitalBlock(
      label: 'LeP',
      subtitle: 'Lebenspunkte',
      current: 18,
      max: 30,
      kind: VitalKind.lep,
      onChanged: (_) {},
    ),
  );

  TextSpan wertSpan(WidgetTester tester) {
    final zeile = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(InspectorVitalBlock),
            matching: find.byType(RichText),
          ),
        )
        .firstWhere((r) => r.text.toPlainText() == '18 / 30');
    // Text.rich verpackt die Spans in einen weiteren; der Wert liegt tiefer.
    TextSpan? suche(InlineSpan span) {
      if (span is! TextSpan) return null;
      if (span.text == '18') return span;
      for (final kind in span.children ?? const <InlineSpan>[]) {
        final treffer = suche(kind);
        if (treffer != null) return treffer;
      }
      return null;
    }

    return suche(zeile.text)!;
  }

  testWidgets('Vitalblock behaelt klassisch Serife und Messingetikett', (
    tester,
  ) async {
    await zeige(tester, klassisch, vital());
    expect(wertSpan(tester).style!.fontFamily, isNot(kSchriftDaten));
    final balken = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(balken.minHeight, 8);
  });

  testWidgets('Vitalblock nimmt unter Kartograph die Ressourcenfarbe', (
    tester,
  ) async {
    await zeige(tester, kartograph, vital());
    expect(wertSpan(tester).style!.fontFamily, kSchriftDaten);
    final balken = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(
      (balken.valueColor! as AlwaysStoppedAnimation<Color>).value,
      kartoHell.lebensenergie,
    );
    // Die Schrittknoepfe und ihre Schluessel bleiben dieselben.
    for (final key in <String>[
      'vital-block-minus-5',
      'vital-block-minus-1',
      'vital-block-plus-1',
      'vital-block-plus-5',
    ]) {
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
    }
  });

  testWidgets('ohne Systemanimationen steht das Wurfergebnis sofort', (
    tester,
  ) async {
    final steuerung = DiceRollController();
    var fertig = 0;
    await zeige(
      tester,
      kartograph,
      AnimatedDiceRow(
        diceSpec: const DiceSpec(count: 1, sides: 20),
        controller: steuerung,
        probeType: ProbeType.attribute,
        onRollComplete: () => fertig++,
      ),
      ohneAnimation: true,
    );
    steuerung.startRoll(<int>[7]);
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
    expect(steuerung.isRolling, isFalse);
    await tester.pump();
    expect(fertig, 1);
  });

  testWidgets('der Wurf rollt, wenn Bewegung erlaubt ist', (tester) async {
    final steuerung = DiceRollController();
    await zeige(
      tester,
      klassisch,
      AnimatedDiceRow(
        diceSpec: const DiceSpec(count: 1, sides: 6),
        controller: steuerung,
      ),
    );
    steuerung.startRoll(<int>[4]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(steuerung.isRolling, isTrue);
    await tester.pumpAndSettle();
    expect(steuerung.isRolling, isFalse);
  });

  test('das Kartograph-Theme traegt KartoTheme fuer die Palette', () {
    expect(kartograph.extension<KartoTheme>(), isNotNull);
  });
}
