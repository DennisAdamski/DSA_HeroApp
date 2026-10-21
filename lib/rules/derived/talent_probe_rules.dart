import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'probe_request_rules.dart';

import 'package:dsa_heldenverwaltung/catalog/talent_nutzung_katalog.dart';

import 'herleitung.dart';
import 'talent_herleitung_rules.dart';
import 'talent_nutzung_rules.dart';

/// Aufgelöste Werte einer Talentprobe des Helden.
class TalentProbenwert {
  /// Hält Probenziele, TaW* und die Grundlagen seiner Berechnung.
  const TalentProbenwert({
    required this.ziele,
    required this.taw,
    required this.ebe,
    required this.herleitung,
    this.spezialisierungen = const <String>[],
  });

  /// Drei Eigenschaften mit ihren Probenwerten (Wunden eingerechnet).
  final List<ProbeTargetValue> ziele;

  /// TaW* = TaW + Modifikator + eBE + Inventarbonus.
  final int taw;

  /// Effektive Behinderung des Talents (negativ oder 0).
  final int ebe;

  /// Herleitungen von TaW*, eBE und Probenwerten; [taw] und [ebe] sind ihre
  /// Summen.
  final TalentHerleitungen herleitung;

  /// Namen der Spezialisierungen des Helden für dieses Talent.
  final List<String> spezialisierungen;

  /// Der Held führt eine Spezialisierung für dieses Talent.
  bool get spezialisierung => spezialisierungen.isNotEmpty;
}

/// Spezialisierungen eines Talenteintrags als bereinigte Namensliste.
///
/// Die normalisierte Liste der Kampftalente hat Vorrang, sonst der
/// Freitext (getrennt an Komma, Semikolon und Zeilenumbruch).
List<String> talentSpezialisierungenAus(HeroTalentEntry eintrag) {
  final roh = eintrag.combatSpecializations.isNotEmpty
      ? eintrag.combatSpecializations
      : eintrag.specializations.split(RegExp(r'[\n,;]+'));
  final gesehen = <String>{};
  return List<String>.unmodifiable([
    for (final name in roh)
      if (name.trim().isNotEmpty && gesehen.add(name.trim())) name.trim(),
  ]);
}

/// Löst Eigenschaftsnamen in Probenziele mit den aktuellen Werten auf.
///
/// Unbekannte Namen werden ausgelassen; Aufrufer prüfen die erwartete Anzahl.
List<ProbeTargetValue> probenzieleFuer(
  Attributes werte,
  List<String> eigenschaften,
) => List<ProbeTargetValue>.unmodifiable([
  for (final name in eigenschaften)
    if (parseAttributeCode(name) case final code?)
      ProbeTargetValue(
        label: attributeCodeKey(code),
        value: readAttributeValue(werte, code),
      ),
]);

/// TaW* einer Talentprobe, identisch für Probensuche und Gefecht.
///
/// Berücksichtigt die effektive Behinderung aus der Kampf-BE (oder der
/// vorübergehenden Talentansicht [talentBeOverride]), die epische
/// KK-Halbierung, den Talentmodifikator und Inventarboni. [eigenschaften]
/// ersetzt die Katalogkette (etwa die gottspezifische Liturgieprobe).
/// `null`, wenn der Held das Talent nicht proben darf (`talentEintragFuerProbe`:
/// Basis-Talente immer, Spezial-Talente nur aktiviert) oder die Kette nicht
/// genau drei Eigenschaften ergibt.
TalentProbenwert? talentProbenwertFuer({
  required HeroComputedSnapshot snapshot,
  required TalentDef talent,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
  List<String>? eigenschaften,
}) {
  final hero = snapshot.hero;
  final eintrag = talentEintragFuerProbe(hero, talent);
  if (eintrag == null) return null;
  final ziele = probenzieleFuer(
    snapshot.probenEigenschaften,
    eigenschaften ?? talent.attributes,
  );
  if (ziele.length != 3) return null;
  final herleitung = herleiteTalent(
    snapshot: snapshot,
    talent: talent,
    epicAdvantagesActive: epicAdvantagesActive,
    talentBeOverride: talentBeOverride,
    eigenschaften: eigenschaften,
  );
  if (herleitung == null) return null;
  return TalentProbenwert(
    ziele: ziele,
    taw: herleitung.taw.wert,
    ebe: herleitung.ebe.wert,
    herleitung: herleitung,
    spezialisierungen: talentSpezialisierungenAus(eintrag),
  );
}

