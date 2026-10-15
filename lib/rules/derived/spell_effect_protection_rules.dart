import 'dart:math' as math;

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_profile_rules.dart';

// Schutzvorräte von Zauberschilden (MAG-EFF-05).
//
// Ein Schildzauber ist kein Rüstungsschutz, sondern ein Vorrat, der Trefferpunkte
// aufnimmt, bis er aufgezehrt ist. Er steht deshalb nicht in `rsTotal` und
// verändert keinen Basiswert. Aufgefangen wird erst, wenn der Nutzer einen
// Treffer ausdrücklich als direkten magischen Angriff einordnet; die App
// erkennt das nicht selbst. Ein Auffangvorgang schreibt genau eine Instanz und
// ist über den erwarteten Restvorrat gegen Wiederholung gesichert.
//
// Beleg: Liber Cantiones S. 92 (Gardianum Zauberschild).

/// Zauber-ID des Gardianum Zauberschild.
const String kGardianumZauberId = 'spell_gardianum_zauberschild';

/// Zauber mit Schutzvorrat, die dieses Modul auswertet. Die Auswahlliste des
/// Dialogs spiegelt sie in `kSchutzAuswahlZauberIds` (ein Test hält beide
/// gleich).
const Set<String> kSchutzZauberIds = <String>{kGardianumZauberId};

/// Mindestens einzusetzende AsP (Kosten „nach Wahl, mindestens aber 3 AsP“).
const int kGardianumMindestAsp = 3;

/// Mindest-ZfW der Variante „Persönlicher Schild“.
const int kPersoenlicherSchildMindestZfw = 11;

/// Ausprägung des Gardianum.
enum Schutzvariante {
  /// Grundwirkung: Kuppel von 3 Schritt Radius, Vorrat AsP + 2 × ZfP*.
  kuppel,

  /// Variante „Persönlicher Schild“ (ab ZfW 11): Vorrat AsP + 3 × ZfP*.
  persoenlich,
}

/// Anfangsvorrat des Gardianum in TP.
///
/// Die Grundwirkung fängt „die investierten AsP plus die doppelten ZfP*“ auf,
/// der persönliche Schild „3 mal ZfP* plus eingesetzte AsP“. `null`, wenn
/// weniger als [kGardianumMindestAsp] AsP oder negative ZfP* angegeben sind:
/// Dann gibt es keinen belegten Vorrat.
int? gardianumKapazitaet({
  required Schutzvariante variante,
  required int zfpStern,
  required int investierteAsp,
}) {
  if (investierteAsp < kGardianumMindestAsp || zfpStern < 0) {
    return null;
  }
  final faktor = variante == Schutzvariante.persoenlich ? 3 : 2;
  return investierteAsp + faktor * zfpStern;
}

/// Hinweis, wenn der angegebene ZfW für [variante] nicht reicht; sonst `null`.
///
/// Nur ein Hinweis: ob der Zaubernde die Variante beherrscht, entscheidet der
/// Tisch.
String? schutzvarianteHinweis(Schutzvariante variante, int? zfw) {
  if (variante == Schutzvariante.persoenlich &&
      zfw != null &&
      zfw < kPersoenlicherSchildMindestZfw) {
    return 'Der persönliche Schild verlangt ZfW $kPersoenlicherSchildMindestZfw; '
        'angegeben ist ZfW $zfw.';
  }
  return null;
}

/// Verbleibender Schutzvorrat der Instanz; nie negativ.
int schutzRestVon(SpellEffectInstance instanz) =>
    math.max(0, instanz.schutzRest ?? instanz.amount);

/// Ob das Profil des Schutzzaubers automatisierbar ist (belegt oder Bestand).
bool _schutzProfilAutomatisiert(RulesCatalog? katalog, String zauberId) {
  if (katalog == null) {
    return false;
  }
  return profileFuerZauber(katalog, zauberId).any(istAutomatisiert);
}

/// Schutzschilde, die jetzt einen Treffer aufnehmen können: automatisierbares
/// Profil, nicht unterdrückt, Restvorrat über 0.
List<SpellEffectInstance> wirksameSchutzschilde(
  HeroState zustand,
  RulesCatalog? katalog,
) {
  return List<SpellEffectInstance>.unmodifiable([
    for (final instanz in zustand.activeSpellEffects.instanzen)
      if (kSchutzZauberIds.contains(instanz.effectId) &&
          !instanz.unterdrueckt &&
          schutzRestVon(instanz) > 0 &&
          _schutzProfilAutomatisiert(katalog, instanz.effectId))
        instanz,
  ]);
}

/// Warum ein Auffangvorgang nichts verändert hat.
enum SchutzAuffangStatus {
  /// Der Schild hat aufgefangen (auch 0 TP bei leerem Vorrat).
  aufgefangen,

  /// Die Instanz ist nicht (mehr) gespeichert.
  nichtGefunden,

