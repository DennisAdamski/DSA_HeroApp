import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifikator_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_value_row.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Schlüssel des Hinweises, dass die Statuswerte während einer Planung ruhen.
const ValueKey<String> kStatuswerteGesperrtSchluessel = ValueKey<String>(
  'inspector-statuswerte-gesperrt',
);

/// Kompakte Statuswerte-Karte fuer den Vitals-Tab.
///
/// Bedienbar: Ini, GS, AW, PA, AT, RS, BE. MR ist read-only.
///
/// Die Dauermodifikatoren (`persistentMods`) liegen im Heldenbogen. Jeder
/// Knopf meldet nur einen Schritt; angewendet wird er auf den gespeicherten
/// Helden (ARCH-05), damit jeder schnelle Klick zählt und nichts überschrieben
/// wird, was ein anderer Weg inzwischen gespeichert hat. Fehler erscheinen im
/// umgebenden `ZustandFehlerBereich`. Während einer Steigerungsrunde sind
/// diese Zeilen gesperrt, weil jede Bogenänderung deren Übernahme bräche; BE
/// bleibt bedienbar, sie liegt nur im Arbeitsspeicher.
///
/// [eingebettet] laesst die eigene Karte weg, wenn der Block bereits in einer
/// Flaeche steht — in der Spielansicht der neuen Oberflaeche liegt er im
/// Abschnitt "Zustand", und eine Karte darin waere eine Karte in der Karte.
/// Zeilen, Keys und Schreibwege bleiben in beiden Formen dieselben.
class InspectorStatuswerteBlock extends ConsumerWidget {
  const InspectorStatuswerteBlock({
    super.key,
    required this.heroId,
    required this.hero,
    required this.derived,
    required this.combat,
    this.eingebettet = false,
  });

  final String heroId;
  final HeroSheet hero;
  final DerivedStats derived;
  final CombatPreviewStats combat;

  /// Verzichtet auf die eigene Karte samt Untertitel.
  final bool eingebettet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mods = hero.persistentMods;
    final gesperrt = ref.watch(advancementSessionProvider(heroId)) != null;
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final activeTalentBe = talentBeOverride ?? combat.beKampf;
    final manualBeModifier = activeTalentBe - combat.beKampf;

    // Schreibt einen Schritt bzw. das Zurücksetzen eines Dauermodifikators.
    void aendere(
      Dauermodifikator art,
      String label,
      RessourcenAenderung aenderung,
    ) {
      aendereHeldMitMeldung(
        context: context,
        ref: ref,
        heroId: heroId,
        was: '$label-Modifikator',
        aenderung: (held) => mitDauermodifikator(held, art, aenderung),
      );
    }

    // Zeile eines Dauermodifikators; gesperrt ohne Bedienknöpfe.
    Widget zeile(String label, Dauermodifikator art, int ergebnis) {
      final wert = dauermodifikatorWert(mods, art);
      return InspectorValueRow(
        key: ValueKey<String>('workspace-status-row-$label'),
        label: label,
        modifier: wert,
        result: ergebnis,
        onDecrement: gesperrt
            ? null
            : () => aendere(art, label, const RessourcenAenderung.schritt(-1)),
        onIncrement: gesperrt
            ? null
            : () => aendere(art, label, const RessourcenAenderung.schritt(1)),
        onReset: gesperrt || wert == 0
            ? null
            : () => aendere(art, label, const RessourcenAenderung.setzen(0)),
      );
    }

    final zeilen = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gesperrt) ...[
          Text(
            'Während eine Entwicklung geplant wird, sind die Statuswerte '
            'gesperrt.',
            key: kStatuswerteGesperrtSchluessel,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
        ],
        zeile('Ini', Dauermodifikator.iniBase, combat.initiative),
        const SizedBox(height: 6),
        zeile('GS', Dauermodifikator.gs, derived.gs),
        const SizedBox(height: 6),
        zeile('AW', Dauermodifikator.ausweichen, combat.ausweichen),
        const SizedBox(height: 6),
        zeile('PA', Dauermodifikator.pa, combat.pa),
        const SizedBox(height: 6),
        zeile('AT', Dauermodifikator.at, combat.at),
        const SizedBox(height: 6),
        InspectorReadOnlyValueRow(
          key: const ValueKey<String>('workspace-status-row-MR'),
          label: 'MR',
          value: derived.mr,
        ),
        const SizedBox(height: 6),
        zeile('RS', Dauermodifikator.rs, combat.rsTotal),
        const SizedBox(height: 6),
        InspectorValueRow(
          key: const ValueKey<String>('workspace-status-row-be'),
          label: 'BE',
          modifier: manualBeModifier,
          result: activeTalentBe,
          onDecrement: () {
            final nextBe = activeTalentBe > 0 ? activeTalentBe - 1 : 0;
            ref
                .read(talentBeOverrideProvider(heroId).notifier)
                .set(nextBe == combat.beKampf ? null : nextBe);
          },
          onIncrement: () {
            final nextBe = activeTalentBe + 1;
            ref
                .read(talentBeOverrideProvider(heroId).notifier)
                .set(nextBe == combat.beKampf ? null : nextBe);
          },
          onReset: talentBeOverride != null
              ? () {
                  ref.read(talentBeOverrideProvider(heroId).notifier).clear();
                }
              : null,
        ),
      ],
    );
    if (!eingebettet) {
      return CodexSectionCard(
        title: 'Statuswerte',
        subtitle: 'Schnellzugriff',
        child: zeilen,
      );
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 12),
        Text('Statuswerte', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        zeilen,
      ],
    );
  }
}