/// Talentprobe des Helden über den gemeinsamen Probenbauer.
///
/// [initialSituationalModifier] belegt den Probendialog vor; negativ heißt
/// erschwert (Konvention des Probenmodells).
ResolvedProbeRequest? talentprobeFuer({
  required HeroComputedSnapshot snapshot,
  required TalentDef talent,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
  int initialSituationalModifier = 0,
}) {
  final wert = talentProbenwertFuer(
    snapshot: snapshot,
    talent: talent,
    epicAdvantagesActive: epicAdvantagesActive,
    talentBeOverride: talentBeOverride,
  );
  if (wert == null) return null;
  return buildTalentProbeRequest(
    title: talent.name,
    targets: wert.ziele,
    basePool: wert.taw,
    spezialisierungen: wert.spezialisierungen,
    initialSituationalModifier: initialSituationalModifier,
    tawHerleitung: wert.herleitung.taw,
  );
}

/// Probe auf [talent] über das Ersatztalent von [option].
///
/// Der TaW* des Ersatztalents sinkt um den Zuschlag (ohne Buchwert um 0); die
/// Probe läuft auf dessen Eigenschaften. Eine Spezialisierung des geforderten
/// Talents gilt dabei nicht.
ResolvedProbeRequest? talentErsatzprobeFuer({
  required HeroComputedSnapshot snapshot,
  required TalentDef talent,
  required TalentErsatzOption option,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
}) {
  final wert = talentProbenwertFuer(
    snapshot: snapshot,
    talent: option.talent,
    epicAdvantagesActive: epicAdvantagesActive,
    talentBeOverride: talentBeOverride,
  );
  if (wert == null) return null;
  final zuschlag = option.zuschlag ?? 0;
  return buildTalentProbeRequest(
    title:
        '${talent.name} (über ${option.talent.name}'
        '${zuschlag == 0 ? '' : ' −$zuschlag'})',
    targets: wert.ziele,
    basePool: wert.taw - zuschlag,
    tawHerleitung: Herleitung(
      bezeichnung: wert.herleitung.taw.bezeichnung,
      schritte: <HerleitungsSchritt>[
        ...wert.herleitung.taw.schritte,
        if (zuschlag != 0)
          HerleitungsSchritt(
            bezeichnung: 'Ausweichzuschlag',
            betrag: -zuschlag,
            art: HerleitungsArt.modifikator,
            quelle: 'Ersatztalent ${option.talent.name}',
            bedingung: 'Meisterentscheid',
          ),
      ],
    ),
  );
}

/// Eine mögliche Ausweichprobe für ein Talent, das der Held nicht proben darf.
class TalentErsatzProbe {
  /// Fasst [talent], den Weg [option] und die fertige Probe [request] zusammen.
  const TalentErsatzProbe({
    required this.talent,
    required this.option,
    required this.request,
  });

  /// Das geforderte Talent, das der Held nicht beherrscht.
  final TalentDef talent;

  /// Ausweichtalent samt Richtzuschlag und Einschränkung.
  final TalentErsatzOption option;

  /// Fertige Probe auf dem Ersatztalent (TaW* abzüglich Zuschlag).
  final ResolvedProbeRequest request;
}

/// Alle Ausweichproben für Talente aus [katalog], die der Held nicht proben
/// darf (nicht aktivierte Spezial-Talente), alphabetisch nach Talent.
///
/// Ob und wie ausgewichen wird, entscheidet der Meister; die Liste zeigt nur,
/// was das Buch vorsieht und was der Held selbst proben darf. Kampftalente und
/// Talente ohne Eintrag in der Nutzungstabelle fehlen.
List<TalentErsatzProbe> talentErsatzproben({
  required HeroComputedSnapshot snapshot,
  required Iterable<TalentDef> katalog,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
}) {
  final talente = katalog.toList(growable: false);
  final ergebnis = <TalentErsatzProbe>[];
  for (final talent in talente) {
    if (talent.group == 'Kampftalent') continue;
    if (talentNutzungFuer(talent.id) == null) continue;
    if (talentEintragFuerProbe(snapshot.hero, talent) != null) continue;
    for (final option in talentErsatzOptionen(
      hero: snapshot.hero,
      talent: talent,
      katalog: talente,
    )) {
      final request = talentErsatzprobeFuer(
        snapshot: snapshot,
        talent: talent,
        option: option,
        epicAdvantagesActive: epicAdvantagesActive,
        talentBeOverride: talentBeOverride,
      );
      if (request != null) {
        ergebnis.add(
          TalentErsatzProbe(talent: talent, option: option, request: request),
        );
      }
    }
  }
  ergebnis.sort((a, b) {
    final c = a.talent.name.toLowerCase().compareTo(
      b.talent.name.toLowerCase(),
    );
    return c != 0
        ? c
        : (a.option.zuschlag ?? 0).compareTo(b.option.zuschlag ?? 0);
  });
  return ergebnis;
}
