import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_inventar_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_verbrauch_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Zeigt das Inventar und benutzt auf Wunsch einen Gegenstand.
///
/// „Gegenstand benutzen“ ist eine längerfristige Handlung (WdS S. 55):
/// Gürteltasche 10, Rucksack 20 Aktionen, eine gelungene FF-Probe halbiert
/// die Zeit; ein getragenes Artefakt kostet eine freie Aktion. Die erste
/// Aktion wird sofort bezahlt, der Rest über „Fortsetzen“. Erst beim
/// Abschluss fragt die App, ob ein Stück abgebucht werden soll.
Future<void> zeigeGefechtsInventar({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (snapshot == null) return;
  final posten = await showDialog<GefechtsInventarposten>(
    context: context,
    builder: (_) => _Inventarliste(posten: gefechtsInventar(snapshot.hero)),
  );
  if (posten == null || !context.mounted) return;
  final wahl = await showDialog<(GefechtsAufbewahrung, bool)>(
    context: context,
    builder: (_) => _Benutzung(posten: posten),
  );
  if (wahl == null || !context.mounted) return;
  final (ort, ffProbe) = wahl;
  final katalog = ref.read(rulesCatalogProvider).asData?.value;
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  if (s == null) return;
  final w = gefechtswerteFuer(snapshot, katalog: katalog);
  // Freie Aktion oder erste reguläre Aktion; die FF-Probe ändert nur die
  // Restdauer, nie diese Art. Gesperrt wird deshalb vor dem Würfeln.
  Gefechtspruefung pruefung(Gefechtszustand z, int dauer) => dauer == 0
      ? pruefeGefechtsaktion(z, w, Gefechtsaktion.freieAktion)
      : pruefeManuelleGefechtsaktion(z, w, kosten: 1);
  final vorher = pruefung(s, gefechtsBenutzungsdauer(ort));
  if (vorher.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(vorher.gruende.join(' '));
  }
  var ffGelungen = false;
  if (ffProbe) {
    final ff = readAttributeValue(
      snapshot.probenEigenschaften,
      AttributeCode.ff,
    );
    final r = await bestand.gefechtsProbe(
      context: context,
      ref: ref,
      heroId: heroId,
      request: gefechtsProbeMitBonus(
        buildAttributeProbeRequest(label: 'FF', effectiveValue: ff),
        null,
        ansageFolgemalus: s.ansageFolgemalus,
      ),
    );
    if (r == null || !context.mounted) return;
    ffGelungen = r.success;
  }
  final dauer = gefechtsBenutzungsdauer(ort, ffGelungen: ffGelungen);
  final frisch = ref.read(gefechtMitInitiativeProvider(heroId));
  if (frisch == null) return;
  final p = pruefung(frisch, dauer);
  if (p.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(p.gruende.join(' '));
  }
  final ctl = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!ctl.reservieren(id)) return;
  try {
    if (!ctl.abschliessen(id, w, p)) return;
  } finally {
    ctl.abbrechen(id);
  }
  if (dauer > 1) {
    ctl.setzen(
      ref
          .read(gefechtMitInitiativeProvider(heroId))!
          .copyWith(
            handlung: Gefechtshandlung(
              titel: 'Gegenstand benutzen · ${posten.eintrag.gegenstand}',
              verbleibend: dauer - 1,
              gegenstand: posten.eintrag,
            ),
          ),
    );
    return;
  }
  if (!context.mounted) return;
  await schliesseGefechtsGegenstandAb(
    context: context,
    ref: ref,
    heroId: heroId,
    eintrag: posten.eintrag,
  );
}

/// Fragt nach abgeschlossener Benutzung, ob ein Stück abgebucht wird.
///
/// Schreibt frisch über `HeroActions.updateHero` und trifft den Eintrag über
/// seinen Inhalt; bei offener Steigerungsrunde wird nichts geschrieben.
/// Ohne eindeutige Menge gibt es keine Abbuchung.
Future<void> schliesseGefechtsGegenstandAb({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
}) async {
  if (!inventarAbbuchbar(eintrag)) return;
  final ja = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(eintrag.gegenstand),
      content: Text(
        'Benutzung abgeschlossen. Ein Stück abbuchen? '
        'Bestand ${inventarMenge(eintrag)} → ${inventarMenge(eintrag)! - 1}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Nicht abbuchen'),
        ),
        FilledButton(
          key: const ValueKey('gefecht-gegenstand-abbuchen'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Abbuchen'),
        ),
      ],
    ),
  );
  if (ja != true) return;
  if (ref.read(advancementSessionProvider(heroId)) != null) {
    throw StateError(
      'Während einer offenen Steigerungsrunde wird das Inventar nicht geändert.',
    );
  }
  await ref
      .read(heroActionsProvider)
      .updateHero(
        heroId,
        (held) => mitVerbrauchtemInventarEintrag(held, eintrag),
      );
}

