import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';

// Quellenbezogene Zaubereffekt-Instanzen (MAG-EFF-02).
//
// Blattartig: importiert nur Domäne und die Effekt-IDs, damit Kampf-, Basis-
// und Probenregeln es ohne Zyklus nutzen dürfen. Schreibende Aktionen stehen
// in `active_spell_state_rules.dart`.

/// Präfix der synthetischen ID, unter der eine Legacy-Effekt-ID als Instanz
/// erscheint. Solche Instanzen werden nie gespeichert.
const String legacyInstanzPraefix = 'legacy:';

/// `true`, wenn [instanzId] eine synthetische Legacy-Instanz bezeichnet.
bool istLegacyInstanz(String instanzId) =>
    instanzId.startsWith(legacyInstanzPraefix);

/// Alle laufenden Wirkungen: Legacy-IDs als synthetische Instanzen, dann die
/// gespeicherten Instanzen.
///
/// Legacy-Instanzen tragen **keine** `attributeMods`: Die Boni des alten
/// Attributo liegen in `HeroState.tempAttributeMods`, die Summe in
/// [effektiveTempAttributeMods] zählt sie dort bereits.
List<SpellEffectInstance> aktiveEffektInstanzen(HeroState zustand) {
  final effekte = zustand.activeSpellEffects;
  return List<SpellEffectInstance>.unmodifiable(<SpellEffectInstance>[
    for (final id in effekte.activeEffectIds)
      SpellEffectInstance(
        id: '$legacyInstanzPraefix$id',
        effectId: id,
        amount: effekte.detailFor(id).amount,
        duration: effekte.detailFor(id).duration,
      ),
    ...effekte.instanzen,
  ]);
}

/// Kürzel der acht Eigenschaften in der Reihenfolge von [AttributeModifiers].
const List<String> _eigenschaftsKuerzel = <String>[
  'MU',
  'KL',
  'IN',
  'CH',
  'FF',
  'GE',
  'KO',
  'KK',
];

List<int> _werte(AttributeModifiers m) => <int>[
  m.mu,
  m.kl,
  m.inn,
  m.ch,
  m.ff,
  m.ge,
  m.ko,
  m.kk,
];

AttributeModifiers _ausWerten(List<int> w) => AttributeModifiers(
  mu: w[0],
  kl: w[1],
  inn: w[2],
  ch: w[3],
  ff: w[4],
  ge: w[5],
  ko: w[6],
  kk: w[7],
);

/// Eigenschaftsboni der laufenden Attributo-Quellen in fester Reihenfolge:
/// zuerst das Legacy-Attributo (seine Boni liegen in `tempAttributeMods`),
/// dann die nicht unterdrückten Instanzen.
///
/// Als `(instanzId, Boni)`; die Legacy-Quelle trägt die synthetische ID
/// `legacy:effect_spell_attributo`.
List<(String, AttributeModifiers)> _attributoQuellen(HeroState zustand) {
  final effekte = zustand.activeSpellEffects;
  return <(String, AttributeModifiers)>[
    if (effekte.isActive(activeSpellEffectAttributo))
      (
        '$legacyInstanzPraefix$activeSpellEffectAttributo',
        zustand.tempAttributeMods,
      ),
    for (final instanz in effekte.instanzen)
      if (instanz.effectId == activeSpellEffectAttributo &&
          !instanz.unterdrueckt)
        (instanz.id, instanz.attributeMods),
  ];
}

/// Pro Eigenschaft der Index der wirksamen Quelle in [quellen] oder `-1`.
///
/// Tischregel: Verbessern mehrere Attributo dieselbe Eigenschaft, zählt nur
/// der **bessere** Wert; bei Gleichstand die erste Quelle. Wer verschiedene
/// Eigenschaften verbessert, behält alle Boni. Dieselbe Regel soll für
/// weitere Zauber mit Einfluss auf Eigenschaften gelten.
List<int> _wirksameQuelle(List<(String, AttributeModifiers)> quellen) {
  final alle = [for (final q in quellen) _werte(q.$2)];
  return <int>[
    for (var e = 0; e < _eigenschaftsKuerzel.length; e++)
      () {
        var bester = -1;
        for (var q = 0; q < alle.length; q++) {
          final wert = alle[q][e];
          if (wert != 0 && (bester < 0 || wert > alle[bester][e])) {
            bester = q;
          }
        }
        return bester;
      }(),
  ];
}

/// Eigenschaftsboni, die für Rechnungen gelten.
///
/// Boni mehrerer Attributo-Quellen (Legacy-Attributo und Instanzen) werden
/// **je Eigenschaft nicht addiert, sondern es zählt der beste Wert**. Ist das
/// Legacy-Attributo aus, sind `tempAttributeMods` manuelle Boni (Meisterentscheid,
/// andere Zauber) und kommen darauf; ist es an, nehmen sie als eine Quelle am
/// Vergleich teil.
///
/// Die einzige Stelle, an der Zauberquellen Eigenschaften verändern; Regeln
/// und Widgets lesen nie `tempAttributeMods` allein. Ohne Instanzen kommt der
/// gespeicherte Wert unverändert zurück.
AttributeModifiers effektiveTempAttributeMods(HeroState zustand) {
  if (zustand.activeSpellEffects.instanzen.isEmpty) {
    return zustand.tempAttributeMods;
  }
  final quellen = _attributoQuellen(zustand);
  final wirksam = _wirksameQuelle(quellen);
  final legacyAktiv = zustand.activeSpellEffects.isActive(
    activeSpellEffectAttributo,
  );
  final manuell = legacyAktiv
      ? List<int>.filled(_eigenschaftsKuerzel.length, 0)
      : _werte(zustand.tempAttributeMods);
  final summe = <int>[
    for (var e = 0; e < _eigenschaftsKuerzel.length; e++)
      manuell[e] + (wirksam[e] < 0 ? 0 : _werte(quellen[wirksam[e]].$2)[e]),
  ];
  return _ausWerten(summe);
}

