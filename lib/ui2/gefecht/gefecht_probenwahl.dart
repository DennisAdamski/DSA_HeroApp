import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_talent_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_zahlfeld.dart';

/// Eine wählbare Talent- oder Eigenschaftsprobe des Gefechts.
class GefechtProbenkandidat {
  /// [request] ist bereits mit dem TaW* bzw. Eigenschaftswert aufgelöst.
  const GefechtProbenkandidat(
    this.name,
    this.detail,
    this.request, {
    this.ausweichen = false,
  });
  final String name, detail;
  final ResolvedProbeRequest request;

  /// Ausweichprobe auf ein verwandtes Talent (Meisterentscheid); erscheint
  /// nur bei einer Suche.
  final bool ausweichen;
}

/// Talente mit TaW* und Eigenschaften, alphabetisch; Kampftalente fehlen.
///
/// AT, PA und Zauber laufen über ihre eigenen Gefechtsaktionen, damit Budget,
/// Distanz und Wirkdauer gelten.
List<GefechtProbenkandidat> gefechtsProbenkandidaten(
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog, {
  required bool epicAdvantagesActive,
  int? talentBeOverride,
}) {
  final talente = <GefechtProbenkandidat>[];
  for (final t in katalog.talents) {
    if (t.group == 'Kampftalent') continue;
    final wert = talentProbenwertFuer(
      snapshot: snapshot,
      talent: t,
      epicAdvantagesActive: epicAdvantagesActive,
      talentBeOverride: talentBeOverride,
    );
    if (wert == null) continue;
    final kette = wert.ziele.map((z) => z.label).join('/');
    talente.add(
      GefechtProbenkandidat(
        t.name,
        '$kette · TaW* ${wert.taw}',
        buildTalentProbeRequest(
          title: t.name,
          targets: wert.ziele,
          basePool: wert.taw,
          hasSpecialization: wert.spezialisierung,
        ),
      ),
    );
  }
  talente.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  final ausweichen = [
    for (final e in talentErsatzproben(
      snapshot: snapshot,
      katalog: katalog.talents,
      epicAdvantagesActive: epicAdvantagesActive,
      talentBeOverride: talentBeOverride,
    ))
      GefechtProbenkandidat(
        e.request.title.replaceFirst('Talentprobe: ', ''),
        'Ausweichen · Meisterentscheid · TaW* ${e.request.basePool}'
        '${e.option.bedingung == null ? '' : ' · ${e.option.bedingung}'}',
        e.request,
        ausweichen: true,
      ),
  ];
  final eigenschaften = [
    for (final code in AttributeCode.values)
      GefechtProbenkandidat(
        attributeCodeKey(code),
        'Eigenschaft · ${readAttributeValue(snapshot.probenEigenschaften, code)}',
        buildAttributeProbeRequest(
          label: attributeCodeKey(code),
          effectiveValue: readAttributeValue(
            snapshot.probenEigenschaften,
            code,
          ),
        ),
      ),
  ];
  return [...talente, ...ausweichen, ...eigenschaften];
}

/// Wählt eine Probe, ihren Zeitbedarf und würfelt sie im Gefecht.
///
/// Die Probe trägt Ansagefolgemalus und passenden Mirakelbonus wie jede
/// Fachprobe. Je nach Zeitbedarf wird keine, eine freie oder eine reguläre
/// Aktion gebucht; ein Talenteinsatz wird nach WdS S. 55 zu Beginn gewürfelt
/// und bleibt mit der verkürzten Restdauer als Handlung offen.
Future<void> zeigeGefechtsTalentprobe({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final katalog = ref.read(heroRulesCatalogProvider(heroId)).asData?.value;
  if (snapshot == null || katalog == null) {
    throw StateError('Spielwerte oder Regelkatalog werden geladen.');
  }
  final episch = ref.read(heroEpicAdvantagesActiveProvider(heroId));
  final kandidat = await showDialog<GefechtProbenkandidat>(
    context: context,
    builder: (_) => _Probenwahl(
      kandidaten: gefechtsProbenkandidaten(
        snapshot,
        katalog,
        epicAdvantagesActive: episch,
        talentBeOverride: ref.read(talentBeOverrideProvider(heroId)),
      ),
    ),
  );
  if (kandidat == null || !context.mounted) return;
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  if (s == null) return;
  final w = gefechtswerteFuer(snapshot, katalog: katalog);
  final wahl = await showDialog<(GefechtsZeitbedarf, int, int)>(
    context: context,
    builder: (_) => _Zeitbedarf(kandidat: kandidat, zustand: s, werte: w),
  );
  if (wahl == null || !context.mounted) return;
  final (zeit, erschwernis, geplant) = wahl;
  final frisch = ref.read(gefechtMitInitiativeProvider(heroId));
  if (frisch == null) return;
  final p = pruefeGefechtsZeitbedarf(frisch, w, zeit);
  if (p != null && p.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(p.gruende.join(' '));
  }
  final basis = modifiziereGefechtsWirkprobe(kandidat.request, erschwernis);
  final request = gefechtsProbeMitBonus(
    basis,
    frisch.mirakelbonus,
    ansageFolgemalus: frisch.ansageFolgemalus,
  );
  final ctl = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!ctl.reservieren(id)) return;
  var gebucht = false;
  try {
    await bestand.gefechtsProbe(
      context: context,
      ref: ref,
      heroId: heroId,
      request: request,
      onResolved: (r) {
        if (gebucht) return;
        gebucht = true;
        if (p == null) {
          ctl.abbrechen(id);
        } else if (!ctl.abschliessen(id, w, p)) {
          return;
        }
        var neu = ref.read(gefechtMitInitiativeProvider(heroId))!;
        if (gefechtsBonusPasst(basis, frisch.mirakelbonus)) {
          neu = neu.copyWith(ohneMirakelbonus: true);
        }
        if (zeit == GefechtsZeitbedarf.laengerfristig) {
          final dauer = gefechtsTalenteinsatzDauer(geplant, r);
          if (dauer > 1) {
            neu = neu.copyWith(
              handlung: Gefechtshandlung(
                titel:
                    'Talenteinsatz ${kandidat.name} · '
                    '${r.success ? 'gelungen' : 'misslungen'}',
                verbleibend: dauer - 1,
              ),
            );
          }
        }
        ctl.setzen(neu);
      },
    );
  } finally {
    ctl.abbrechen(id);
  }
}

