import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/alchimikum_bezug.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_state_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';

// Elixiere der Tugenden (TRANK, Teilstand 2).
//
// Ein Elixier verändert Eigenschaften auf Zeit. Es läuft als gewöhnliche
// Wirkungsquelle (`SpellEffectInstance`, `effectId` = Katalog-ID des Mittels)
// im Effektdialog, mit eigenem Ende und eigener Dauer je Eigenschaftsänderung.
// Die Instanzen rechnen über `effektiveTempAttributeMods`
// (`spell_effect_instance_rules.dart`), nie darüber hinaus. Gerechnet wird nur,
// was der Katalog ausdrücklich mit Eigenschaft, Zahl und Dauer nennt;
// Nachwirkungen nach Ablauf, Gruppen („alle geistigen Eigenschaften“) und
// AuP-Wirkungen bleiben Text der Qualitätsstufe. Beleg: Wege der Alchimie
// (2. Auflage 2012), Kapitel „Die Elixiere der Tugenden“.

/// Titel des Protokolleintrags.
const String elixierProtokollTitel = 'Elixier eingenommen';

/// Das Katalogmittel hinter [bezug] oder `null` (ohne Katalog, ohne Verweis
/// oder bei unbekannter ID).
AlchimikumDef? alchimikumZuBezug(
  RulesCatalog? katalog,
  AlchimikumBezug? bezug,
) {
  if (katalog == null || bezug == null) {
    return null;
  }
  for (final mittel in katalog.alchimika) {
    if (mittel.id == bezug.id) {
      return mittel;
    }
  }
  return null;
}

/// Die Eigenschaftsänderungen, die [eintrag] laut Katalog beim Einnehmen
/// auslöst; leer ohne Verweis, ohne Katalog oder ohne solche Wirkung.
List<AlchimikumEigenschaft> elixierEigenschaften(
  RulesCatalog? katalog,
  HeroInventoryEntry eintrag,
) {
  final bezug = eintrag.alchimikum;
  final mittel = alchimikumZuBezug(katalog, bezug);
  if (mittel == null || bezug == null) {
    return const <AlchimikumEigenschaft>[];
  }
  return alchimikumStufe(mittel, bezug.stufe)?.eigenschaften ??
      const <AlchimikumEigenschaft>[];
}

/// Ob [eintrag] „Einnehmen“ anbietet: Der Katalog nennt für sein Mittel und
/// seine Stufe Eigenschaftsänderungen.
bool hatElixierWirkung(RulesCatalog? katalog, HeroInventoryEntry eintrag) =>
    elixierEigenschaften(katalog, eintrag).isNotEmpty;

/// Eigenschaftsänderung [wert] für das Kürzel [kuerzel] (`MU` … `KK`);
/// `null` bei unbekanntem Kürzel (dann wird nichts geraten).
AttributeModifiers? eigenschaftsAenderung(String kuerzel, int wert) {
  switch (kuerzel) {
    case 'MU':
      return AttributeModifiers(mu: wert);
    case 'KL':
      return AttributeModifiers(kl: wert);
    case 'IN':
      return AttributeModifiers(inn: wert);
    case 'CH':
      return AttributeModifiers(ch: wert);
    case 'FF':
      return AttributeModifiers(ff: wert);
    case 'GE':
      return AttributeModifiers(ge: wert);
    case 'KO':
      return AttributeModifiers(ko: wert);
    case 'KK':
      return AttributeModifiers(kk: wert);
  }
  return null;
}

/// Zeiteinheit zum Katalogwert; `null` bei unbekanntem Namen.
SpellDurationUnit? _einheit(String name) {
  for (final einheit in SpellDurationUnit.values) {
    if (einheit.name == name) {
      return einheit;
    }
  }
  return null;
}

