/// ZfW* und Probenwerte einer Zauberprobe als Herleitung (ARCH-04).
///
/// Ein Zauber wird mit dem ZfW des Heldeneintrags plus Modifikator gewürfelt;
/// die Probe läuft auf die drei Eigenschaften des Zaubers mit den
/// Probenwerten (Wunden und temporäre Eigenschaftsboni eingerechnet).
/// Probensuche, Magie-Tab und Gefecht nehmen dieselben Funktionen.
///
/// Bewusst **keine** Schritte von ZfW* (Teilstand 15):
/// - Zauberspezialisierung: +2 nur im spezialisierten Aspekt, höchstens eine je
///   Zauber (WdH S. 292 f.). Wie bei Talenten ein Schalter im Probendialog.
/// - Merkmalskenntnis: nur „eine Spalte leichter erlernen“ (WdH S. 289); steht
///   in der Lernspalten-Herleitung (`zauber_lernspalte_rules.dart`).
/// - Repräsentation: wirkt auf die Lernspalte (dort hergeleitet) und die
///   Zaubertechnik; fehlende Komponenten sind Veränderte Technik, eine spontane
///   Modifikation (WdZ S. 21), also situativ.
/// - AsP-Kosten: Katalogtext, oft Freitext; nur Hinweis im Probendialog.
library;

import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_spell_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_request_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_probe_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

/// Bezeichnung des ZfW-Grundwerts.
const String kZfwSchritt = 'ZfW';

/// Bezeichnung des eigenen Zaubermodifikators.
const String kZfwModifikatorSchritt = 'Modifikator';

/// Herleitung von ZfW* = ZfW + Modifikator des Heldeneintrags.
Herleitung herleiteZfw(HeroSpellEntry eintrag) => Herleitung(
  bezeichnung: 'ZfW*',
  schritte: <HerleitungsSchritt>[
    HerleitungsSchritt(
      bezeichnung: kZfwSchritt,
      betrag: eintrag.spellValue ?? 0,
      art: HerleitungsArt.zukauf,
    ),
    HerleitungsSchritt(
      bezeichnung: kZfwModifikatorSchritt,
      betrag: eintrag.modifier,
      art: HerleitungsArt.modifikator,
      quelle: 'Eigener Modifikator',
    ),
  ],
);

/// Aufgelöste Werte einer Zauberprobe.
class ZauberProbenwert {
  /// Hält Probenziele, ZfW* und seine Herleitung.
  const ZauberProbenwert({
    required this.ziele,
    required this.herleitung,
    this.spezialisierungen = const <String>[],
    this.kosten = '',
    this.kontext,
  });

  /// Drei Eigenschaften mit ihren Probenwerten.
  final List<ProbeTargetValue> ziele;

  /// Herleitung von ZfW*.
  final Herleitung herleitung;

  /// Zauberspezialisierungen des Helden (nicht leere Namen).
  final List<String> spezialisierungen;

  /// AsP-Kosten laut Katalog; leer, wenn unbekannt.
  final String kosten;

  /// Zauberdetails für den aufklappbaren Kontext im Probendialog.
  final ProbeKontext? kontext;

  /// ZfW* = ZfW + Modifikator.
  int get zfw => herleitung.wert;
}

/// Zauberdetails aus Katalog und Heldenoverrides (Override hat Vorrang, wie
/// im Zauberdetaildialog). Geschützte Texte bleiben roh.
ProbeKontext zauberKontextAus(HeroSpellEntry eintrag, SpellDef spell) {
  final overrides = eintrag.textOverrides;
  return ProbeKontext(
    wirkung: overrides?.wirkung ?? spell.wirkung,
    variantenRoh:
        overrides?.variants ?? spell.rawVariantsEncrypted ?? spell.variants,
    kosten: (overrides?.aspCost ?? spell.aspCost).trim(),
    zauberdauer: (overrides?.castingTime ?? spell.castingTime).trim(),
    reichweite: (overrides?.range ?? spell.range).trim(),
    wirkungsdauer: (overrides?.duration ?? spell.duration).trim(),
    zielobjekt: (overrides?.targetObject ?? spell.targetObject).trim(),
    merkmale: spell.traits.trim(),
    modifikationen: (overrides?.modifications ?? spell.modifications).trim(),
    quelle: spell.source.trim(),
  );
}

