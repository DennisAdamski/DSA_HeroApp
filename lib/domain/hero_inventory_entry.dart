import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Wer oder was ein Inventarstück trägt.
enum InventoryTraeger {
  /// Wird vom Helden selbst getragen (Standard).
  held,

  /// Wird von einem Begleiter getragen.
  begleiter,
}

/// Persistierter Inventar-Eintrag eines Helden.
///
/// Bewahrt Legacy-Stringfelder für Abwärtskompatibilität und ergänzt sie um
/// typisierte Metadaten für Quelle, Träger und besondere Eigenschaften.
class HeroInventoryEntry {
  /// Erstellt einen serialisierbaren Inventar-Eintrag.
  const HeroInventoryEntry({
    this.gegenstand = '',
    this.woGetragen = '',
    this.typ = '',
    this.welchesAbenteuer = '',
    this.gewicht = '',
    this.wert = '',
    this.artefakt = '',
    this.anzahl = '',
    this.amKoerper = '',
    this.woDann = '',
    this.gruppe = '',
    this.beschreibung = '',
    // Neue typisierte Felder (v16)
    this.itemType = InventoryItemType.sonstiges,
    this.source = InventoryItemSource.manuell,
    this.sourceRef,
    this.istAusgeruestet = false,
    this.modifiers = const <InventoryItemModifier>[],
    this.gewichtGramm = 0,
    this.wertSilber = 0,
    this.herkunft = '',
    this.isMagisch = false,
    this.magischDescription = '',
    this.isGeweiht = false,
    this.geweihtDescription = '',
    // Träger-Felder (v19)
    this.traegerTyp = InventoryTraeger.held,
    this.traegerId,
  });

  // --- Bestehende 12 String-Felder (unveraendert, rueckwaertskompatibel) ---
  final String gegenstand;
  final String woGetragen;
  final String typ;
  final String welchesAbenteuer;
  final String gewicht;
  final String wert;

  /// Legacy-Freitext für frühere Artefakt-Kennzeichnung.
  final String artefakt;
  final String anzahl;
  final String amKoerper;
  final String woDann;
  final String gruppe;
  final String beschreibung;

  // --- Neue typisierte Felder (v16) ---

  /// Kategorie des Inventar-Eintrags.
  final InventoryItemType itemType;

  /// Ursprung: manuell angelegt oder automatisch aus dem Kampf-Tab synchronisiert.
  final InventoryItemSource source;

  /// Composite-Schluessel fuer die Zuordnung zu einem Kampf-Tab-Eintrag.
  ///
  /// Format:
  /// - Waffe:     `'w:{weaponName}'`
  /// - Ruestung:  `'a:{pieceName}'`
  /// - Geschoss:  `'w:{weaponName}|p:{projName}'`
  /// - Nebenhand: `'oh:{equipmentName}'`
  ///
  /// `null` bei manuell angelegten Eintraegen.
  final String? sourceRef;

  /// Ob das Item gerade getragen/ausgeruest wird.
  ///
  /// Nur relevant fuer [InventoryItemType.ausruestung]. Steuert, ob
  /// [modifiers] in die berechneten Heldenwerte einfliessen.
  final bool istAusgeruestet;

  /// Modifikatoren, die wirken, wenn [istAusgeruestet] == true.
  final List<InventoryItemModifier> modifiers;

  /// Gewicht in Gramm (0 = unbekannt).
  final int gewichtGramm;

  /// Wert in Silbertalern (0 = unbekannt).
  final int wertSilber;

  /// Herkunft / Fundort / Haendler des Items.
  final String herkunft;

  /// Kennzeichnet den Gegenstand als magisch.
  final bool isMagisch;

  /// Freitext-Beschreibung für den magischen Gegenstand.
  final String magischDescription;

  /// Kennzeichnet den Gegenstand als geweiht.
  final bool isGeweiht;

  /// Freitext-Beschreibung für den geweihten Gegenstand.
  final String geweihtDescription;

  // --- Träger-Felder (v19) ---

  /// Wer dieses Inventarstück trägt.
  final InventoryTraeger traegerTyp;

  /// ID des Begleiters, wenn [traegerTyp] == [InventoryTraeger.begleiter].
  /// Null, wenn der Held das Item trägt.
  final String? traegerId;

  /// Gibt eine Kopie mit selektiv überschriebenen Feldern zurück.
  HeroInventoryEntry copyWith({
    String? gegenstand,
    String? woGetragen,
    String? typ,
    String? welchesAbenteuer,
    String? gewicht,
    String? wert,
    String? artefakt,
    String? anzahl,
    String? amKoerper,
    String? woDann,
    String? gruppe,
    String? beschreibung,
    InventoryItemType? itemType,
    InventoryItemSource? source,
    Object? sourceRef = keepFieldValue,
    bool? istAusgeruestet,
    List<InventoryItemModifier>? modifiers,
    int? gewichtGramm,
    int? wertSilber,
    String? herkunft,
    bool? isMagisch,
    String? magischDescription,
    bool? isGeweiht,
    String? geweihtDescription,
    InventoryTraeger? traegerTyp,
    Object? traegerId = keepFieldValue,
  }) {
    return HeroInventoryEntry(
      gegenstand: gegenstand ?? this.gegenstand,
      woGetragen: woGetragen ?? this.woGetragen,
      typ: typ ?? this.typ,
      welchesAbenteuer: welchesAbenteuer ?? this.welchesAbenteuer,
      gewicht: gewicht ?? this.gewicht,
      wert: wert ?? this.wert,
      artefakt: artefakt ?? this.artefakt,
      anzahl: anzahl ?? this.anzahl,
      amKoerper: amKoerper ?? this.amKoerper,
      woDann: woDann ?? this.woDann,
      gruppe: gruppe ?? this.gruppe,
      beschreibung: beschreibung ?? this.beschreibung,
      itemType: itemType ?? this.itemType,
      source: source ?? this.source,
      sourceRef: sourceRef == keepFieldValue
          ? this.sourceRef
          : sourceRef as String?,
      istAusgeruestet: istAusgeruestet ?? this.istAusgeruestet,
      modifiers: modifiers ?? this.modifiers,
      gewichtGramm: gewichtGramm ?? this.gewichtGramm,
      wertSilber: wertSilber ?? this.wertSilber,
      herkunft: herkunft ?? this.herkunft,
      isMagisch: isMagisch ?? this.isMagisch,
      magischDescription: magischDescription ?? this.magischDescription,
      isGeweiht: isGeweiht ?? this.isGeweiht,
      geweihtDescription: geweihtDescription ?? this.geweihtDescription,
      traegerTyp: traegerTyp ?? this.traegerTyp,
      traegerId: traegerId == keepFieldValue
          ? this.traegerId
          : traegerId as String?,
    );
  }

