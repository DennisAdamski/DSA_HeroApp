import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Zeigt kompakte Ressourcen und vorhandene Wunden vor den Zustandskontrollen.
class GefechtVitalwerte extends StatelessWidget {
  /// Die Heldenidentität erhält die Expansion unabhängig von Ressourcenständen.
  const GefechtVitalwerte({
    super.key,
    required this.heroId,
    required this.werte,
    required this.child,
  });

  /// Stabile Identität für den lokalen Aufklappzustand der Karte.
  final String heroId;

  /// Liefert gespeicherte Ressourcen, tatsächliche Wunden und berechnete Maxima.
  final HeroComputedSnapshot werte;

  /// Bestehende Ressourcen-, Schadens-, Wunden- und Effektbedienung.
  final Widget child;

  /// Verbindet die knappe Übersicht mit den vorhandenen Fachkontrollen.
  @override
  Widget build(BuildContext context) {
    final state = werte.state;
    final maxima = werte.derivedStats;
    final wunden = state.wpiZustand.wundenProZone;
    return Card(
      child: ExpansionTile(
        // Eine manuelle Entscheidung bleibt auch nach Heilung oder Schaden gültig.
        key: PageStorageKey<String>('gefecht-vitalwerte-$heroId'),
        title: const Text('Vitalwerte'),
        subtitle: Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            Text('LeP ${state.currentLep} / ${maxima.maxLep}'),
            if (werte.resourceActivation.magic.isEnabled)
              Text('AsP ${state.currentAsp} / ${maxima.maxAsp}'),
            for (final zone in WundZone.values)
              if ((wunden[zone] ?? 0) > 0)
                Text(
                  '${wundZoneLabel[zone]}: ${wunden[zone]} '
                  '${wunden[zone] == 1 ? 'Wunde' : 'Wunden'}',
                ),
          ],
        ),
        initiallyExpanded: gefechtDurchhaltenOeffnen(
          wundAbzuege: werte.wundEffekte.hatAbzuege,
          lep: state.currentLep,
          maxLep: maxima.maxLep,
        ),
        childrenPadding: const EdgeInsets.all(12),
        children: [child],
      ),
    );
  }
}
