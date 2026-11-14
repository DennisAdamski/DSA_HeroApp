import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifikator_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_value_row.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_section_card.dart';

/// Schlüssel des Hinweises, dass die Statuswerte während einer Planung ruhen.
const ValueKey<String> kStatuswerteGesperrtSchluessel = ValueKey<String>(
  'inspector-statuswerte-gesperrt',
);

/// Ein Statuswert mit seinen Schreibwegen; `null` sperrt die Aktion.
typedef _Statuswert = ({
  String label,
  int modifier,
  int result,
  bool nurLesen,
  VoidCallback? minus,
  VoidCallback? plus,
  VoidCallback? zuruecksetzen,
});

/// Die acht Statuswerte in fester Reihenfolge, für Zeilen, Raster und Blatt.
///
/// Jeder Knopf meldet nur einen Schritt; angewendet wird er auf den
/// gespeicherten Helden (ARCH-05). Beobachtet Planung und BE-Überschreibung
/// selbst, damit alle Formen dieselben Werte und Sperren zeigen.
List<_Statuswert> _statuswerte({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroSheet hero,
  required DerivedStats derived,
  required CombatPreviewStats combat,
}) {
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

  // Wert eines Dauermodifikators; gesperrt ohne Bedienung.
  _Statuswert wert(String label, Dauermodifikator art, int ergebnis) {
    final modifier = dauermodifikatorWert(mods, art);
    return (
      label: label,
      modifier: modifier,
      result: ergebnis,
      nurLesen: false,
      minus: gesperrt
          ? null
          : () => aendere(art, label, const RessourcenAenderung.schritt(-1)),
      plus: gesperrt
          ? null
          : () => aendere(art, label, const RessourcenAenderung.schritt(1)),
      zuruecksetzen: gesperrt || modifier == 0
          ? null
          : () => aendere(art, label, const RessourcenAenderung.setzen(0)),
    );
  }

  // BE liegt nur im Arbeitsspeicher und bleibt deshalb auch während einer
  // Planung bedienbar.
  void setzeBe(int naechste) {
    ref
        .read(talentBeOverrideProvider(heroId).notifier)
        .set(naechste == combat.beKampf ? null : naechste);
  }

  return <_Statuswert>[
    wert('Ini', Dauermodifikator.iniBase, combat.initiative),
    wert('GS', Dauermodifikator.gs, derived.gs),
    wert('AW', Dauermodifikator.ausweichen, combat.ausweichen),
    wert('PA', Dauermodifikator.pa, combat.pa),
    wert('AT', Dauermodifikator.at, combat.at),
    (
      label: 'MR',
      modifier: 0,
      result: derived.mr,
      nurLesen: true,
      minus: null,
      plus: null,
      zuruecksetzen: null,
    ),
    wert('RS', Dauermodifikator.rs, combat.rsTotal),
    (
      label: 'BE',
      modifier: manualBeModifier,
      result: activeTalentBe,
      nurLesen: false,
      minus: () => setzeBe(activeTalentBe > 0 ? activeTalentBe - 1 : 0),
      plus: () => setzeBe(activeTalentBe + 1),
      zuruecksetzen: talentBeOverride != null
          ? () => ref.read(talentBeOverrideProvider(heroId).notifier).clear()
          : null,
    ),
  ];
}

// Key der Zeile; BE trägt seit jeher einen kleingeschriebenen Namen.
ValueKey<String> _zeilenKey(String label) => ValueKey<String>(
  label == 'BE' ? 'workspace-status-row-be' : 'workspace-status-row-$label',
);

// Bedienbare Zeile oder, bei MR, die Nur-Lese-Zeile.
Widget _zeile(_Statuswert wert) {
  if (wert.nurLesen) {
    return InspectorReadOnlyValueRow(
      key: _zeilenKey(wert.label),
      label: wert.label,
      value: wert.result,
    );
  }
  return InspectorValueRow(
    key: _zeilenKey(wert.label),
    label: wert.label,
    modifier: wert.modifier,
    result: wert.result,
    onDecrement: wert.minus,
    onIncrement: wert.plus,
    onReset: wert.zuruecksetzen,
  );
}

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
///
/// Mit [raster] stehen die Werte als flaches Raster kleiner Karten (vier
/// Spalten, bei wenig Platz zwei) statt als acht Zeilen; ein Tipp öffnet ein
/// kleines Blatt mit derselben Zeile und denselben Schreibwegen. So bleibt die
/// schmale Zustandskachel der Spielansicht flach.
class InspectorStatuswerteBlock extends ConsumerWidget {
  const InspectorStatuswerteBlock({
    super.key,
    required this.heroId,
    required this.hero,
    required this.derived,
    required this.combat,
    this.eingebettet = false,
    this.mitTrenner = true,
    this.raster = false,
  });