/// Kürzel der Eigenschaften, die die Quelle [instanzId] verbessert, die aber
/// von einer besseren (oder gleich guten, früheren) Attributo-Quelle
/// überlagert werden und deshalb nicht zählen.
List<String> ueberlagerteEigenschaften(HeroState zustand, String instanzId) {
  final quellen = _attributoQuellen(zustand);
  final index = quellen.indexWhere((q) => q.$1 == instanzId);
  if (index < 0) {
    return const <String>[];
  }
  final wirksam = _wirksameQuelle(quellen);
  final eigene = _werte(quellen[index].$2);
  return <String>[
    for (var e = 0; e < _eigenschaftsKuerzel.length; e++)
      if (eigene[e] != 0 && wirksam[e] != index) _eigenschaftsKuerzel[e],
  ];
}

/// Kurzbeschreibung der Eingaben einer Instanz für die Anzeige: Attributo
/// nennt seine Boni, andere Zauber ZfP* und ZfW des Zaubernden.
String beschreibeEffektInstanz(SpellEffectInstance instanz) {
  if (instanz.effectId == activeSpellEffectAttributo) {
    final boni = beschreibeAttributoInstanz(instanz);
    return boni.isEmpty ? '' : 'Boni: $boni';
  }
  return [
    if (instanz.zfpStern != null) 'ZfP* ${instanz.zfpStern}',
    if (instanz.zfw != null) 'ZfW ${instanz.zfw}',
  ].join(', ');
}

/// Anzeigename des Zaubers hinter [effectId]: die Bezeichnung des
/// Bestandseffekts, sonst der Katalogname, sonst die ID selbst.
String effektName(String effectId, RulesCatalog? katalog) {
  final bestand = importantActiveSpellEffectById(effectId);
  if (bestand != null) {
    return bestand.label;
  }
  for (final zauber in katalog?.spells ?? const <SpellDef>[]) {
    if (zauber.id == effectId) {
      return zauber.name;
    }
  }
  return effectId;
}

/// Boni einer Instanz als Text (`MU+2 KL+1`), leer ohne Werte.
String beschreibeAttributoInstanz(SpellEffectInstance instanz) =>
    describeAttributeModifiers(instanz.attributeMods);

/// Ob die Wirkungsdauer eines Zaubers laut Katalog „(A)“ trägt, der Zauber
/// also aufrechterhalten werden muss (Konzentration).
bool dauerVerlangtAufrechterhaltung(String wirkungsdauer) =>
    wirkungsdauer.contains('(A)');

/// Zauber-ID zu einer Effekt-ID: über das Profil (`legacyEffektId`), sonst
/// ist die Effekt-ID selbst die Zauber-ID.
String? _zauberIdFuerEffekt(String effectId, RulesCatalog catalog) {
  for (final profil in catalog.spellEffects) {
    if (profil.legacyEffektId == effectId) {
      return profil.spellId;
    }
  }
  return effectId;
}

/// Ob der Zauber hinter [effectId] laut Katalog aufrechterhalten werden muss.
/// Ohne Katalog oder bei unbekanntem Zauber: `false` (nichts geraten).
bool effektVerlangtAufrechterhaltung(String effectId, RulesCatalog? catalog) {
  if (catalog == null) {
    return false;
  }
  final zauberId = _zauberIdFuerEffekt(effectId, catalog);
  for (final zauber in catalog.spells) {
    if (zauber.id == zauberId) {
      return dauerVerlangtAufrechterhaltung(zauber.duration);
    }
  }
  return false;
}

/// Laufende Wirkungen, die aufrechterhalten werden müssen.
class AufrechterhaltungsBefund {
  /// Erstellt den Befund.
  const AufrechterhaltungsBefund(this.namen);

  /// Effekt-IDs je laufender, nicht unterdrückter Wirkung (eine pro Quelle).
  final List<String> namen;

  /// Zahl der aufrechtzuerhaltenden Wirkungen.
  int get anzahl => namen.length;
}

/// Zählt laufende, nicht unterdrückte Wirkungen (Legacy-IDs und Instanzen),
/// deren Zauber laut Katalog „(A)“ trägt. Jede Quelle zählt einzeln: zwei
/// Armatrutz sind zwei aufrechtzuerhaltende Zauber.
///
/// Nur ein **Vorschlag** für die bestätigte Anzahl im Wirkdialog; der Nutzer
/// entscheidet am Tisch.
AufrechterhaltungsBefund aufrechterhaltungsBefund(
  HeroState zustand,
  RulesCatalog? catalog,
) {
  return AufrechterhaltungsBefund(<String>[
    for (final instanz in aktiveEffektInstanzen(zustand))
      if (!instanz.unterdrueckt &&
          effektVerlangtAufrechterhaltung(instanz.effectId, catalog))
        instanz.effectId,
  ]);
}
