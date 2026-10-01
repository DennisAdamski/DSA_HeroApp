import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';

/// Tatsächliche Katalogzauber und karmale Einträge mit klarer manueller Grenze.
class GefechtMagie extends StatelessWidget {
  /// Führt die Probe über den gemeinsamen, aktionsgebundenen Auftrag aus.
  const GefechtMagie({
    super.key,
    required this.werte,
    required this.katalog,
    required this.gesperrt,
    required this.onAuftrag,
  });
  final HeroComputedSnapshot werte;
  final RulesCatalog? katalog;
  final bool gesperrt;
  final void Function(
    String titel,
    ResolvedProbeRequest? probe,
    String beschreibung,
  )
  onAuftrag;
  @override
  Widget build(BuildContext context) {
    if (!werte.resourceActivation.magic.isEnabled &&
        !werte.resourceActivation.divine.isEnabled) {
      return const SizedBox.shrink();
    }
    return KartoAbschnitt(
      titel: 'Magie und Karma',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Prüfen: Zeitpunkt, Dauer, Ressourcen und Wirkungen manuell bestätigen.',
          ),
          for (final zauber in katalog?.spells ?? <SpellDef>[])
            if (werte.hero.spells.containsKey(zauber.id))
              TextButton(
                onPressed: gesperrt
                    ? null
                    : () => onAuftrag(
                        zauber.name,
                        gefechtsZauberprobe(werte, zauber),
                        '${zauber.wirkung}\n'
                        'Dauer: ${zauber.castingTime}\nKosten: ${zauber.aspCost}\n'
                        'Reichweite: ${zauber.range}\nZiel: ${zauber.targetObject}',
                      ),
                child: Text('${zauber.name} · prüfen'),
              ),
          if (werte.resourceActivation.divine.isEnabled) ...[
            for (final talent in katalog?.talents ?? <TalentDef>[])
              if (talent.name.toLowerCase().contains('liturgiekenntnis') &&
                  gefechtsLiturgieprobe(werte, talent) != null)
                TextButton(
                  onPressed: gesperrt
                      ? null
                      : () => onAuftrag(
                          talent.name,
                          gefechtsLiturgieprobe(werte, talent),
                          'Tatsächliche Liturgiekenntnis; Liturgie, Grad, Modifikatoren, Zeitpunkt, '
                          'Dauer und KaP-Kosten ausdrücklich bestätigen.',
                        ),
                  child: Text('${talent.name} · prüfen'),
                ),
            for (final sf
                in katalog == null
                    ? <SpecialAbilityDef>[]
                    : gefechtKarmaleFertigkeiten(werte, katalog!))
              TextButton(
                onPressed: gesperrt
                    ? null
                    : () => onAuftrag(
                        sf.name,
                        null,
                        '${sf.beschreibung}\n${sf.voraussetzungen}',
                      ),
                child: Text('${sf.name} · manuell prüfen'),
              ),
            TextButton(
              onPressed: gesperrt
                  ? null
                  : () => onAuftrag(
                      'Mirakel / Liturgie',
                      null,
                      'Erlernte Liturgie, Grad, LkW, Probe, Zeitpunkt, Dauer und KaP-Kosten '
                          'anhand des tatsächlichen Helden und Regeltexts prüfen. Keine automatische Bonusformel.',
                    ),
              child: const Text('Karmale Handlung manuell führen'),
            ),
          ],
        ],
      ),
    );
  }
}