/// Probenwert eines Zaubers aus einem (gegebenenfalls ungespeicherten)
/// [eintrag] und den Probenwerten der Eigenschaften.
///
/// `null`, wenn der Zauber nicht aktiviert ist (kein ZfW) oder seine Kette
/// nicht genau drei bekannte Eigenschaften ergibt.
ZauberProbenwert? zauberProbenwertAus({
  required HeroSpellEntry eintrag,
  required SpellDef spell,
  required Attributes probenEigenschaften,
}) {
  if (eintrag.spellValue == null) return null;
  final ziele = probenzieleFuer(probenEigenschaften, spell.attributes);
  if (ziele.length != 3) return null;
  return ZauberProbenwert(
    ziele: ziele,
    herleitung: herleiteZfw(eintrag),
    spezialisierungen: List<String>.unmodifiable([
      for (final name in eintrag.specializations)
        if (name.trim().isNotEmpty) name.trim(),
    ]),
    kosten: (eintrag.textOverrides?.aspCost ?? spell.aspCost).trim(),
    kontext: zauberKontextAus(eintrag, spell),
  );
}

/// Probenwert des Zaubers [spell] für den Helden des [snapshot].
///
/// Die Eigenschaften sind `HeroComputedSnapshot.probenEigenschaften`; `null`,
/// wenn der Held den Zauber nicht führt oder nicht aktiviert hat.
ZauberProbenwert? zauberProbenwertFuer({
  required HeroComputedSnapshot snapshot,
  required SpellDef spell,
}) {
  final eintrag = snapshot.hero.spells[spell.id];
  if (eintrag == null) return null;
  return zauberProbenwertAus(
    eintrag: eintrag,
    spell: spell,
    probenEigenschaften: snapshot.probenEigenschaften,
  );
}

/// Zauberprobe über den gemeinsamen Probenbauer, mit ZfW*-Herleitung,
/// Spezialisierungsschalter und Kostenhinweis.
ResolvedProbeRequest zauberprobeAus({
  required ZauberProbenwert wert,
  required String titel,
}) => buildSpellProbeRequest(
  title: titel,
  targets: wert.ziele,
  basePool: wert.zfw,
  spezialisierungen: wert.spezialisierungen,
  zfwHerleitung: wert.herleitung,
  hinweise: zauberprobenHinweise(wert),
  kontext: wert.kontext,
);

/// Hinweise zur Zauberprobe. Spezialisierungen (Auswahl im Dialog) und Kosten
/// (Zauberdetails) stehen nicht mehr im Text; bleibt für künftige Hinweise.
List<String> zauberprobenHinweise(ZauberProbenwert wert) => const <String>[];

/// Ein gelernter Zauber des Helden mit seiner ZfW*-Herleitung.
class ZauberUebersicht {
  /// Erzeugt den Eintrag für die Wertesuche.
  const ZauberUebersicht({
    required this.id,
    required this.name,
    required this.herleitung,
  });

  /// Katalog-ID des Zaubers.
  final String id;

  /// Anzeigename.
  final String name;

  /// ZfW*-Herleitung.
  final Herleitung herleitung;
}

/// Sammelt die ZfW*-Herleitungen aller aktivierten Katalogzauber des Helden,
/// alphabetisch nach Name.
List<ZauberUebersicht> sammleZauberHerleitungen({
  required HeroComputedSnapshot snapshot,
  required Iterable<SpellDef> zauber,
}) {
  final ergebnis = <ZauberUebersicht>[
    for (final spell in zauber)
      if (snapshot.hero.spells[spell.id] case final e?
          when e.spellValue != null)
        ZauberUebersicht(
          id: spell.id,
          name: spell.name,
          herleitung: herleiteZfw(e),
        ),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ergebnis;
}