// Durchsuchbare Auswahl; Treffer in alphabetischer Reihenfolge.
class _Probenwahl extends StatefulWidget {
  const _Probenwahl({required this.kandidaten});
  final List<GefechtProbenkandidat> kandidaten;
  @override
  State<_Probenwahl> createState() => _ProbenwahlState();
}

class _ProbenwahlState extends State<_Probenwahl> {
  String _suche = '';
  @override
  Widget build(BuildContext context) {
    final suche = _suche.trim().toLowerCase();
    // Ausweichproben (Meisterentscheid) erscheinen nur bei einer Suche.
    final treffer = widget.kandidaten
        .where(
          (k) => suche.isEmpty
              ? !k.ausweichen
              : k.name.toLowerCase().contains(suche),
        )
        .take(60)
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const ValueKey('gefecht-probe-suche'),
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Talent oder Eigenschaft suchen',
                ),
                onChanged: (v) => setState(() => _suche = v),
              ),
            ),
            Flexible(
              child: treffer.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Keine passende Probe.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final k in treffer)
                          ListTile(
                            title: Text(k.name),
                            subtitle: Text(k.detail),
                            onTap: () => Navigator.pop(context, k),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Zeitbedarf und Erschwernis vor dem Wurf; Budget aus derselben Prüfung.
class _Zeitbedarf extends StatefulWidget {
  const _Zeitbedarf({
    required this.kandidat,
    required this.zustand,
    required this.werte,
  });
  final GefechtProbenkandidat kandidat;
  final Gefechtszustand zustand;
  final Gefechtswerte werte;
  @override
  State<_Zeitbedarf> createState() => _ZeitbedarfState();
}

class _ZeitbedarfState extends State<_Zeitbedarf> {
  late GefechtsZeitbedarf _zeit = gefechtsZeitbedarfVorgabe(
    widget.kandidat.request.type,
  );
  final _erschwernis = TextEditingController(text: '0');
  final _geplant = TextEditingController(text: '3');

  @override
  void dispose() {
    _erschwernis.dispose();
    _geplant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pruefeGefechtsZeitbedarf(widget.zustand, widget.werte, _zeit);
    final erschwernis = int.tryParse(_erschwernis.text.trim());
    final geplant = int.tryParse(_geplant.text.trim());
    final lang = _zeit == GefechtsZeitbedarf.laengerfristig;
    final gesperrt = p?.status == Gefechtsfreigabe.gesperrt;
    final gueltig =
        !gesperrt &&
        erschwernis != null &&
        (!lang || geplant != null && geplant >= 1);
    final folgemalus = widget.zustand.ansageFolgemalus;
    return AlertDialog(
      title: Text(widget.kandidat.name),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.kandidat.detail),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final z in GefechtsZeitbedarf.values)
                    ChoiceChip(
                      key: ValueKey('gefecht-zeitbedarf-${z.name}'),
                      label: Text(gefechtsZeitbedarfName(z)),
                      selected: _zeit == z,
                      onSelected: (_) => setState(() => _zeit = z),
                    ),
                ],
              ),
              if (lang)
                GefechtZahlfeld(
                  controller: _geplant,
                  label: 'Geplante Aktionen',
                  minimum: 1,
                  hilfe:
                      'Übrig behaltene TaP* verkürzen die Dauer (WdS S. 55).',
                  onChanged: () => setState(() {}),
                ),
              GefechtZahlfeld(
                controller: _erschwernis,
                label: 'Erschwernis',
                minimum: null,
                hilfe: 'Kampfgetümmel erschwert die meisten Proben.',
                onChanged: () => setState(() {}),
              ),
              if (folgemalus > 0)
                Text(
                  'Ansagefolgemalus +$folgemalus wird zusätzlich angewandt.',
                ),
              if (gesperrt) Text(p!.gruende.join('\n')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey('gefecht-talentprobe-starten'),
          autofocus: true,
          onPressed: gueltig
              ? () => Navigator.pop(context, (_zeit, erschwernis, geplant ?? 1))
              : null,
          child: const Text('Würfeln'),
        ),
      ],
    );
  }
}
