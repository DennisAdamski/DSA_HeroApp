import 'package:dsa_heldenverwaltung/catalog/catalog_json_helpers.dart';

/// Pruefstand eines Zauberprofils (MAG-EFF).
///
/// Der Status sagt nur, *wie gut belegt* ein Profil ist, nicht, was es
/// bewirkt. Zahlen rechnet ausschliesslich das jeweilige Regelmodul unter
/// `lib/rules/derived/`.
enum SpellEffectStatus {
  /// Wirkung ist in der App bereits umgesetzt (Axxeleratus, Attributo,
  /// Armatrutz, Fulminictus). Das Profil beschreibt den Bestand, aendert ihn
  /// aber nicht.
  bestand,

  /// Wirkungsmechanik ist gegen das Regelwerk belegt, aber noch nicht
  /// umgesetzt. Erst ein Folgepaket darf daraus Zahlen ableiten.
  belegt,

  /// Bewusst nur Hinweis oder Meisterentscheid; nie Zahlenautomatik.
  manuell,

  /// Von dieser Version nicht verstandener Status; wirkt nicht.
  unbekannt,
}

/// Quellenangabe eines Zauberprofils.
class SpellEffectBeleg {
  /// Erstellt eine Quellenangabe.
  const SpellEffectBeleg({this.buch = '', this.seite = '', this.chunkId = 0});

  /// Regelwerk, z. B. `Liber Cantiones`.
  final String buch;

  /// Gedruckte Buchseite (nicht die PDF-Seite), z. B. `84`.
  final String seite;

  /// Chunk-ID im dsa-rules-Index zum Nachlesen; 0 = nicht angegeben.
  final int chunkId;

  /// Ob Buch und Seite benannt sind.
  bool get istBenannt => buch.trim().isNotEmpty && seite.trim().isNotEmpty;

  /// Liest eine Quellenangabe tolerant aus dem Katalog-JSON.
  factory SpellEffectBeleg.fromJson(Map<String, dynamic> json) {
    return SpellEffectBeleg(
      buch: readCatalogString(json, 'buch', fallback: ''),
      seite: readCatalogString(json, 'seite', fallback: ''),
      chunkId: readCatalogInt(json, 'chunkId', fallback: 0),
    );
  }

  /// Schreibt die Quellenangabe ohne leere Felder zurueck.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (buch.isNotEmpty) 'buch': buch,
      if (seite.isNotEmpty) 'seite': seite,
      if (chunkId != 0) 'chunkId': chunkId,
    };
  }
}

/// Profil der Charakterwirkung eines Zaubers (MAG-EFF-01).
///
/// Ein Profil verknuepft eine Zauber-ID des Katalogs mit Pruefstand, Quelle
/// und den Eingaben, die eine spaetere Regelrechnung braucht. Es enthaelt
/// **keine Formeln und keine Zahlenbeitraege**: ohne ausdruecklich belegtes
/// Profil darf nichts aus Namen oder Freitext geraten werden. Wirkungs- und
/// Variantentexte bleiben in `magie.json` (dort verschluesselt).
class SpellEffectProfile {
  /// Erstellt ein Zauberprofil.
  const SpellEffectProfile({
    required this.id,
    required this.spellId,
    this.profilVersion = 1,
    this.status = SpellEffectStatus.unbekannt,
    this.rohStatus = '',
    this.legacyEffektId = '',
    this.beleg = const SpellEffectBeleg(),
    this.eingaben = const <String>[],
    this.variantenHinweis = '',
    this.rundungsHinweis = '',
    this.hinweis = '',
  });

  /// Stabile Profil-ID, z. B. `profil_falkenauge_grund`.
  final String id;

  /// ID des Zaubers in `magie.json`.
  final String spellId;

  /// Version des Profils; steigt, wenn sich die belegte Wirkung aendert.
  final int profilVersion;

  /// Pruefstand des Profils.
  final SpellEffectStatus status;

  /// Gespeicherter Status, auch wenn er unbekannt ist (fuer `toJson`).
  final String rohStatus;

  /// Bisherige ID des Bestandseffekts in `ActiveSpellEffectsState`
  /// (`effect_spell_*`); leer bei Profilen ohne Bestandsumsetzung.
  final String legacyEffektId;

  /// Quelle der belegten Wirkung.
  final SpellEffectBeleg beleg;

  /// Namen der Eingaben, die die Rechnung braucht (`zfpStern`, `zfw`, ...).
  final List<String> eingaben;

  /// Welche Varianten dieses Profil ausdruecklich nicht abdeckt.
  final String variantenHinweis;

  /// Offene oder bewusst nicht festgelegte Rundung.
  final String rundungsHinweis;

  /// Sonstiger Hinweis fuer Menschen, ohne Regelwirkung.
  final String hinweis;

  /// Liest ein Profil tolerant aus dem Katalog-JSON.
  factory SpellEffectProfile.fromJson(Map<String, dynamic> json) {
    final rohStatus = readCatalogString(json, 'status', fallback: '');
    final status = SpellEffectStatus.values.firstWhere(
      (value) =>
          value.name == rohStatus && value != SpellEffectStatus.unbekannt,
      orElse: () => SpellEffectStatus.unbekannt,
    );
    final belegJson = readCatalogObject(json, 'beleg');
    return SpellEffectProfile(
      id: readCatalogString(json, 'id', fallback: ''),
      spellId: readCatalogString(json, 'spellId', fallback: ''),
      profilVersion: readCatalogInt(json, 'profilVersion', fallback: 1),
      status: status,
      rohStatus: rohStatus,
      legacyEffektId: readCatalogString(json, 'legacyEffektId', fallback: ''),
      beleg: belegJson == null
          ? const SpellEffectBeleg()
          : SpellEffectBeleg.fromJson(belegJson),
      eingaben: readCatalogStringList(json, 'eingaben'),
      variantenHinweis: readCatalogString(
        json,
        'variantenHinweis',
        fallback: '',
      ),
      rundungsHinweis: readCatalogString(json, 'rundungsHinweis', fallback: ''),
      hinweis: readCatalogString(json, 'hinweis', fallback: ''),
    );
  }

  /// Schreibt das Profil zurueck; unbekannte Status behalten ihren Rohwert.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'spellId': spellId,
      'profilVersion': profilVersion,
      'status': status == SpellEffectStatus.unbekannt ? rohStatus : status.name,
      if (legacyEffektId.isNotEmpty) 'legacyEffektId': legacyEffektId,
      'beleg': beleg.toJson(),
      if (eingaben.isNotEmpty) 'eingaben': eingaben,
      if (variantenHinweis.isNotEmpty) 'variantenHinweis': variantenHinweis,
      if (rundungsHinweis.isNotEmpty) 'rundungsHinweis': rundungsHinweis,
      if (hinweis.isNotEmpty) 'hinweis': hinweis,
    };
  }
}
