import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_begleiter.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

/// Würfelhilfen der Begleiter im Gefecht (Vertraute V3a): AT, PA und TP aus
/// dem Kampfprofil, ohne Schreibweg.
void main() {
  const kater = HeroCompanion(
    id: 'kater',
    name: 'Kater',
    typ: BegleiterTyp.vertrauter,
    vertrautenBindung: VertrautenBindung(artId: 'vart_katze'),
    angriffe: [
      HeroCompanionAttack(
        id: 'pranke',
        name: 'Prankenhieb',
        at: 10,
        pa: 5,
        tp: '1W6',
        steigerungAt: 2,
      ),
      HeroCompanionAttack(id: 'huf', name: 'Huf', at: 8, tp: 'Huf +2'),
    ],
  );

  Future<List<ResolvedProbeRequest>> zeige(
    WidgetTester tester, {
    bool mitProbe = true,
    bool gesperrt = false,
    double skalierung = 1,
    double breite = 390,
    HeroCompanion begleiter = kater,
  }) async {
    final anfragen = <ResolvedProbeRequest>[];
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        builder: (context, kind) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(skalierung)),
          child: kind!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: GefechtBegleiter(
              begleiter: [begleiter],
              gesperrt: gesperrt,
              onProbe: mitProbe
                  ? (request) async {
                      anfragen.add(request);
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gefecht-begleiter-kater')));
    await tester.pumpAndSettle();
    return anfragen;
  }

  Finder knopf(int angriff, String art) =>
      find.byKey(ValueKey('gefecht-begleiter-kater-$angriff-$art'));

  testWidgets('jeder Angriff bietet AT, PA und TP, soweit sie vorhanden sind', (
    tester,
  ) async {
    await zeige(tester);
    expect(knopf(0, 'at'), findsOneWidget);
    expect(knopf(0, 'pa'), findsOneWidget);
    expect(knopf(0, 'tp'), findsOneWidget);
    // Der Huf hat keine PA und keinen lesbaren TP-Ausdruck.
    expect(knopf(1, 'at'), findsOneWidget);
    expect(knopf(1, 'pa'), findsNothing);
    expect(knopf(1, 'tp'), findsNothing);
    expect(
      find.byKey(const ValueKey('gefecht-begleiter-kater-1-tp-hinweis')),
      findsOneWidget,
    );
  });

  testWidgets('die Knöpfe melden die Probe mit den wirksamen Werten', (
    tester,
  ) async {
    final anfragen = await zeige(tester);
    for (final art in ['at', 'pa', 'tp']) {
      await tester.ensureVisible(knopf(0, art));
      await tester.tap(knopf(0, art));
      await tester.pumpAndSettle();
    }
    expect(anfragen.map((r) => r.type), [
      ProbeType.combatAttack,
      ProbeType.combatParry,
      ProbeType.damage,
    ]);
    expect(anfragen[0].targets.single.value, 12, reason: 'AT 10 + 2');
    expect(anfragen[1].targets.single.value, 5);
    expect(anfragen[2].diceSpec.label, '1W6');
  });

  testWidgets('ein gebundener Vertrauter trägt den Hinweis „magisch“', (
    tester,
  ) async {
    await zeige(tester);
    expect(
      find.byKey(const ValueKey('gefecht-begleiter-kater-magisch')),
      findsOneWidget,
    );
  });

  testWidgets(
    'ohne Vertrautenbindung kein Hinweis, ohne Rückruf keine Knöpfe',
    (tester) async {
      await zeige(
        tester,
        mitProbe: false,
        begleiter: kater.copyWith(vertrautenBindung: null),
      );
      expect(knopf(0, 'at'), findsNothing);
      expect(
        find.byKey(const ValueKey('gefecht-begleiter-kater-magisch')),
        findsNothing,
      );
    },
  );

  testWidgets('gesperrt würfeln die Knöpfe nicht', (tester) async {
    final anfragen = await zeige(tester, gesperrt: true);
    await tester.ensureVisible(knopf(0, 'at'));
    await tester.tap(knopf(0, 'at'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(anfragen, isEmpty);
  });

  testWidgets('Kampfregeln der Art und Aurapanzer stehen im Profil', (
    tester,
  ) async {
    await zeige(
      tester,
      begleiter: kater.copyWith(
        startMr: 4,
        sonderfertigkeiten: const [
          HeroCompanionSonderfertigkeit(
            name: 'Aurapanzer',
            katalogId: 'magsf_aurapanzer',
          ),
        ],
      ),
    );
    final regeln = find.byKey(
      const ValueKey('gefecht-begleiter-kater-kampfregeln'),
    );
    await tester.ensureVisible(regeln);
    expect(tester.widget<Text>(regeln).data, contains('Hinterhalt (12)'));
    expect(
      find.byKey(const ValueKey('gefecht-begleiter-kater-aurapanzer')),
      findsOneWidget,
    );
  });

  testWidgets('schmal mit Textfaktor 2 ohne Überlauf', (tester) async {
    await zeige(tester, breite: 360, skalierung: 2);
    await tester.ensureVisible(knopf(0, 'tp'));
    expect(tester.takeException(), isNull);
  });
}
