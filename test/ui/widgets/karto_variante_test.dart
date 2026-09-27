import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_badge.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_empty_state.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_metric_tile.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_page_scaffold.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_tab_header.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_rahmen.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

/// Die Bestandsbausteine teilen sich beide Oberflaechen. Unter Codex muessen
/// sie bleiben, wie sie waren; unter Kartograph zeichnen sie sich neu.
void main() {
  final klassisch = buildAppTheme(
    brightness: Brightness.light,
    centerAppBarTitle: false,
  );
  final kartograph = buildKartoCompatTheme(
    buildKartoTheme(brightness: Brightness.light, centerAppBarTitle: false),
  );

  Future<void> zeige(WidgetTester tester, ThemeData theme, Widget kind) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: SingleChildScrollView(child: kind)),
      ),
    );
    // Ein Themenwechsel zwischen zwei Aufrufen wird ueberblendet; erst an
    // dessen Ende traegt das Theme die Erweiterungen des Ziels.
    await tester.pumpAndSettle();
  }

  TextStyle stilVon(WidgetTester tester, String text) {
    final widget = tester.widget<Text>(find.text(text));
    return widget.style!;
  }

  testWidgets('die Variante erkennt nur Kartograph', (tester) async {
    KartoTheme? unterCodex;
    KartoTheme? unterKarto;
    await zeige(
      tester,
      klassisch,
      Builder(
        builder: (context) {
          unterCodex = kartoVariante(context);
          return const SizedBox();
        },
      ),
    );
    await zeige(
      tester,
      kartograph,
      Builder(
        builder: (context) {
          unterKarto = kartoVariante(context);
          return const SizedBox();
        },
      ),
    );
    expect(unterCodex, isNull);
    expect(unterKarto, isNotNull);
  });

  group('CodexSectionCard', () {
    const karte = CodexSectionCard(
      title: 'Basisinformationen',
      subtitle: 'Name und Herkunft',
      child: Text('Inhalt'),
    );

    testWidgets('bleibt klassisch eine Karte', (tester) async {
      await zeige(tester, klassisch, karte);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(KartoFlaeche), findsNothing);
    });

    testWidgets('ist unter Kartograph eine Flaeche mit Abschnittstitel', (
      tester,
    ) async {
      await zeige(tester, kartograph, karte);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(KartoFlaeche), findsOneWidget);
      final titel = stilVon(tester, 'Basisinformationen');
      expect(titel.fontFamily, kSchriftTitel);
      expect(titel.fontSize, kartograph.textTheme.abschnitt.fontSize);
      expect(find.text('Inhalt'), findsOneWidget);
    });
  });

  group('CodexTabHeader', () {
    const kopf = CodexTabHeader(
      title: 'Ausrüstungs-Ledger',
      subtitle: 'Traglast und Herkunft',
    );

    testWidgets('traegt klassisch seinen Kasten', (tester) async {
      await zeige(tester, klassisch, kopf);
      final kasten = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Ausrüstungs-Ledger'),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(kasten.decoration, isA<BoxDecoration>());
    });

    testWidgets('steht unter Kartograph ohne Kasten', (tester) async {
      await zeige(tester, kartograph, kopf);
      expect(
        find.ancestor(
          of: find.text('Ausrüstungs-Ledger'),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
      expect(stilVon(tester, 'Ausrüstungs-Ledger').fontFamily, kSchriftTitel);
    });
  });

  group('CodexMetricTile', () {
    const kachel = CodexMetricTile(label: 'AT', value: '14', highlight: true);

    InlineSpan wertSpan(WidgetTester tester) {
      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(CodexMetricTile),
          matching: find.byType(RichText),
        ),
      );
      final wurzel = rich.text as TextSpan;
      return wurzel.children!.first is TextSpan
          ? (wurzel.children!.first as TextSpan).children!.last
          : wurzel.children!.last;
    }

    testWidgets('setzt den Wert klassisch in die Serife', (tester) async {
      await zeige(tester, klassisch, kachel);
      final wert = wertSpan(tester) as TextSpan;
      expect(wert.style!.fontFamily, isNot(kSchriftDaten));
    });

    testWidgets('setzt ihn unter Kartograph in Tabellenziffern', (
      tester,
    ) async {
      await zeige(tester, kartograph, kachel);
      final wert = wertSpan(tester) as TextSpan;
      expect(wert.style!.fontFamily, kSchriftDaten);
      expect(
        wert.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final flaeche = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(CodexMetricTile),
              matching: find.byType(Material),
            )
            .first,
      );
      // Hervorhebung als Messingkante, nicht als Toenung.
      expect((flaeche.shape! as KartoRahmen).akzent, kartoHell.messing);
    });
  });

  testWidgets('CodexBadge ist unter Kartograph ein kleines Element', (
    tester,
  ) async {
    BorderRadius radius() {
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.text('Neu'), matching: find.byType(Container))
            .first,
      );
      return (box.decoration! as BoxDecoration).borderRadius! as BorderRadius;
    }

    await zeige(tester, klassisch, const CodexBadge(label: 'Neu'));
    final vorher = radius();
    await zeige(tester, kartograph, const CodexBadge(label: 'Neu'));
    expect(radius(), BorderRadius.circular(kKartoRadiusKlein));
    expect(vorher, isNot(BorderRadius.circular(kKartoRadiusKlein)));
  });

  testWidgets('CodexEmptyState zeigt unter Kartograph die Kompassrose', (
    tester,
  ) async {
    const leer = CodexEmptyState(
      title: 'Noch leer',
      message: 'Lege etwas an.',
      assetPath: 'assets/ui/codex/empty_ledger.png',
    );
    await zeige(tester, klassisch, leer);
    expect(find.byType(KartoKompassrose), findsNothing);
    await zeige(tester, kartograph, leer);
    expect(find.byType(KartoKompassrose), findsOneWidget);
    expect(find.text('Noch leer'), findsOneWidget);
  });

  testWidgets('CodexPageScaffold legt unter Kartograph Papier unter', (
    tester,
  ) async {
    const seite = CodexPageScaffold(child: Text('Seite'));
    await zeige(tester, klassisch, const SizedBox(height: 200, child: seite));
    expect(find.byType(KartoPapier), findsNothing);
    await zeige(tester, kartograph, const SizedBox(height: 200, child: seite));
    expect(find.byType(KartoPapier), findsOneWidget);
  });

  group('FlexibleTable', () {
    final tabelle = SizedBox(
      width: 400,
      child: FlexibleTable(
        headerCells: const [Text('Gegenstand'), Text('Anzahl')],
        rows: const [
          FlexibleTableRow(cells: [Text('Wolldecke'), Text('12')]),
          FlexibleTableRow(cells: [Text('Seil'), Text('3')]),
        ],
        numerischeSpalten: const {1},
      ),
    );

    testWidgets('bleibt klassisch linksbuendig im getoenten Kasten', (
      tester,
    ) async {
      await zeige(tester, klassisch, tabelle);
      expect(
        find.ancestor(of: find.text('12'), matching: find.byType(Align)),
        findsNothing,
      );
    });

    testWidgets('setzt Zahlen unter Kartograph rechtsbuendig', (tester) async {
      await zeige(tester, kartograph, tabelle);
      final ausrichtung = tester.widget<Align>(
        find.ancestor(of: find.text('12'), matching: find.byType(Align)).first,
      );
      expect(ausrichtung.alignment, Alignment.centerRight);
      // Der Text der Zahl bleibt linksbuendig in der Zelle ohne Ausrichtung.
      expect(
        find.ancestor(of: find.text('Wolldecke'), matching: find.byType(Align)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('das Codex-Theme fuehrt kein KartoTheme', () {
    // Grundlage der Erkennung: faende sich hier je ein KartoTheme, zeichnete
    // die alte Oberflaeche ungefragt im neuen Stil.
    expect(klassisch.extension<KartoTheme>(), isNull);
    expect(klassisch.extension<CodexTheme>(), isNotNull);
  });

  testWidgets('epischer Akzent und Radien folgen der Oberflaeche', (
    tester,
  ) async {
    Color? akzent;
    double? radius;
    double? radiusKlein;
    Widget messe() => Builder(
      builder: (context) {
        akzent = epischerAkzent(context);
        radius = kartoRadiusOder(context, 12);
        radiusKlein = kartoRadiusOder(context, 12, klein: true);
        return const SizedBox();
      },
    );

    await zeige(tester, klassisch, messe());
    expect(akzent, const Color(0xFFB8860B));
    expect(radius, 12);
    expect(radiusKlein, 12);

    await zeige(tester, kartograph, messe());
    expect(akzent, kartoHell.messing);
    expect(radius, kKartoRadius);
    expect(radiusKlein, kKartoRadiusKlein);
  });
}
