/// Würfelhilfen für die Angriffe eines Begleiters im Gefecht (Vertraute V3a).
///
/// AT, PA und TP stammen aus dem Kampfprofil und sind damit schon mit
/// Steigerung und Ausbildung verrechnet. Es sind Würfelhilfen: Die App führt
/// für Begleiter weder Aktionen pro Runde noch Initiative noch eine Buchung
/// am Gegner; Treffer und Schaden überträgt der Spieler selbst.
library;

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

import 'begleiter_kampfprofil_rules.dart';
import 'tp_ausdruck_rules.dart';

/// Hinweis zu Angriffen, die als magisch gelten.
const String kBegleiterMagischHinweis =
    'Die Angriffe des Vertrauten gelten als magisch und können auch '
    'dämonische Wesenheiten verletzen (WdZ S. 125).';

String _angriffsname(BegleiterKampfprofil p, BegleiterAngriffsprofil a) =>
    '${p.name}: ${a.name}';

String _hinweis(BegleiterKampfprofil p, BegleiterAngriffsprofil a) => [
  'Wert des Begleiters mit Steigerung und Ausbildung; Zu- und Abschläge '
      'setzt der Spieler im Dialog.',
  if (a.dk.trim().isNotEmpty) 'DK ${a.dk.trim()}.',
  if (p.angriffeMagisch) kBegleiterMagischHinweis,
].join(' ');

/// AT-Probe des Angriffs [a]; `null`, wenn der Angriff keine AT hat.
ResolvedProbeRequest? begleiterAngriffProbe(
  BegleiterKampfprofil p,
  BegleiterAngriffsprofil a,
) {
  final at = a.at;
  if (at == null) return null;
  return ResolvedProbeRequest(
    type: ProbeType.combatAttack,
    title: 'AT ${_angriffsname(p, a)}',
    subtitle: 'Begleiter · AT $at',
    ruleHint: _hinweis(p, a),
    diceSpec: const DiceSpec(count: 1, sides: 20),
    targets: [ProbeTargetValue(label: 'AT ${a.name}', value: at)],
  );
}

/// PA-Probe des Angriffs [a]; `null`, wenn der Angriff keine PA hat.
ResolvedProbeRequest? begleiterParadeProbe(
  BegleiterKampfprofil p,
  BegleiterAngriffsprofil a,
) {
  final pa = a.pa;
  if (pa == null) return null;
  return ResolvedProbeRequest(
    type: ProbeType.combatParry,
    title: 'PA ${_angriffsname(p, a)}',
    subtitle: 'Begleiter · PA $pa',
    ruleHint: _hinweis(p, a),
    diceSpec: const DiceSpec(count: 1, sides: 20),
    targets: [ProbeTargetValue(label: 'PA ${a.name}', value: pa)],
  );
}

/// TP-Wurf des Angriffs [a]; `null`, wenn sich die TP-Angabe nicht als
/// Würfelausdruck lesen lässt („Huf +2“, leer).
ResolvedProbeRequest? begleiterSchadenProbe(
  BegleiterKampfprofil p,
  BegleiterAngriffsprofil a,
) {
  final wuerfel = tpAusdruckZuWuerfel(a.tp);
  if (wuerfel == null) return null;
  return ResolvedProbeRequest(
    type: ProbeType.damage,
    title: 'TP ${_angriffsname(p, a)}',
    subtitle: '${a.name} · ${wuerfel.label}',
    ruleHint:
        'Trefferpunkte des Begleiters; Rüstungsschutz und Buchung am Gegner '
        'übernimmt der Spieler.${p.angriffeMagisch ? ' $kBegleiterMagischHinweis' : ''}',
    diceSpec: wuerfel,
    targets: const [],
  );
}