/// Kurztext einer Eigenschaftsänderung für Dialog und Protokoll, z. B.
/// `MU +3 · 3 Spielrunden`.
String beschreibeElixierEigenschaft(AlchimikumEigenschaft e) {
  final vorzeichen = e.wert >= 0 ? '+' : '−';
  final einheit = switch (e.einheit) {
    'spielrunden' => e.dauer == 1 ? 'Spielrunde' : 'Spielrunden',
    'stunden' => e.dauer == 1 ? 'Stunde' : 'Stunden',
    'tage' => e.dauer == 1 ? 'Tag' : 'Tage',
    'kampfrunden' => e.dauer == 1 ? 'Kampfrunde' : 'Kampfrunden',
    'minuten' => e.dauer == 1 ? 'Minute' : 'Minuten',
    _ => e.einheit,
  };
  return '${e.eigenschaft} $vorzeichen${e.wert.abs()} · ${e.dauer} $einheit';
}

/// Die Wirkungsquellen eines eingenommenen Elixiers: je Eigenschaftsänderung
/// eine Instanz mit eigener Dauer.
///
/// Jede Instanz trägt eine eigene Vorgangs-ID (`<vorgangsId>#<Nummer>`), damit
/// eine Wiederholung keine zweite Wirkung anlegt. [neueId] liefert die
/// Instanz-IDs. Unbekannte Eigenschaftskürzel werden übersprungen.
List<SpellEffectInstance> elixierInstanzen({
  required AlchimikumDef mittel,
  required String stufe,
  required String vorgangsId,
  required String Function() neueId,
}) {
  final wirkung = alchimikumStufe(mittel, stufe);
  if (wirkung == null) {
    return const <SpellEffectInstance>[];
  }
  final instanzen = <SpellEffectInstance>[];
  for (var i = 0; i < wirkung.eigenschaften.length; i++) {
    final e = wirkung.eigenschaften[i];
    final aenderung = eigenschaftsAenderung(e.eigenschaft, e.wert);
    if (aenderung == null) {
      continue;
    }
    final einheit = _einheit(e.einheit);
    instanzen.add(
      SpellEffectInstance(
        id: neueId(),
        effectId: mittel.id,
        vorgangsId: '$vorgangsId#$i',
        quelle: 'Qualität $stufe',
        attributeMods: aenderung,
        duration: einheit == null || e.dauer <= 0
            ? null
            : SpellDuration(amount: e.dauer, unit: einheit),
      ),
    );
  }
  return List<SpellEffectInstance>.unmodifiable(instanzen);
}

/// Ob zu [vorgangsId] bereits Wirkungsquellen gespeichert sind (Wiederholung).
bool elixierBereitsEingenommen(HeroState zustand, String vorgangsId) {
  return zustand.activeSpellEffects.instanzen.any(
    (i) => i.vorgangsId?.startsWith('$vorgangsId#') ?? false,
  );
}

/// Legt die Wirkungsquellen von [instanzen] an.
///
/// Idempotent über die Vorgangs-IDs der Instanzen (`aktiviereEffektInstanz`).
HeroState nimmElixierEin(
  HeroState zustand,
  List<SpellEffectInstance> instanzen,
) {
  var ergebnis = zustand;
  for (final instanz in instanzen) {
    ergebnis = aktiviereEffektInstanz(ergebnis, instanz);
  }
  return ergebnis;
}

/// Protokolleintrag des Einnehmens; nennt Mittel, Stufe und die berechneten
/// Eigenschaftsänderungen.
DiceLogEntry baueElixierProtokoll({
  required AlchimikumDef mittel,
  required String stufe,
  required List<AlchimikumEigenschaft> eigenschaften,
  required DateTime zeitpunkt,
}) {
  return diceLogEntryFromRoll(
    title: elixierProtokollTitel,
    subtitle: [
      '${mittel.name} (Qualität $stufe)',
      for (final e in eigenschaften) beschreibeElixierEigenschaft(e),
    ].join(' · '),
    diceValues: const <int>[],
    total: 0,
    timestamp: zeitpunkt,
  );
}
