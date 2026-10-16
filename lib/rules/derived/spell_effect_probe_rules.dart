import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_combat_rules.dart';

// Probenbeiträge laufender Zauberwirkungen (MAG-EFF-03).
//
// Die Zahlen entstehen einmal in `berechneSpellEffectBeitraege`; dieses Modul
// wählt nur aus, was zu einer konkreten Probe passt, und schreibt es in den
// Startwert des situativen Modifikators. So sehen Magie-Tab, Probensuche,
// Talenttabellen und Gefecht dieselbe Zahl, und der Nutzer kann sie im Dialog
// noch verändern (Meisterentscheid).

/// Auswahl der Beiträge, die auf eine Probe wirken.
class SpellEffectProbenAnpassung {
  /// Erstellt die Anpassung.
  const SpellEffectProbenAnpassung({
    this.wert = 0,
    this.beschreibungen = const <String>[],
  });

  /// Summe der Beiträge (positiv = erleichtert, negativ = erschwert).
  final int wert;

  /// Je Beitrag eine Zeile für den Probendialog, etwa `Adlerauge … +5`.
  final List<String> beschreibungen;

  /// `true`, wenn kein Beitrag zur Probe passt.
  bool get istLeer => beschreibungen.isEmpty;
}

/// Wählt die Beiträge aus, die zu einer Probe der Art [typ] passen.
///
/// Talentproben bekommen Beiträge mit `talent` (und passendem
/// [talentName], falls der Beitrag talentgebunden ist), Zauberproben
/// Beiträge mit `zauber`. Alle anderen Probenarten bleiben unberührt.
SpellEffectProbenAnpassung probenAnpassungFuer(
  SpellEffectBeitraege beitraege, {
  required ProbeType typ,
  String? talentName,
}) {
  if (typ != ProbeType.talent && typ != ProbeType.spell) {
    return const SpellEffectProbenAnpassung();
  }
  var summe = 0;
  final texte = <String>[];
  for (final beitrag in beitraege.probenBeitraege) {
    final passt = switch (typ) {
      ProbeType.talent =>
        beitrag.talent &&
            (beitrag.talentName == null ||
                (talentName != null &&
                    beitrag.talentName!.toLowerCase() ==
                        talentName.trim().toLowerCase())),
      ProbeType.spell => beitrag.zauber,
      _ => false,
    };
    if (!passt || beitrag.wert == 0) {
      continue;
    }
    summe += beitrag.wert;
    texte.add(
      '${beitrag.bezeichnung} ${beitrag.wert > 0 ? '+' : '−'}'
      '${beitrag.wert.abs()}',
    );
  }
  return SpellEffectProbenAnpassung(
    wert: summe,
    beschreibungen: List<String>.unmodifiable(texte),
  );
}

/// Name des Talents einer Talentprobe aus ihrem Titel (`Talentprobe: X`).
///
/// `null` für andere Probenarten oder Titel ohne diese Form. Der Titel
/// entsteht zentral in `buildTalentProbeRequest`.
String? talentNameAusProbe(ResolvedProbeRequest probe) {
  const praefix = 'Talentprobe: ';
  if (probe.type != ProbeType.talent || !probe.title.startsWith(praefix)) {
    return null;
  }
  final name = probe.title.substring(praefix.length);
  // Ersatzproben tragen den Zusatz „(über …)“; dort gilt das Ersatztalent
  // nicht als das geforderte.
  return name.contains(' (über ') ? null : name.trim();
}

/// Die Probe [probe] mit den passenden Zauberbeiträgen im Startmodifikator.
///
/// Ohne passenden Beitrag kommt dieselbe Instanz zurück.
ResolvedProbeRequest probeMitSpellEffekten(
  ResolvedProbeRequest probe,
  SpellEffectBeitraege beitraege,
) {
  final anpassung = probenAnpassungFuer(
    beitraege,
    typ: probe.type,
    talentName: talentNameAusProbe(probe),
  );
  if (anpassung.istLeer) {
    return probe;
  }
  return probe.copyWith(
    initialSituationalModifier:
        probe.initialSituationalModifier + anpassung.wert,
    ruleHint:
        '${probe.ruleHint} Zaubereffekte im Startwert: '
        '${anpassung.beschreibungen.join(', ')}.',
  );
}
