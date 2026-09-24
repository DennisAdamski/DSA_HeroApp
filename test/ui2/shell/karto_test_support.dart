import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';

const testCatalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
);

HeroSheet testHero([String id = 'rondra', String name = 'Rondra']) => HeroSheet(
  id: id,
  name: name,
  level: 1,
  attributes: Attributes(
    mu: 14,
    kl: 12,
    inn: 13,
    ch: 11,
    ff: 10,
    ge: 12,
    ko: 14,
    kk: 13,
  ),
  apTotal: 1000,
  apSpent: 500,
  apAvailable: 500,
);

class TestBestand implements KartoBestandsAdapter {
  Future<bool> Function()? pruefung;

  /// Zählt die Aufrufe je Bestandsaktion für die Prüfungen der Spielansicht.
  final List<String> aufrufe = <String>[];

  @override
  Widget verwaltung({
    required String heroId,
    required bool korrekturenGesperrt,
    required ValueChanged<KartoVerlassenPruefung?> onVerlassenRegistriert,
  }) => _TestVerwaltung(
    pruefung: () async => await pruefung?.call() ?? true,
    registrieren: onVerlassenRegistriert,
    gesperrt: korrekturenGesperrt,
  );

  @override
  Widget spielEigenschaftsproben({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) => Text('Eigenschaftsproben $heroId');

  @override
  Widget spielKampfproben({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) => Text('Kampfproben $heroId');

  @override
  Widget spielZustand({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) => Text('Zustand $heroId');

  @override
  Widget spielEffekte({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) => Text('Effekte $heroId');

  @override
  Widget spielProtokoll(HeroComputedSnapshot werte) =>
      Text('Protokoll ${werte.state.diceLog.length}');

  @override
  Widget planKatalog(String heroId) => Text('Plankatalog $heroId');
  @override
  Widget planHistorie(String heroId) => Text('Planhistorie $heroId');
  @override
  Future<void> heldenVerwalten(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(appBar: AppBar(), body: const Text('Bestandshelden')),
      ),
    );
  }

  @override
  Future<void> anmelden(
    BuildContext context, {
    bool registrieren = false,
  }) async {
    aufrufe.add(registrieren ? 'registrieren' : 'anmelden');
  }

  @override
  Future<void> einstellungen(
    BuildContext context, {
    KartoVerlassenPruefung? vorOberflaechenwechsel,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: const Text('Bestandseinstellungen'),
        ),
      ),
    );
  }

  @override
  Future<void> probeSuchen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
  }) async {
    aufrufe.add('probeSuchen:$heroId');
  }

  @override
  Future<void> rast({
    required BuildContext context,
    required String heroId,
  }) async {
    aufrufe.add('rast:$heroId');
  }

  @override
  Future<void> effekte({
    required BuildContext context,
    required String heroId,
  }) async {
    aufrufe.add('effekte:$heroId');
  }

  @override
  Future<void> ressourceBearbeiten({
    required BuildContext context,
    required String heroId,
    required KartoRessource ressource,
  }) async {
    aufrufe.add('ressource:$heroId:${ressource.name}');
  }

  @override
  Widget heldenbild({
    required String heroId,
    required String dateiname,
    required double groesse,
    required Widget ersatz,
  }) {
    aufrufe.add('heldenbild:$heroId:$dateiname');
    return SizedBox(
      width: groesse,
      height: groesse,
      child: Center(child: Text('Bild $dateiname')),
    );
  }
}

class _TestVerwaltung extends StatefulWidget {
  const _TestVerwaltung({
    required this.pruefung,
    required this.registrieren,
    required this.gesperrt,
  });
  final KartoVerlassenPruefung pruefung;
  final ValueChanged<KartoVerlassenPruefung?> registrieren;
  final bool gesperrt;
  @override
  State<_TestVerwaltung> createState() => _TestVerwaltungState();
}

class _TestVerwaltungState extends State<_TestVerwaltung> {
  final _draft = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.registrieren(() => widget.pruefung());
  }

  @override
  void dispose() {
    widget.registrieren(null);
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(widget.gesperrt ? 'Verwaltung gesperrt' : 'Verwaltungsinhalt'),
      TextField(key: const ValueKey('test-entwurf'), controller: _draft),
    ],
  );
}
