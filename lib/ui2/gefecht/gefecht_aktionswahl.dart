import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_aktionskatalog_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_freigabe_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Wählt eine benannte Handlung nach WdS S. 55 und bucht sie.
///
/// Freie Handlungen verbrauchen eine freie Aktion, Bewegen eine und Sprinten
/// zwei reguläre Aktionen. „Sich zu Boden werfen“ würfelt die GE-Probe; bei
/// Misslingen werden 1W6 INI in der Sitzung und 1W6 AuP frisch im
/// Heldenzustand abgezogen. Abbruch einer Probe bucht nichts.
Future<void> zeigeGefechtsBenannteAktion({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final katalog = ref.read(rulesCatalogProvider).asData?.value;
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  if (snapshot == null || s == null) return;
  final w = gefechtswerteFuer(snapshot, katalog: katalog);
  final wahl = await showDialog<GefechtsBenannteAktion>(
    context: context,
    builder: (_) => _Aktionswahl(
      pruefungen: {
        for (final a in GefechtsBenannteAktion.values)
          a: pruefeGefechtsBenannteAktion(s, w, a),
      },
    ),
  );
  if (wahl == null || !context.mounted) return;
  final frisch = ref.read(gefechtMitInitiativeProvider(heroId));
  if (frisch == null) return;
  final p = pruefeGefechtsBenannteAktion(frisch, w, wahl);
  if (p.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(p.gruende.join(' '));
  }
  final ctl = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!ctl.reservieren(id)) return;
  try {
    if (wahl != GefechtsBenannteAktion.zuBodenWerfen) {
      if (!ctl.abschliessen(id, w, p)) return;
      ctl.setzen(
        wendeGefechtsBenannteAktionAn(
          ref.read(gefechtMitInitiativeProvider(heroId))!,
          wahl,
        ),
      );
      return;
    }
    final ge = readAttributeValue(
      snapshot.probenEigenschaften,
      AttributeCode.ge,
    );
    final probe = await bestand.gefechtsProbe(
      context: context,
      ref: ref,
      heroId: heroId,
      request: gefechtsProbeMitBonus(
        buildAttributeProbeRequest(label: 'GE', effectiveValue: ge),
        null,
        ansageFolgemalus: frisch.ansageFolgemalus,
      ),
    );
    if (probe == null || !context.mounted) return;
    var ini = 0, aup = 0;
    if (!probe.success) {
      // Abbruch eines Folgewurfs bucht nichts, wie der Abbruch der GE-Probe.
      final iniWurf = await _w6(
        context,
        ref,
        heroId,
        bestand,
        'Sturz · INI-Verlust',
      );
      if (iniWurf == null || !context.mounted) return;
      final aupWurf = await _w6(
        context,
        ref,
        heroId,
        bestand,
        'Sturz · AuP-Verlust',
      );
      if (aupWurf == null || !context.mounted) return;
      ini = iniWurf;
      aup = aupWurf;
    }
    if (!ctl.abschliessen(id, w, p)) return;
    ctl.setzen(
      wendeGefechtsBenannteAktionAn(
        ref.read(gefechtMitInitiativeProvider(heroId))!,
        wahl,
        iniVerlust: ini,
      ),
    );
    if (aup > 0) {
      await ref
          .read(heroActionsProvider)
          .updateHeroState(
            heroId,
            (st) =>
                st.copyWith(currentAu: gefechtsAupNachSturz(st.currentAu, aup)),
          );
    }
  } finally {
    ctl.abbrechen(id);
  }
}

// Ein W6 über die gemeinsame Probe; `null` bei Abbruch.
Future<int?> _w6(
  BuildContext context,
  WidgetRef ref,
  String heroId,
  KartoGefechtsAdapter bestand,
  String titel,
) async {
  final r = await bestand.gefechtsProbe(
    context: context,
    ref: ref,
    heroId: heroId,
    request: ResolvedProbeRequest(
      type: ProbeType.genericRoll,
      title: titel,
      subtitle: '1W6',
      ruleHint: 'Sich zu Boden werfen, GE-Probe misslungen (WdS S. 55).',
      diceSpec: const DiceSpec(count: 1, sides: 6),
      targets: const [],
    ),
  );
  return r?.total;
}

// Gruppierte Liste mit Kosten, Regeltext und Sperrgrund je Handlung.
class _Aktionswahl extends StatelessWidget {
  const _Aktionswahl({required this.pruefungen});
  final Map<GefechtsBenannteAktion, Gefechtspruefung> pruefungen;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    Widget gruppe(String titel, GefechtsAktionskosten kosten) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(titel, style: texte.titleSmall),
        ),
        for (final e in pruefungen.entries)
          if (gefechtsAktionskosten(e.key) == kosten)
            ListTile(
              key: ValueKey('gefecht-aktion-${e.key.name}'),
              title: Text(gefechtsAktionsname(e.key)),
              subtitle: Text(
                e.value.status == Gefechtsfreigabe.gesperrt
                    ? gefechtsHauptgrund(e.value) ?? 'Gesperrt'
                    : gefechtsAktionsregel(e.key),
              ),
              enabled: e.value.status != Gefechtsfreigabe.gesperrt,
              onTap: () => Navigator.pop(context, e.key),
            ),
      ],
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('Aktion wählen', style: texte.titleLarge),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    gruppe('Freie Aktionen', GefechtsAktionskosten.frei),
                    gruppe('Eine Aktion', GefechtsAktionskosten.aktion),
                    gruppe('Zwei Aktionen', GefechtsAktionskosten.zweiAktionen),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