// Gruppierte, lesbare Inventarliste; nur Benutzbares hat einen Knopf.
class _Inventarliste extends StatelessWidget {
  const _Inventarliste({required this.posten});
  final List<GefechtsInventarposten> posten;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    final gruppen = <GefechtsInventargruppe, List<GefechtsInventarposten>>{};
    // Gleichnamige Gegenstände sind häufig; der Schlüssel folgt der Position.
    final nummer = <GefechtsInventarposten, int>{};
    for (final p in posten) {
      nummer[p] = nummer.length;
      (gruppen[p.gruppe] ??= []).add(p);
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Inventar', style: texte.titleLarge),
            ),
            Flexible(
              child: posten.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Keine Gegenstände erfasst.'),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final g in gruppen.entries) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: Text(
                                gefechtsInventargruppenName(g.key),
                                style: texte.titleSmall,
                              ),
                            ),
                            for (final p in g.value)
                              _zeile(context, p, nummer[p]!),
                          ],
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
                  child: const Text('Schließen'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Name, Menge und Ort; Begleitergepäck nennt den Träger.
  Widget _zeile(BuildContext context, GefechtsInventarposten p, int nummer) {
    final e = p.eintrag;
    final details = [
      if (p.menge != null)
        '${p.menge}×'
      else if (e.anzahl.trim().isNotEmpty)
        e.anzahl,
      if (p.traeger != null) p.traeger!,
      if (e.woGetragen.trim().isNotEmpty) e.woGetragen,
      if (e.isMagisch) 'magisch',
    ].join(' · ');
    return ListTile(
      key: ValueKey('gefecht-inventar-${e.instanzId ?? nummer}'),
      title: Text(e.gegenstand.isEmpty ? 'Unbenannt' : e.gegenstand),
      subtitle: details.isEmpty ? null : Text(details),
      trailing: p.benutzbar
          ? TextButton(
              onPressed: () => Navigator.pop(context, p),
              child: const Text('Benutzen'),
            )
          : null,
    );
  }
}

// Aufbewahrung und optionale FF-Probe vor der Benutzung.
class _Benutzung extends StatefulWidget {
  const _Benutzung({required this.posten});
  final GefechtsInventarposten posten;
  @override
  State<_Benutzung> createState() => _BenutzungState();
}

class _BenutzungState extends State<_Benutzung> {
  late GefechtsAufbewahrung _ort = gefechtsAufbewahrungVorgabe(
    widget.posten.eintrag,
  );
  bool _ff = false;

  @override
  Widget build(BuildContext context) {
    final halbierbar =
        _ort == GefechtsAufbewahrung.guerteltasche ||
        _ort == GefechtsAufbewahrung.rucksack;
    final dauer = gefechtsBenutzungsdauer(_ort);
    final abbuchbar = inventarAbbuchbar(widget.posten.eintrag);
    return AlertDialog(
      title: Text('${widget.posten.eintrag.gegenstand} benutzen'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final o in GefechtsAufbewahrung.values)
                    ChoiceChip(
                      key: ValueKey('gefecht-aufbewahrung-${o.name}'),
                      label: Text(gefechtsAufbewahrungName(o)),
                      selected: _ort == o,
                      onSelected: (_) => setState(() => _ort = o),
                    ),
                ],
              ),
              if (halbierbar)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ff,
                  title: const Text('FF-Probe würfeln (halbiert die Zeit)'),
                  onChanged: (v) => setState(() => _ff = v ?? false),
                ),
              const SizedBox(height: 8),
              Text(
                dauer == 0
                    ? 'Dauer: freie Aktion.'
                    : 'Dauer: $dauer Aktion${dauer == 1 ? '' : 'en'}'
                          '${halbierbar && _ff ? ' (bei gelungener FF-Probe halbiert)' : ''}; '
                          'die erste wird jetzt bezahlt.',
              ),
              Text(
                abbuchbar
                    ? 'Beim Abschluss wird gefragt, ob ein Stück abgebucht wird.'
                    : 'Menge nicht eindeutig: keine Abbuchung.',
              ),
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
          key: const ValueKey('gefecht-gegenstand-starten'),
          autofocus: true,
          onPressed: () => Navigator.pop(context, (_ort, halbierbar && _ff)),
          child: const Text('Benutzen'),
        ),
      ],
    );
  }
}
