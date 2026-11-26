import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_unterwegs.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reittier_probe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_verwaltungs_ziel.dart';

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
    KartoVerwaltungsZiel? ziel,
  }) => _TestVerwaltung(
    pruefung: () async => await pruefung?.call() ?? true,
    registrieren: onVerlassenRegistriert,
    gesperrt: korrekturenGesperrt,
    ziel: ziel,
  );

  @override
  Widget spielEigenschaftsproben({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) => Text('Eigenschaftsproben $heroId');

  @override
  Widget spielFavoritenproben({required String heroId}) =>
      Text('Häufige Proben $heroId');

  @override
  Widget spielKampfproben({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) => Text('Kampfproben $heroId');

  @override
  Widget spielZustand({
    required String heroId,
    required HeroComputedSnapshot werte,
    bool mitBelastung = true,
  }) {
    zustandMitBelastung.add(mitBelastung);
    return Text('Zustand $heroId');
  }

  /// Wert von `mitBelastung` je Bau der Zustandskachel.
  final List<bool> zustandMitBelastung = <bool>[];

  @override
  Widget spielEffekte({
    required String heroId,
    required HeroComputedSnapshot werte,
  }) => Text('Effekte $heroId');

  /// Grenzen, mit denen das Protokoll gebaut wurde (`null` = vollständig).
  final List<int?> protokollGrenzen = <int?>[];

  @override
  Widget spielProtokoll(HeroComputedSnapshot werte, {int? hoechstens}) {
    protokollGrenzen.add(hoechstens);
    return Text('Protokoll ${werte.state.diceLog.length}');
  }

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
  Future<void> probeWiederholen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required DiceLogEntry eintrag,
  }) async {
    aufrufe.add('probeWiederholen:$heroId:${eintrag.title}');
  }

  /// Schaltbar, damit Tests auch die Plattform ohne Regelindex prüfen können.
  bool regelnVerfuegbar = true;

  @override
  bool get regelnNachschlagenVerfuegbar => regelnVerfuegbar;

  @override
  Future<void> regelnNachschlagen({required BuildContext context}) async {
    aufrufe.add('regeln');
  }

  @override
  Future<void> berechnungsschritte({
    required BuildContext context,
    required String heroId,
  }) async {
    aufrufe.add('berechnungsschritte:$heroId');
  }

  @override
  Future<void> regelprofil({
    required BuildContext context,
    required String heroId,
  }) async {
    aufrufe.add('regelprofil:$heroId');
  }

  @override
  Future<void> rast({
    required BuildContext context,
    required String heroId,
  }) async {
    aufrufe.add('rast:$heroId');
  }

  @override
  Future<void> schadenErhalten({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
  }) async {
    aufrufe.add('schadenErhalten:$heroId');
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
  Future<void> ressourceSchritt({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required KartoRessource ressource,
    required int schritt,
  }) async {
    aufrufe.add('ressourceSchritt:$heroId:${ressource.name}:$schritt');
  }

  @override
  Future<void> begleiterWertAendern({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String begleiterId,
    required BegleiterPool pool,
    required RessourcenAenderung aenderung,
  }) async {
    aufrufe.add(
      'begleiter:$heroId:$begleiterId:${pool.name}:'
      '${switch (aenderung) {
        RessourcenSchritt(:final schritt) => 'schritt$schritt',
        RessourcenSetzen(:final wert) => 'setzen$wert',
      }}',
    );
  }

  @override
  Future<void> begleiterWundenAendern({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String begleiterId,
    required int schritt,
  }) async {
    aufrufe.add('wunden:$heroId:$begleiterId:$schritt');
  }

  @override
  Future<void> reittierProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String begleiterId,
    required ReittierProbeArt art,
  }) async {
    aufrufe.add('reittierProbe:$heroId:$begleiterId:${art.name}');
  }

  @override
  Future<void> standortSetzen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required String standort,
    String ortId = '',
    double? kartenX,
    double? kartenY,
  }) async {
    aufrufe.add(
      ortId.isEmpty
          ? 'standort:$heroId:$standort'
          : 'standort:$heroId:$standort:$ortId',
    );
  }

  @override
  Future<bool> reiseZustandSetzen({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required HeroUnterwegs? unterwegs,
    String? standort,
    String standortOrtId = '',
  }) async {
    aufrufe.add(
      'reise:$heroId:${unterwegs?.ziel ?? '-'}:${standort ?? '-'}'
      '${standortOrtId.isEmpty ? '' : ':$standortOrtId'}',
    );
    return true;
  }

  @override
  Future<void> vertrautenAktionen({
    required BuildContext context,
    required String heroId,
    required String begleiterId,
  }) async {
    aufrufe.add('vertrautenAktionen:$heroId:$begleiterId');
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
    this.ziel,
  });
  final KartoVerlassenPruefung pruefung;
  final ValueChanged<KartoVerlassenPruefung?> registrieren;
  final bool gesperrt;
  final KartoVerwaltungsZiel? ziel;
  @override
  State<_TestVerwaltung> createState() => _TestVerwaltungState();
}

class _TestVerwaltungState extends State<_TestVerwaltung> {
  final _draft = TextEditingController();
  KartoVerwaltungsAbschnitt? _abschnitt;

  // Wie die echte Verwaltung: beim Start und bei jedem Wunsch lesen.
  void _wunsch() => setState(() => _abschnitt = widget.ziel?.abschnitt);

  @override
  void initState() {
    super.initState();
    widget.registrieren(() => widget.pruefung());
    _abschnitt = widget.ziel?.abschnitt;
    widget.ziel?.addListener(_wunsch);
  }

  @override
  void dispose() {
    widget.ziel?.removeListener(_wunsch);
    widget.registrieren(null);
    _draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(widget.gesperrt ? 'Verwaltung gesperrt' : 'Verwaltungsinhalt'),
      if (_abschnitt != null) Text('Abschnitt ${_abschnitt!.name}'),
      TextField(key: const ValueKey('test-entwurf'), controller: _draft),
    ],
  );
}
