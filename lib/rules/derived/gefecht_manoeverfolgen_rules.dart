import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

/// WdS MCP 6991/7003: bestätigte KK-/GE-Gegenprobe nach misslungener Abwehr.
ResolvedProbeRequest gefechtsGegenprobe(
  String id, {
  required int eigenschaft,
  bool meisterlich = false,
  int? tp,
  int standBonus = 0,
}) {
  final entwaffnen = id == 'man_entwaffnen';
  if (!entwaffnen && id != 'man_umreissen' ||
      eigenschaft < 1 ||
      !entwaffnen && (tp == null || tp < 0) ||
      ![0, 2, 4, 8].contains(standBonus)) {
    throw ArgumentError(
      'Vollständiges belegtes Gegenprobenprofil erforderlich.',
    );
  }
  final erschwernis = entwaffnen ? (meisterlich ? 10 : 8) : tp! - standBonus;
  return ResolvedProbeRequest(
    type: ProbeType.attribute,
    title: entwaffnen
        ? 'Entwaffnen · gegnerische KK'
        : 'Umreißen · gegnerische GE',
    subtitle: 'Bestätigter Gegnerwert',
    ruleHint: 'Schadensloses Manöver; keine LeP-Buchung.',
    diceSpec: const DiceSpec(count: 1, sides: 20),
    targets: [
      ProbeTargetValue(label: entwaffnen ? 'KK' : 'GE', value: eigenschaft),
    ],
    initialSituationalModifier: -erschwernis,
  );
}

/// Gegenprobenergebnis erzeugt ausschließlich die belegte flüchtige Gegnerfolge.
Gefechtsgegner gefechtsManoeverfolge(
  Gefechtsgegner g,
  String id, {
  required bool gegenprobeErfolg,
  int? iniVerlust,
}) {
  if (gegenprobeErfolg) return g;
  if (id == 'man_entwaffnen') return g.copyWith(entwaffnet: true);
  if (id == 'man_umreissen' &&
      iniVerlust != null &&
      iniVerlust >= 2 &&
      iniVerlust <= 12) {
    return g.copyWith(liegend: true, ini: g.ini - iniVerlust);
  }
  throw ArgumentError('Bestätigter 2W6-INI-Verlust erforderlich.');
}
