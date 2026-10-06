import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

import '../../ui2/shell/karto_test_support.dart';

// Die Wirkabschluss-Methoden der Gefechtsbrücke gegen die echte
// Bestandsimplementierung (Restschuld „lib/ui-Importe des Wirkabschlusses“).

class _Repo extends FakeRepository {
  _Repo()
    : super(
        heroes: [testHero()],
        states: {
          'rondra': const HeroState(
            currentLep: 20,
            currentAsp: 20,
            currentKap: 0,
            currentAu: 30,
          ),
        },
      );

  bool fehler = false;

  @override
  Future<void> saveHeroState(String heroId, HeroState state) async {
    if (fehler) throw StateError('Speicher voll');
    await super.saveHeroState(heroId, state);
  }
}

const _adapter = KartoBestandsAdapterImpl();

void main() {
  late _Repo repo;
  late BuildContext kontext;
  late WidgetRef referenz;

  Future<void> starte(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = _Repo();
    final c = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: _adapter.gefechtsFehlerBereich(
              builder: (anzeige) => Consumer(
                builder: (ctx, ref, _) {
                  kontext = ctx;
                  referenz = ref;
                  ref.watch(heroComputedProvider('rondra'));
                  return Column(children: [const Text('Inhalt'), anzeige]);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('gefechtsZustand schreibt frisch, Fehler im Fehlerbereich', (
    tester,
  ) async {
    await starte(tester);
    // Eine Zwischenänderung an LeP bleibt erhalten; AsP zählt vom Gespeicherten.
    final gespeichert = (await repo.loadHeroState('rondra'))!;
    await repo.saveHeroState('rondra', gespeichert.copyWith(currentLep: 7));
    final neu = await _adapter.gefechtsZustand(
      context: kontext,
      ref: referenz,
      heroId: 'rondra',
      was: 'Gefechtsfolgen',
      aenderung: (z) => z.copyWith(currentAsp: z.currentAsp - 3),
    );
    expect(neu?.currentAsp, 17);
    expect(neu?.currentLep, 7);

    repo.fehler = true;
    final fehlgeschlagen = await _adapter.gefechtsZustand(
      context: kontext,
      ref: referenz,
      heroId: 'rondra',
      was: 'Gefechtsfolgen',
      aenderung: (z) => z.copyWith(currentAsp: z.currentAsp - 3),
    );
    await tester.pumpAndSettle();
    expect(fehlgeschlagen, isNull);
    expect(find.byKey(kZustandFehlerSchluessel), findsOneWidget);
    expect(
      find.text('Gefechtsfolgen nicht gespeichert: Speicher voll'),
      findsOneWidget,
    );
    expect((await repo.loadHeroState('rondra'))!.currentAsp, 17);
  });

  testWidgets('Armatrutz- und Attributo-Eingabe liefern Werte oder null', (
    tester,
  ) async {
    await starte(tester);
    final abbruch = _adapter.gefechtsArmatrutzWerte(kontext);
    await tester.pumpAndSettle();
    expect(find.text('Armatrutz – magische Rüstung'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(await abbruch, isNull);

    final armatrutz = _adapter.gefechtsArmatrutzWerte(kontext);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('armatrutz-input-rs')),
      '3',
    );
    await tester.tap(find.byKey(const ValueKey('armatrutz-input-confirm')));
    await tester.pumpAndSettle();
    final ActiveSpellEffectDetail? detail = await armatrutz;
    expect(detail?.amount, 3);

    final attributo = _adapter.gefechtsAttributoWerte(kontext);
    await tester.pumpAndSettle();
    expect(find.text('Attributo – Boni eingeben'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    final AttributeModifiers? boni = await attributo;
    expect(boni, isNull);
  });

  testWidgets('Wirkkosten öffnen den Ressourcendialog mit Blattkontext', (
    tester,
  ) async {
    await starte(tester);
    bool? imFehlerbereich;
    final offen = _adapter.gefechtsWirkkosten(
      context: kontext,
      heroId: 'rondra',
      karmal: false,
      kosten: 5,
      onUebernehmen: (blatt) async {
        imFehlerbereich =
            blatt.findAncestorWidgetOfExactType<ZustandFehlerBereich>() != null;
        return true;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Bestätigte Abschlusskosten: 5 AsP'), findsOneWidget);
    await tester.tap(find.text('Abschlusskosten übernehmen'));
    await tester.pumpAndSettle();
    await offen;
    expect(imFehlerbereich, isTrue);
    expect(find.text('Bestätigte Abschlusskosten: 5 AsP'), findsNothing);
  });
}