  final String heroId;
  final HeroSheet hero;
  final DerivedStats derived;
  final CombatPreviewStats combat;

  /// Verzichtet auf die eigene Karte samt Untertitel.
  final bool eingebettet;

  /// Ob im eingebetteten Zustand eine Trennlinie über der Überschrift steht.
  /// Steht der Block neben anderen Abschnitten statt darunter, entfällt sie.
  final bool mitTrenner;

  /// Werte als Raster kleiner Karten statt als Zeilen.
  final bool raster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gesperrt = ref.watch(advancementSessionProvider(heroId)) != null;
    final werte = _statuswerte(
      context: context,
      ref: ref,
      heroId: heroId,
      hero: hero,
      derived: derived,
      combat: combat,
    );

    final zeilen = Column(
      crossAxisAlignment: raster
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
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
        if (raster)
          _StatuswertRaster(heroId: heroId, werte: werte)
        else
          for (var i = 0; i < werte.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _zeile(werte[i]),
          ],
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
        if (mitTrenner) ...[
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
        ],
        Text('Statuswerte', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        zeilen,
      ],
    );
  }
}

/// Raster der Statuswerte: vier Spalten, bei wenig Platz zwei.
class _StatuswertRaster extends StatelessWidget {
  const _StatuswertRaster({required this.heroId, required this.werte});

  static const double _abstand = 6;
  static const double _minBreite = 56;
  static const double _hoehe = 48;

  final String heroId;
  final List<_Statuswert> werte;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final breite = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 4 * (_minBreite + _abstand);
        final spalten = breite + _abstand >= 4 * (_minBreite + _abstand)
            ? 4
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: werte.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: spalten,
            mainAxisSpacing: _abstand,
            crossAxisSpacing: _abstand,
            mainAxisExtent: _hoehe,
          ),
          itemBuilder: (context, index) {
            final wert = werte[index];
            final bedienbar = wert.minus != null || wert.plus != null;
            return _StatuswertKarte(
              wert: wert,
              onTap: bedienbar
                  ? () => _zeigeStatuswertBlatt(
                      context: context,
                      heroId: heroId,
                      label: wert.label,
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Kleine Karte eines Statuswerts: Kürzel, Ergebnis, Modifikator als Marke.
class _StatuswertKarte extends StatelessWidget {
  const _StatuswertKarte({required this.wert, required this.onTap});

  final _Statuswert wert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codex = context.codexTheme;
    final modifier = wert.modifier;
    final modFarbe = modifier > 0
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final karte = Material(
      color: codex.parchment,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey<String>('workspace-status-kachel-${wert.label}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: codex.brassMuted, width: 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  wert.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: codex.brass,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${wert.result}',
                      key: ValueKey<String>(
                        'workspace-status-kachel-${wert.label}-wert',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (modifier != 0) ...[
                      const SizedBox(width: 3),
                      Text(
                        mitVorzeichen(modifier),
                        key: ValueKey<String>(
                          'workspace-status-kachel-${wert.label}-mod',
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: modFarbe,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Tooltip(
      message: wert.nurLesen
          ? '${wert.label} (nur Anzeige)'
          : onTap == null
          ? '${wert.label} (gesperrt)'
          : '${wert.label} anpassen',
      child: karte,
    );
  }
}

// Öffnet das Blatt eines Statuswerts; es bleibt für mehrere Schritte offen.
Future<void> _zeigeStatuswertBlatt({
  required BuildContext context,
  required String heroId,
  required String label,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => ZustandFehlerBereich(
      child: _StatuswertBlatt(heroId: heroId, label: label),
    ),
  );
}

/// Blatt mit der einen Zeile eines Statuswerts.
///
/// Liest die Werte selbst neu, damit die Zeile jedem Schritt folgt; die
/// Schritte schreiben wie die Zeilen frisch auf den gespeicherten Helden.
class _StatuswertBlatt extends ConsumerWidget {
  const _StatuswertBlatt({required this.heroId, required this.label});

  final String heroId;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(heroComputedProvider(heroId)).valueOrNull;
    _Statuswert? wert;
    if (snapshot != null) {
      for (final kandidat in _statuswerte(
        context: context,
        ref: ref,
        heroId: heroId,
        hero: snapshot.hero,
        derived: snapshot.derivedStats,
        combat: snapshot.combatPreviewStats,
      )) {
        if (kandidat.label == label) wert = kandidat;
      }
    }
    return Dialog(
      key: ValueKey<String>('workspace-status-blatt-$label'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kDialogWidthSmall),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$label anpassen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (wert == null)
                const Center(child: CircularProgressIndicator())
              else
                _zeile(wert),
              const ZustandFehlerAnzeige(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey<String>(
                    'workspace-status-blatt-schliessen',
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
