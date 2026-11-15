/// Bestandsbausteine des Spielbereichs, getrennt vom übrigen Adapter.
///
/// Die Spec sieht diese Aufteilung der Brückenschicht ausdrücklich vor: der
/// Spielbereich bringt mehrere Bausteine mit, die sonst
/// `karto_bestands_adapter_impl.dart` aufblähen würden.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_belastung_section.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_statuswerte_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_vital_block.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector_wunden_card.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';

/// Öffnet die vorhandene Ressourcenbedienung als aufgelegtes Blatt.
///
/// Bewusst der `InspectorVitalBlock` und nicht `showResourceStepperDialog`:
/// nur er kennt ±5/±1, Zurücksetzen auf das Maximum, Überheilung und die
/// Untergrenze [kVitalFloor]. Der Stepper klemmt hart auf `0..max` und könnte
/// negative Lebenspunkte gar nicht erzeugen.
Future<void> zeigeRessourcenBlatt({
  required BuildContext context,
  required String heroId,
  required KartoRessource ressource,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => ZustandFehlerBereich(
      child: _RessourcenBlatt(heroId: heroId, ressource: ressource),
    ),
  );
}

String _kurzName(KartoRessource ressource) => switch (ressource) {
  KartoRessource.lebensenergie => 'LeP',
  KartoRessource.ausdauer => 'AuP',
  KartoRessource.astralenergie => 'AsP',
  KartoRessource.karma => 'KaP',
};

int _aktuellVon(HeroState state, KartoRessource ressource) =>
    switch (ressource) {
      KartoRessource.lebensenergie => state.currentLep,
      KartoRessource.ausdauer => state.currentAu,
      KartoRessource.astralenergie => state.currentAsp,
      KartoRessource.karma => state.currentKap,
    };

HeroState _mitWertVon(HeroState state, KartoRessource ressource, int wert) =>
    switch (ressource) {
      KartoRessource.lebensenergie => state.copyWith(currentLep: wert),
      KartoRessource.ausdauer => state.copyWith(currentAu: wert),
      KartoRessource.astralenergie => state.copyWith(currentAsp: wert),
      KartoRessource.karma => state.copyWith(currentKap: wert),
    };

/// Wendet [aenderung] auf den **frisch geladenen** Wert der [ressource] an.
///
/// Gemeinsamer Schreibweg für das Ressourcenblatt und die Knöpfe der
/// Spielansicht: Der Zustand wird neu gelesen, nur diese eine Ressource
/// ersetzt und nie auf einem beim Rendern erfassten Wert gerechnet. Dadurch
/// zählt auch jeder schnelle Klick.
Future<void> schreibeRessourcenAenderung({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoRessource ressource,
  required RessourcenAenderung aenderung,
}) {
  return aendereZustandMitMeldung(
    context: context,
    ref: ref,
    heroId: heroId,
    was: _kurzName(ressource),
    aenderung: (aktuell) => _mitWertVon(
      aktuell,
      ressource,
      aenderung.wendeAn(_aktuellVon(aktuell, ressource)),
    ),
  );
}

/// Verschiebt die [ressource] um [schritt], nie unter [kVitalFloor].
///
/// Wie im Blatt gibt es keine Obergrenze: Überheilung bleibt möglich. Die
/// Untergrenze bleibt hier und nicht in der Oberfläche, damit UI2 keine Regel
/// kennt.
Future<void> schreibeRessourcenSchritt({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoRessource ressource,
  required int schritt,
}) {
  return schreibeRessourcenAenderung(
    context: context,
    ref: ref,
    heroId: heroId,
    ressource: ressource,
    aenderung: RessourcenAenderung.schritt(schritt, untergrenze: kVitalFloor),
  );
}

// Liest den gemeinsamen Snapshot und speichert über den vorhandenen Schreibweg.
class _RessourcenBlatt extends ConsumerWidget {
  const _RessourcenBlatt({required this.heroId, required this.ressource});

  final String heroId;
  final KartoRessource ressource;

  String get _kurz => _kurzName(ressource);

  String get _lang => switch (ressource) {
    KartoRessource.lebensenergie => 'Lebenspunkte',
    KartoRessource.ausdauer => 'Ausdauer',
    KartoRessource.astralenergie => 'Astralpunkte',
    KartoRessource.karma => 'Karmapunkte',
  };

  VitalKind get _art => switch (ressource) {
    KartoRessource.lebensenergie => VitalKind.lep,
    KartoRessource.ausdauer => VitalKind.aup,
    KartoRessource.astralenergie => VitalKind.asp,
    KartoRessource.karma => VitalKind.kap,
  };

  int _aktuell(HeroState state) => _aktuellVon(state, ressource);