  /// Die Instanz ist kein Schutzvorrat oder unterdrückt.
  unwirksam,

  /// Der gespeicherte Restvorrat weicht vom erwarteten ab – etwa weil derselbe
  /// Vorgang schon gebucht wurde. Nichts wurde verändert.
  restAbweichend,
}

/// Ergebnis von [fangeMagischenSchadenAuf].
class SchutzAuffangErgebnis {
  /// Erstellt das Ergebnis.
  const SchutzAuffangErgebnis({
    required this.status,
    required this.zustand,
    required this.eingehend,
    required this.aufgefangen,
    required this.durchschlag,
    required this.restVorher,
    required this.restNachher,
  });

  /// Ausgang des Vorgangs.
  final SchutzAuffangStatus status;

  /// Zustand nach dem Vorgang; unverändert, wenn [status] nicht
  /// [SchutzAuffangStatus.aufgefangen] ist.
  final HeroState zustand;

  /// Eingehende TP des Angriffs.
  final int eingehend;

  /// Vom Schild aufgenommene TP.
  final int aufgefangen;

  /// TP, die der Schild nicht mehr aufnimmt.
  final int durchschlag;

  /// Restvorrat vor dem Vorgang.
  final int restVorher;

  /// Restvorrat danach.
  final int restNachher;

  /// Ob der Vorrat durch diesen Vorgang aufgezehrt wurde.
  bool get aufgezehrt => restNachher <= 0 && restVorher > 0;
}

/// Lässt den Schild [instanzId] einen direkten magischen Treffer von
/// [eingehend] TP auffangen.
///
/// Der Schild nimmt höchstens seinen Restvorrat auf; der Rest schlägt durch.
/// [erwarteterRest] ist der Restvorrat, den der Nutzer beim Bestätigen sah:
/// weicht der gespeicherte ab, ändert sich nichts. So bucht eine Wiederholung
/// desselben Vorgangs (Doppelklick, Retry) nie zweimal. Ein aufgezehrter
/// Schild bleibt mit Restvorrat 0 gespeichert; beendet wird er am Tisch.
SchutzAuffangErgebnis fangeMagischenSchadenAuf(
  HeroState zustand, {
  required String instanzId,
  required int eingehend,
  required int erwarteterRest,
}) {
  final tp = math.max(0, eingehend);
  SchutzAuffangErgebnis unveraendert(SchutzAuffangStatus status, int rest) =>
      SchutzAuffangErgebnis(
        status: status,
        zustand: zustand,
        eingehend: tp,
        aufgefangen: 0,
        durchschlag: tp,
        restVorher: rest,
        restNachher: rest,
      );

  final instanz = zustand.activeSpellEffects.instanzFor(instanzId);
  if (instanz == null) {
    return unveraendert(SchutzAuffangStatus.nichtGefunden, 0);
  }
  final rest = schutzRestVon(instanz);
  if (!kSchutzZauberIds.contains(instanz.effectId) || instanz.unterdrueckt) {
    return unveraendert(SchutzAuffangStatus.unwirksam, rest);
  }
  if (rest != erwarteterRest) {
    return unveraendert(SchutzAuffangStatus.restAbweichend, rest);
  }
  final aufgefangen = math.min(tp, rest);
  final danach = rest - aufgefangen;
  return SchutzAuffangErgebnis(
    status: SchutzAuffangStatus.aufgefangen,
    zustand: bearbeiteEffektInstanz(
      zustand,
      instanzId,
      (aktuell) => aktuell.copyWith(schutzRest: danach),
    ),
    eingehend: tp,
    aufgefangen: aufgefangen,
    durchschlag: tp - aufgefangen,
    restVorher: rest,
    restNachher: danach,
  );
}

/// Setzt den Restvorrat des Schilds [instanzId] auf [rest] (Korrektur, etwa
/// nach dem Verlust von AsP durch einen Schadenszauber ohne direkte TP).
///
/// Der Wert wird auf 0 bis zur Anfangskapazität begrenzt; ein Schild wird
/// durch eine Korrektur nie über seine Kapazität hinaus gefüllt.
HeroState setzeSchutzRest(HeroState zustand, String instanzId, int rest) {
  return bearbeiteEffektInstanz(zustand, instanzId, (aktuell) {
    if (!kSchutzZauberIds.contains(aktuell.effectId)) {
      return aktuell;
    }
    return aktuell.copyWith(
      schutzRest: rest.clamp(0, math.max(0, aktuell.amount)),
    );
  });
}

/// Kurzbeschreibung des Vorrats für die Anzeige, etwa „Schutz 8 / 14 TP“.
String beschreibeSchutzVorrat(SpellEffectInstance instanz) {
  final rest = schutzRestVon(instanz);
  if (rest <= 0) {
    return 'Schutz aufgezehrt (0 / ${instanz.amount} TP)';
  }
  return 'Schutz $rest / ${instanz.amount} TP';
}
