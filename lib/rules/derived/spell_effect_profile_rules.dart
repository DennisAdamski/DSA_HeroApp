import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';

/// Art eines Befunds bei der Prüfung der Zauberprofile (MAG-EFF-01).
enum SpellEffectBefundArt {
  /// Die Profil-ID fehlt.
  profilIdFehlt,

  /// Dieselbe Profil-ID kommt mehrfach vor.
  profilIdDoppelt,

  /// Die Zauber-ID existiert nicht im Katalog.
  zauberUnbekannt,

  /// Die Profilversion ist kleiner als 1.
  versionUngueltig,

  /// Der Status wird von dieser Version nicht verstanden.
  statusUnbekannt,

  /// Buch oder Seite der Quelle fehlen.
  quelleFehlt,

  /// Ein Bestandsprofil nennt keine Bestandsumsetzung.
  bestandOhneUmsetzung,

  /// Die genannte Legacy-Effekt-ID kennt die App nicht.
  legacyEffektUnbekannt,

  /// Ein Profil ohne Bestandsstatus nennt eine Legacy-Effekt-ID.
  legacyEffektOhneBestand,
}

/// Ein einzelner Befund der Profilprüfung.
class SpellEffectBefund {
  /// Erstellt einen Befund zu [profilId].
  const SpellEffectBefund({
    required this.art,
    required this.profilId,
    required this.nachricht,
  });

  /// Art des Befunds.
  final SpellEffectBefundArt art;

  /// Betroffenes Profil; leer, wenn schon die ID fehlt.
  final String profilId;

  /// Menschenlesbare Beschreibung.
  final String nachricht;

  @override
  String toString() => '${art.name} [$profilId]: $nachricht';
}

/// Zauber-ID des Fulminictus, dessen Grundwirkung als Fremdschaden besteht.
///
/// Bestandsprofil ohne Legacy-Effekt-ID, weil Fulminictus kein Dauereffekt am
/// Helden ist (`gefecht_fremdwirkung_rules.dart`).
const String kFulminictusZauberId = 'spell_fulminictus_donnerkeil';

/// Legacy-Effekt-IDs, die ein Bestandsprofil nennen darf.
const Set<String> kBekannteLegacyEffektIds = <String>{
  activeSpellEffectAxxeleratus,
  activeSpellEffectAttributo,
  activeSpellEffectArmatrutz,
};

/// Prüft alle Zauberprofile eines Katalogs und liefert die gefundenen Mängel.
///
/// Eine leere Liste heißt: Verweise lösen auf, Quellen und Versionen sind
/// gesetzt, Bestandsprofile benennen ihre Umsetzung. Die Funktion ändert
/// nichts und rechnet keine Wirkung; sie schützt davor, dass ein Profil auf
/// einen nicht existierenden Zauber zeigt oder unbelegt als belegt gilt.
List<SpellEffectBefund> validiereSpellEffectProfile(RulesCatalog katalog) {
  final befunde = <SpellEffectBefund>[];
  final zauberIds = <String>{for (final spell in katalog.spells) spell.id};
  final gesehen = <String>{};

  for (final profil in katalog.spellEffects) {
    void melde(SpellEffectBefundArt art, String nachricht) {
      befunde.add(
        SpellEffectBefund(art: art, profilId: profil.id, nachricht: nachricht),
      );
    }

    if (profil.id.trim().isEmpty) {
      melde(SpellEffectBefundArt.profilIdFehlt, 'Profil ohne ID.');
    } else if (!gesehen.add(profil.id)) {
      melde(SpellEffectBefundArt.profilIdDoppelt, 'Profil-ID mehrfach.');
    }
    if (!zauberIds.contains(profil.spellId)) {
      melde(
        SpellEffectBefundArt.zauberUnbekannt,
        'Zauber "${profil.spellId}" fehlt im Katalog.',
      );
    }
    if (profil.profilVersion < 1) {
      melde(SpellEffectBefundArt.versionUngueltig, 'Profilversion unter 1.');
    }
    if (profil.status == SpellEffectStatus.unbekannt) {
      melde(
        SpellEffectBefundArt.statusUnbekannt,
        'Status "${profil.rohStatus}" ist unbekannt.',
      );
    }
    if (!profil.beleg.istBenannt) {
      melde(SpellEffectBefundArt.quelleFehlt, 'Buch oder Seite fehlen.');
    }
    _pruefeBestandsbezug(profil, melde);
  }
  return List<SpellEffectBefund>.unmodifiable(befunde);
}

/// Prüft die Verbindung zwischen Bestandsstatus und Legacy-Effekt-ID.
void _pruefeBestandsbezug(
  SpellEffectProfile profil,
  void Function(SpellEffectBefundArt art, String nachricht) melde,
) {
  final legacyId = profil.legacyEffektId;
  final istBestand = profil.status == SpellEffectStatus.bestand;
  if (legacyId.isNotEmpty && !kBekannteLegacyEffektIds.contains(legacyId)) {
    melde(
      SpellEffectBefundArt.legacyEffektUnbekannt,
      'Effekt "$legacyId" kennt die App nicht.',
    );
  }
  if (legacyId.isNotEmpty && !istBestand) {
    melde(
      SpellEffectBefundArt.legacyEffektOhneBestand,
      'Legacy-Effekt nur bei Status "bestand" erlaubt.',
    );
  }
  final umgesetzt =
      legacyId.isNotEmpty || profil.spellId == kFulminictusZauberId;
  if (istBestand && !umgesetzt) {
    melde(
      SpellEffectBefundArt.bestandOhneUmsetzung,
      'Bestandsprofil ohne Legacy-Effekt oder bekannte Fremdwirkung.',
    );
  }
}

/// Ob aus dem Profil überhaupt Zahlen abgeleitet werden dürfen.
///
/// Nur belegte und bereits umgesetzte Profile gelten als automatisierbar;
/// manuelle und unbekannte Profile liefern nie einen Zahlenbonus. Das ist
/// die Bremse gegen geratene Wirkungen aus Name oder Freitext.
bool istAutomatisiert(SpellEffectProfile profil) {
  return profil.status == SpellEffectStatus.bestand ||
      profil.status == SpellEffectStatus.belegt;
}

/// Liefert alle Profile eines Zaubers (leer, wenn keines hinterlegt ist).
List<SpellEffectProfile> profileFuerZauber(
  RulesCatalog katalog,
  String spellId,
) {
  return <SpellEffectProfile>[
    for (final profil in katalog.spellEffects)
      if (profil.spellId == spellId) profil,
  ];
}

/// Liefert das Bestandsprofil zu einer Legacy-Effekt-ID oder `null`.
SpellEffectProfile? profilFuerLegacyEffekt(
  RulesCatalog katalog,
  String legacyEffektId,
) {
  if (legacyEffektId.isEmpty) return null;
  for (final profil in katalog.spellEffects) {
    if (profil.legacyEffektId == legacyEffektId) return profil;
  }
  return null;
}
