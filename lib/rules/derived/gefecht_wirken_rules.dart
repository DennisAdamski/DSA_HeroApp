import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';

import 'active_spell_rules.dart';
import 'active_spell_state_rules.dart';
import 'gefecht_ansagefolge_rules.dart';

import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Variable Grundwirkungen verwenden den eingefrorenen Wurf, niemals neue AsP.
int gefechtsAbschlusskosten(Gefechtshandlung h) {
  if (h.abbruchKosten != null) return h.abbruchKosten!;
  final erfolg = h.ergebnis?.success == true && !h.gescheitert;
  if (erfolg && h.wirken!.fremdwirkung != null) {
    final wurf = h.fremdwirkungswurf;
    if (wurf == null) {
      throw StateError('Den einmaligen Schadenswurf zuerst festhalten.');
    }
    return wurf.kosten;
  }
  return erfolg
      ? h.wirken!.kosten
      : h.wirken!.misserfolgKosten ??
            gefechtsWirkkosten(h.wirken!.kosten, h.art, erfolg: false);
}

/// Übernimmt Eingabewerte, erhält aber unbekannte Felder des frischen Effekts.
HeroState uebernimmGefechtsArmatrutz(
  HeroState aktuell,
  ActiveSpellEffectDetail eingabe,
) {
  final detail = aktuell.activeSpellEffects.detailFor(
    activeSpellEffectArmatrutz,
  );
  final dauer = eingabe.duration;
  final frisch = detail.duration;
  final neueDauer = dauer == null || frisch == null
      ? dauer
      : frisch.copyWith(
          amount: dauer.amount,
          remaining: dauer.remaining,
          unit: dauer.unit,
        );
  return aktiviereArmatrutz(
    aktuell,
    detail.copyWith(
      amount: eingabe.amount,
      duration: neueDauer,
      clearDuration: dauer == null,
    ),
  );
}

/// WdZ 15: niedrige LE/AU und bestätigte aufrechterhaltene Zauber, ohne Wunddoppelung.
int gefechtsZauberZuschlag(
  HeroComputedSnapshot s, {
  required int aufrechterhalten,
  required bool simultanzaubern,
}) {
  final le = s.state.currentLep, maxLe = s.derivedStats.maxLep;
  final au = s.state.currentAu, maxAu = s.derivedStats.maxAu;
  final leMalus = maxLe <= 0
      ? 0
      : le * 4 <= maxLe
      ? 9
      : le * 3 <= maxLe
      ? 6
      : le * 2 <= maxLe
      ? 3
      : 0;
  final auMalus = maxAu <= 0
      ? 0
      : au * 4 <= maxAu
      ? 6
      : au * 3 <= maxAu
      ? 3
      : 0;
  return leMalus + auMalus + aufrechterhalten * (simultanzaubern ? 1 : 3);
}

/// Ein Bonus trifft nur den bestätigten Proben- oder Eigenschaftstitel.
bool gefechtsBonusPasst(ResolvedProbeRequest p, GefechtsProbenbonus? b) =>
    b != null && (p.title == b.ziel || p.targets.any((t) => t.label == b.ziel));

/// Folgemalus bleibt Probenzuschlag; Mirakelbonus erhöht Pool oder passenden Zielwert.
ResolvedProbeRequest gefechtsProbeMitBonus(
  ResolvedProbeRequest p,
  GefechtsProbenbonus? b, {
  int ansageFolgemalus = 0,
}) {
  p = gefechtsProbeMitAnsagefolgemalus(p, ansageFolgemalus);
  if (!gefechtsBonusPasst(p, b)) return p;
  final pool =
      p.title == b!.ziel &&
      (p.type == ProbeType.talent || p.type == ProbeType.spell);
  return ResolvedProbeRequest(
    type: p.type,
    title: p.title,
    subtitle: p.subtitle,
    ruleHint: '${p.ruleHint} Einmaliger bestätigter Mirakelbonus: ${b.wert}.',
    diceSpec: p.diceSpec,
    basePool: p.basePool + (pool ? b.wert : 0),
    targets: pool
        ? p.targets
        : [
            for (final t in p.targets)
              ProbeTargetValue(
                label: t.label,
                value:
                    t.value +
                    (p.title == b.ziel || t.label == b.ziel ? b.wert : 0),
              ),
          ],
    specializationBonus: p.specializationBonus,
    initialSpecializationApplied: p.initialSpecializationApplied,
    initialSituationalModifier: p.initialSituationalModifier,
    fixedRollTotal: p.fixedRollTotal,
  );
}

/// Gemeinsamer karmaler Zuschlag hält Grad, Wiederholung und Kontext auseinander.
int gefechtsKarmalzuschlag({
  required int grad,
  required bool mirakel,
  required int mirakelklasse,
  required int fehlversuche,
  required int zusaetzlich,
}) =>
    zusaetzlich +
    (mirakel ? mirakelklasse : gefechtsGradzuschlag(grad)) +
    fehlversuche * 3;

