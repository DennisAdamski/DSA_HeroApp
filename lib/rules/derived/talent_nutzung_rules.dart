/// Wer ein Talent proben darf und worauf er ausweichen kann (WdS S. 16 f.,
/// Basisregelwerk S. 113). Die Tabelle steht in `talent_nutzung_katalog.dart`.
library;

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/catalog/talent_nutzung_katalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';

/// Der Eintrag, mit dem [hero] auf [talent] proben darf; `null`, wenn er es
/// nicht darf.
///
/// * Basis-Talente darf jeder Held proben: ohne Eintrag oder ohne Wert gilt
///   TaW 0, ein negativer TaW bleibt erlaubt.
/// * Spezial-Talente brauchen einen aktivierten Wert von mindestens 0; ein
///   nicht aktiviertes oder negatives Talent erlaubt keine Probe.
/// * Talente, die die Tabelle nicht kennt (eigene Katalogeinträge), verlangen
///   wie Spezial-Talente einen Wert.
HeroTalentEntry? talentEintragFuerProbe(HeroSheet hero, TalentDef talent) {
  final eintrag = hero.talents[talent.id];
  final nutzung = talentNutzungFuer(talent.id);
  if (nutzung != null && nutzung.basis) {
    return eintrag ?? const HeroTalentEntry(talentValue: 0);
  }
  final wert = eintrag?.talentValue;
  if (eintrag == null || wert == null) return null;
  if (nutzung != null && wert < 0) return null;
  return eintrag;
}

/// Ein Talent, auf das der Held statt des geforderten ausweichen kann.
class TalentErsatzOption {
  /// Das Ersatztalent [talent] mit Richtzuschlag [zuschlag].
  const TalentErsatzOption({
    required this.talent,
    required this.zuschlag,
    this.bedingung,
  });

  /// Ersatztalent, das der Held proben darf.
  final TalentDef talent;

  /// Abzug vom TaW des Ersatztalents; `null`, wenn der Meister ihn bestimmt.
  final int? zuschlag;

  /// Einschränkung des Buchs, etwa „nur mit der Spezialisierung Bauchreden“.
  final String? bedingung;
}

/// Talente, auf die der Held für [talent] ausweichen kann.
///
/// Es erscheinen nur Ersatztalente, die er selbst proben darf
/// ([talentEintragFuerProbe]); die Reihenfolge folgt dem Buch.
List<TalentErsatzOption> talentErsatzOptionen({
  required HeroSheet hero,
  required TalentDef talent,
  required Iterable<TalentDef> katalog,
}) {
  final nutzung = talentNutzungFuer(talent.id);
  if (nutzung == null) return const <TalentErsatzOption>[];
  final nachId = <String, TalentDef>{for (final t in katalog) t.id: t};
  return <TalentErsatzOption>[
    for (final ersatz in nutzung.ersatz)
      if (nachId[ersatz.talentId] case final def?)
        if (talentEintragFuerProbe(hero, def) != null)
          TalentErsatzOption(
            talent: def,
            zuschlag: ersatz.zuschlag,
            bedingung: ersatz.bedingung,
          ),
  ];
}