  // Gemeinsamer Schreibweg: siehe [schreibeRessourcenAenderung].
  Future<void> _speichere(
    BuildContext context,
    WidgetRef ref,
    RessourcenAenderung aenderung,
  ) {
    return schreibeRessourcenAenderung(
      context: context,
      ref: ref,
      heroId: heroId,
      ressource: ressource,
      aenderung: aenderung,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final werte = ref.watch(heroComputedProvider(heroId)).valueOrNull;
    final state = werte?.state;
    final derived = werte?.derivedStats;
    final maximum = switch (ressource) {
      KartoRessource.lebensenergie => derived?.maxLep ?? 0,
      KartoRessource.ausdauer => derived?.maxAu ?? 0,
      KartoRessource.astralenergie => derived?.maxAsp ?? 0,
      KartoRessource.karma => derived?.maxKap ?? 0,
    };

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kDialogWidthSmall),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$_lang anpassen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (state == null)
                const Center(child: CircularProgressIndicator())
              else
                InspectorVitalBlock(
                  label: _kurz,
                  subtitle: _lang,
                  current: _aktuell(state),
                  max: maximum,
                  kind: _art,
                  onChanged: (naechster) => _speichere(context, ref, naechster),
                ),
              const ZustandFehlerAnzeige(),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const ValueKey<String>('karto-ressource-schliessen'),
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

/// Baut Belastung, Wunden und Statuswerte als einen Block.
///
/// Fasst genau die Teile des Vitals-Tabs zusammen, die nicht Ressourcen sind.
/// Die Bausteine bleiben die vorhandenen: Wunden bringen ihren eigenen
/// Detaildialog mit, Belastung ihren eigenen Schreibweg. Ohne [mitBelastung]
/// entfällt die Belastung; die Spielansicht führt Erschöpfung und
/// Überanstrengung in „Dabei“.
///
/// In einer **weiten** Kachel (SPIEL-07, [KartoKachelGroesse.weit]) mit
/// mindestens [zweiSpaltenAb] Breite stehen zwei Spalten nebeneinander: links
/// Belastung über Wunden, beide von Anfang an aufgeklappt, rechts die
/// Statuswerte als Zeilen. Sonst steht alles in einer Spalte mit eingeklappten
/// Abschnitten, die Statuswerte als flaches Wertraster
/// ([InspectorStatuswerteBlock.raster]). Die Schreibwege sind in beiden Formen
/// dieselben.
class KartoZustandsblock extends StatelessWidget {
  /// Erstellt den Zustandsblock aus dem bereits gelesenen Snapshot.
  const KartoZustandsblock({
    super.key,
    required this.heroId,
    required this.werte,
    this.mitBelastung = true,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Gemeinsamer Snapshot des Spielbereichs.
  final HeroComputedSnapshot werte;

  /// Ob Erschöpfung und Überanstrengung im Block stehen.
  final bool mitBelastung;

  /// Breite, ab der zwei Spalten à mindestens 300 dp nebeneinander passen.
  ///
  /// Eine Wertzeile braucht rund 300 dp: ihre Bedienelemente sind etwa 200 dp
  /// breit, dazu kommt der Name, etwa „Überanstrengung“.
  static const double zweiSpaltenAb = 624;

  static const double _spaltenabstand = 24;

  @override
  Widget build(BuildContext context) {
    final weit = KartoKachelSteuerung.istWeit(context);
    // Belastung und Wunden melden Speicherfehler hier, nicht als Snackbar.
    return ZustandFehlerBereich(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final zweispaltig = weit && constraints.maxWidth >= zweiSpaltenAb;
          Widget belastung() => InspectorBelastungSection(
            heroId: heroId,
            heroState: werte.state,
            anfangsAufgeklappt: zweispaltig,
          );
          Widget wunden() => InspectorWundenSection(
            heroId: heroId,
            heroState: werte.state,
            wundEffekte: werte.wundEffekte,
            wundschwelle: werte.wundschwelle,
            anfangsAufgeklappt: zweispaltig,
          );
          Widget statuswerte() => InspectorStatuswerteBlock(
            heroId: heroId,
            hero: werte.hero,
            derived: werte.derivedStats,
            combat: werte.combatPreviewStats,
            // Der Zustand ist bereits ein Abschnitt; eine eigene Karte darin
            // waere eine Karte in der Karte.
            eingebettet: true,
            // Neben den anderen Abschnitten statt darunter braucht er keine
            // Trennlinie.
            mitTrenner: !zweispaltig,
            // In einer Spalte acht Zeilen untereinander wären zu tief.
            raster: !zweispaltig,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ZustandFehlerAnzeige(),
              if (zweispaltig)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        key: const ValueKey<String>('karto-zustand-links'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (mitBelastung) ...[
                            belastung(),
                            const SizedBox(height: 14),
                          ],
                          wunden(),
                        ],
                      ),
                    ),
                    const SizedBox(width: _spaltenabstand),
                    Expanded(
                      child: KeyedSubtree(
                        key: const ValueKey<String>('karto-zustand-rechts'),
                        child: statuswerte(),
                      ),
                    ),
                  ],
                )
              else ...[
                if (mitBelastung) ...[belastung(), const SizedBox(height: 14)],
                wunden(),
                const SizedBox(height: 14),
                statuswerte(),
              ],
            ],
          );
        },
      ),
    );
  }
}
