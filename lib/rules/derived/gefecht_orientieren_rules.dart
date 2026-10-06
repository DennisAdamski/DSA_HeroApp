import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'gefecht_held_rules.dart';
import 'gefecht_rules.dart';

/// Herkunft einer ausdrücklich korrigierten INI-Minderung.
enum IniVerlustart { kampf, geschuetzt, ungeklaert }

/// Ersetzt nur den gewählten Verlustanteil, ohne andere Ursachen zu löschen.
Gefechtszustand korrigiereIniVerlust(
  Gefechtszustand s,
  int wert,
  IniVerlustart art,
) => switch (art) {
  IniVerlustart.kampf => s.copyWith(
    iniVerlust: wert,
    ungeklaerterIniVerlust: 0,
  ),
  IniVerlustart.geschuetzt => s.copyWith(
    geschuetzterIniVerlust: wert,
    ungeklaerterIniVerlust: 0,
  ),
  IniVerlustart.ungeklaert => s.copyWith(ungeklaerterIniVerlust: wert),
};

/// Bestätigte Dauer und einmalige IN-Probe nach WdS 56.
class Orientierungsplan {
  /// Aufmerksamkeit ersetzt die Probe, nicht die Aktionskosten.
  const Orientierungsplan(this.dauer, this.probe);
  final int dauer;
  final ResolvedProbeRequest? probe;
}

/// Baut die Regel aus echten Werten, ohne Kriegskunst-Situationsboni.
Orientierungsplan orientierungsplan({
  required int intuition,
  required int kriegskunst,
  required bool aufmerksamkeit,
  bool position = false,
}) {
  final bonus = kriegskunst > 0 ? kriegskunst ~/ 2 : 0;
  return Orientierungsplan(
    aufmerksamkeit || position ? 1 : 2,
    aufmerksamkeit
        ? null
        : ResolvedProbeRequest(
            type: ProbeType.attribute,
            title: 'Orientieren · IN-Probe',
            subtitle: 'Kriegskunst: Erleichterung $bonus',
            ruleHint: 'WdS S. 56; INI nur bei Erfolg übernehmen.',
            diceSpec: const DiceSpec(count: 1, sides: 20),
            targets: [ProbeTargetValue(label: 'IN', value: intuition + bonus)],
          ),
  );
}

/// Liest die aktuelle effektive IN und den unveränderten Kriegskunst-TaW.
Orientierungsplan orientierungFuer(
  HeroComputedSnapshot snapshot, {
  bool position = false,
}) => orientierungsplan(
  intuition: snapshot.probenEigenschaften.inn,
  kriegskunst: snapshot.hero.talents['tal_kriegskunst']?.talentValue ?? 0,
  aufmerksamkeit: gefechtswerteFuer(snapshot).aufmerksamkeit,
  position: position,
);

/// Prüft die nächste reguläre Marke; SK-II-Zusatzparaden sind ausgeschlossen.
Gefechtspruefung pruefeOrientierung(
  Gefechtszustand s,
  Gefechtswerte w, {
  bool position = false,
  bool eingeschraenkt = false,
  bool fortsetzen = false,
  bool eigenerAuftrag = false,
}) {
  final p = pruefeGefechtsaktion(
    position ? s.copyWith(desorientiert: false) : s,
    w,
    fortsetzen ? Gefechtsaktion.handlung : Gefechtsaktion.position,
    handlungFortsetzen: fortsetzen,
    eigenerAuftrag: eigenerAuftrag,
  );
  final sperren = <String>[
    if (p.status == Gefechtsfreigabe.gesperrt) ...p.gruende,
    if (s.haltung == Gefechtshaltung.liegend) 'Liegend kein Orientieren.',
    if (eingeschraenkt) 'Wahrnehmung oder Bewegung eingeschränkt.',
    if (s.ungeklaerterIniVerlust != 0) 'Manuelle INI-Verluste zuerst zuordnen.',
    if (s.desorientiert && !position) 'Position + Orientieren verwenden.',
  ];
  return Gefechtspruefung(
    aktion: Gefechtsaktion.handlung,
    status: sperren.isEmpty
        ? Gefechtsfreigabe.bereit
        : Gefechtsfreigabe.gesperrt,
    gruende: sperren,
    zielwert: null,
    angriffe: p.angriffe,
    paraden: p.paraden,
  );
}

/// Übernimmt nur rückgewinnbare Verluste; Heldenmali bleiben außerhalb der Sitzung.
Gefechtszustand uebernimmOrientierung(
  Gefechtszustand s, {
  required int maximum,
  required bool erfolg,
  bool position = false,
}) {
  final bereinigt = s.ansageFolgemalus == 0
      ? s
      : s.copyWith(ansageFolgemalus: 0);
  if (!erfolg && !position) return bereinigt;
  return bereinigt.copyWith(
    iniWurf: erfolg ? maximum : s.iniWurf,
    iniVerlust: erfolg ? 0 : s.iniVerlust,
    desorientiert: position ? false : s.desorientiert,
  );
}

/// Behält das etablierte Klingentänzer-Maximum als ausdrückliche App-Konvention.
int orientierungsmaximum(HeroComputedSnapshot snapshot) =>
    snapshot.combatPreviewStats.initiativeDiceSpec.count * 6;