  /// Serialisiert den Eintrag in ein JSON-kompatibles Map.
  Map<String, dynamic> toJson() {
    final normalizedMagischDescription = magischDescription.trim();
    final legacyArtifactValue = _legacyArtifactValue(
      isMagisch: isMagisch,
      magischDescription: normalizedMagischDescription,
      legacyArtifact: artefakt.trim(),
    );

    return <String, dynamic>{
      'gegenstand': gegenstand,
      'woGetragen': woGetragen,
      'typ': typ,
      'welchesAbenteuer': welchesAbenteuer,
      'gewicht': gewicht,
      'wert': wert,
      'artefakt': legacyArtifactValue,
      'anzahl': anzahl,
      'amKoerper': amKoerper,
      'woDann': woDann,
      'gruppe': gruppe,
      'beschreibung': beschreibung,
      // v16
      'itemType': itemType.name,
      'source': source.name,
      if (sourceRef != null) 'sourceRef': sourceRef,
      'istAusgeruestet': istAusgeruestet,
      'modifiers': modifiers.map((m) => m.toJson()).toList(),
      'gewichtGramm': gewichtGramm,
      'wertSilber': wertSilber,
      'herkunft': herkunft,
      'isMagisch': isMagisch,
      'magischDescription': normalizedMagischDescription,
      'isGeweiht': isGeweiht,
      'geweihtDescription': geweihtDescription,
      // v19
      'traegerTyp': traegerTyp.name,
      if (traegerId != null) 'traegerId': traegerId,
    };
  }

  /// Deserialisiert einen Inventar-Eintrag aus einem JSON-Map.
  static HeroInventoryEntry fromJson(Map<String, dynamic> json) {
    String getString(String key) => (json[key] as String?) ?? '';

    InventoryItemType parseItemType(String? raw) {
      return InventoryItemType.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => InventoryItemType.sonstiges,
      );
    }

    InventoryItemSource parseSource(String? raw) {
      return InventoryItemSource.values.firstWhere(
        (e) => e.name == raw,
        orElse: () => InventoryItemSource.manuell,
      );
    }

    final modifiersRaw = json['modifiers'];
    final modifiers = modifiersRaw is List
        ? modifiersRaw
              .whereType<Map<String, dynamic>>()
              .map(InventoryItemModifier.fromJson)
              .toList(growable: false)
        : const <InventoryItemModifier>[];
    final legacyArtifact = getString('artefakt').trim();
    final hasMagischDescription =
        json.containsKey('magischDescription') &&
        json['magischDescription'] != null;
    final magischDescription = hasMagischDescription
        ? getString('magischDescription')
        : legacyArtifact;

    return HeroInventoryEntry(
      gegenstand: getString('gegenstand'),
      woGetragen: getString('woGetragen'),
      typ: getString('typ'),
      welchesAbenteuer: getString('welchesAbenteuer'),
      gewicht: getString('gewicht'),
      wert: getString('wert'),
      artefakt: legacyArtifact,
      anzahl: getString('anzahl'),
      amKoerper: getString('amKoerper'),
      woDann: getString('woDann'),
      gruppe: getString('gruppe'),
      beschreibung: getString('beschreibung'),
      // v16 – lenient defaults
      itemType: parseItemType(json['itemType'] as String?),
      source: parseSource(json['source'] as String?),
      sourceRef: json['sourceRef'] as String?,
      istAusgeruestet: (json['istAusgeruestet'] as bool?) ?? false,
      modifiers: modifiers,
      gewichtGramm: (json['gewichtGramm'] as num?)?.toInt() ?? 0,
      wertSilber: (json['wertSilber'] as num?)?.toInt() ?? 0,
      herkunft: getString('herkunft'),
      isMagisch: (json['isMagisch'] as bool?) ?? legacyArtifact.isNotEmpty,
      magischDescription: magischDescription,
      isGeweiht: (json['isGeweiht'] as bool?) ?? false,
      geweihtDescription: getString('geweihtDescription'),
      // v19 – lenient defaults
      traegerTyp: InventoryTraeger.values.firstWhere(
        (e) => e.name == json['traegerTyp'],
        orElse: () => InventoryTraeger.held,
      ),
      traegerId: json['traegerId'] as String?,
    );
  }
}

String _legacyArtifactValue({
  required bool isMagisch,
  required String magischDescription,
  required String legacyArtifact,
}) {
  if (!isMagisch) {
    return '';
  }
  if (magischDescription.isNotEmpty) {
    return magischDescription;
  }
  if (legacyArtifact.isNotEmpty) {
    return legacyArtifact;
  }
  return 'magisch';
}
