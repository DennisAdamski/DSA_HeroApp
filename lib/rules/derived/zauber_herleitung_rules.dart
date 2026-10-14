/// ZfW* und Probenwerte einer Zauberprobe als Herleitung (ARCH-04).
///
/// Ein Zauber wird mit dem ZfW des Heldeneintrags plus Modifikator gewürfelt;
/// die Probe läuft auf die drei Eigenschaften des Zaubers mit den
/// Probenwerten (Wunden und temporäre Eigenschaftsboni eingerechnet).
/// Probensuche, Magie-Tab und Gefecht nehmen dieselben Funktionen.
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
  const ZauberProbenwert({required this.ziele, required this.herleitung});

  /// Drei Eigenschaften mit ihren Probenwerten.
  final List<ProbeTargetValue> ziele;

  /// Herleitung von ZfW*.
  final Herleitung herleitung;

  /// ZfW* = ZfW + Modifikator.
  int get zfw => herleitung.wert;
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
  return ZauberProbenwert(ziele: ziele, herleitung: herleiteZfw(eintrag));
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

/// Zauberprobe über den gemeinsamen Probenbauer.
ResolvedProbeRequest zauberprobeAus({
  required ZauberProbenwert wert,
  required String titel,
}) => buildSpellProbeRequest(
  title: titel,
  targets: wert.ziele,
  basePool: wert.zfw,
);

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