/// Konzentrationsstärke erleichtert ausschließlich die Störungsprobe um sieben.
int gefechtsStoerungszuschlag(
  int zuschlag, {
  required bool konzentrationsstaerke,
}) => zuschlag - (konzentrationsstaerke ? 7 : 0);

/// Nur eindeutige ganze Aktionsangaben sind sichere Vorbelegungen.
int? gefechtsFesteAktionen(String text) {
  final m = RegExp(
    r'^\s*(\d+)\s+Aktion(?:en)?\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  final wert = m == null ? null : int.tryParse(m[1]!);
  return wert != null && wert > 0 ? wert : null;
}

/// Variable, permanente und laufende Kosten werden nicht aus Freitext geraten.
int? gefechtsFesteKosten(String text) {
  final m = RegExp(
    r'^\s*(\d+)\s+(?:AsP|KaP)\s*$',
    caseSensitive: false,
  ).firstMatch(text);
  return m == null ? null : int.tryParse(m[1]!);
}

/// Angebrochene halbe Aktionen werden auf ganze Marken aufgerundet (App-Regel).
int gefechtsWirkdauer(
  int dauer, {
  required bool erfolg,
  required bool zauberkontrolle,
}) {
  if (dauer < 1) throw ArgumentError.value(dauer, 'dauer');
  return erfolg
      ? dauer
      : zauberkontrolle
      ? 1
      : (dauer + 1) ~/ 2;
}

/// Bestätigte Standardkosten nach WdZ und LL; Sonderfälle benötigen ein Profil.
int gefechtsWirkkosten(
  int kosten,
  Gefechtshandlungsart art, {
  required bool erfolg,
}) {
  if (kosten < 0) throw ArgumentError.value(kosten, 'kosten');
  if (erfolg) return kosten;
  if (art == Gefechtshandlungsart.mirakel) return 1;
  if (art == Gefechtshandlungsart.liturgie) {
    if (kosten % 5 != 0) {
      throw StateError('Rundung der Liturgiekosten bestätigen.');
    }
    return kosten < 5 ? 1 : kosten ~/ 5;
  }
  return (kosten + 1) ~/ 2;
}

/// Gewöhnliche Grade I–VI kosten fünf KaP je Grad (permanente Kosten separat).
int gefechtsGradkosten(int grad) {
  if (grad < 1 || grad > 6) throw ArgumentError.value(grad, 'grad');
  return grad * 5;
}

/// Gewöhnliche Gradmodifikatoren, ohne gesonderte Aufstufungs-/Situationsregeln.
int gefechtsGradzuschlag(int grad) {
  gefechtsGradkosten(grad);
  return (grad - 1) * 2;
}

/// Bucht gegen den frisch geladenen Stand und verhindert stilles Klemmen auf null.
HeroState uebernimmGefechtsWirkkosten(
  HeroState aktuell,
  int kosten, {
  required bool karmal,
}) {
  final energie = karmal ? aktuell.currentKap : aktuell.currentAsp;
  if (kosten < 0 || energie < kosten) {
    throw StateError(
      'Energie inzwischen unzureichend; Abschluss bleibt offen.',
    );
  }
  return karmal
      ? aktuell.copyWith(currentKap: energie - kosten)
      : aktuell.copyWith(currentAsp: energie - kosten);
}

/// Zusätzliche Zuschläge verändern den vorhandenen Probenpool genau einmal.
ResolvedProbeRequest modifiziereGefechtsWirkprobe(
  ResolvedProbeRequest probe,
  int zuschlag,
) => ResolvedProbeRequest(
  type: probe.type,
  title: probe.title,
  subtitle: probe.subtitle,
  ruleHint: '${probe.ruleHint} Zusatzmodifikator: $zuschlag.',
  diceSpec: probe.diceSpec,
  targets: probe.targets,
  basePool: probe.basePool,
  specializationBonus: probe.specializationBonus,
  initialSpecializationApplied: probe.initialSpecializationApplied,
  initialSituationalModifier: probe.initialSituationalModifier - zuschlag,
);

/// Hausregel S.25–26; unbekannte Kulte erhalten keine erfundene Eigenschaftskette.
List<String>? gefechtsKultEigenschaften(String kult) {
  final k = kult.trim().toLowerCase();
  if (['boron', 'hesinde', 'nandus'].contains(k)) return ['MU', 'KL', 'IN'];
  if ([
    'praios',
    'ucuri',
    'rondra',
    'kor',
    'swafnir',
    'efferd',
    'travia',
    'firun',
    'ifirn',
    'tsa',
    'phex',
    'aves',
    'peraine',
    'ingerimm',
    'rahja',
  ].contains(k)) {
    return ['MU', 'IN', 'CH'];
  }
  return null;
}
