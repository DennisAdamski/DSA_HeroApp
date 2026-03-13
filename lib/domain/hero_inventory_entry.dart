import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Wer oder was ein Inventarstück trägt.
enum InventoryTraeger {
  /// Wird vom Helden selbst getragen (Standard).
  held,

  /// Wird von einem Begleiter getragen.
  begleiter,
}

class HeroInventoryEntry {
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

  // --- Träger-Felder (v19) ---

  /// Wer dieses Inventarstück trägt.
  final InventoryTraeger traegerTyp;

  /// ID des Begleiters, wenn [traegerTyp] == [InventoryTraeger.begleiter].
  /// Null, wenn der Held das Item trägt.
  final String? traegerId;

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
    Object? sourceRef = _sentinel,
    bool? istAusgeruestet,
    List<InventoryItemModifier>? modifiers,
    int? gewichtGramm,
    int? wertSilber,
    String? herkunft,
    InventoryTraeger? traegerTyp,
    Object? traegerId = _sentinel,
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
      sourceRef: sourceRef == _sentinel ? this.sourceRef : sourceRef as String?,
      istAusgeruestet: istAusgeruestet ?? this.istAusgeruestet,
      modifiers: modifiers ?? this.modifiers,
      gewichtGramm: gewichtGramm ?? this.gewichtGramm,
      wertSilber: wertSilber ?? this.wertSilber,
      herkunft: herkunft ?? this.herkunft,
      traegerTyp: traegerTyp ?? this.traegerTyp,
      traegerId: traegerId == _sentinel ? this.traegerId : traegerId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'gegenstand': gegenstand,
      'woGetragen': woGetragen,
      'typ': typ,
      'welchesAbenteuer': welchesAbenteuer,
      'gewicht': gewicht,
      'wert': wert,
      'artefakt': artefakt,
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
      // v19
      'traegerTyp': traegerTyp.name,
      if (traegerId != null) 'traegerId': traegerId,
    };
  }

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

    return HeroInventoryEntry(
      gegenstand: getString('gegenstand'),
      woGetragen: getString('woGetragen'),
      typ: getString('typ'),
      welchesAbenteuer: getString('welchesAbenteuer'),
      gewicht: getString('gewicht'),
      wert: getString('wert'),
      artefakt: getString('artefakt'),
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
      // v19 – lenient defaults
      traegerTyp: InventoryTraeger.values.firstWhere(
        (e) => e.name == json['traegerTyp'],
        orElse: () => InventoryTraeger.held,
      ),
      traegerId: json['traegerId'] as String?,
    );
  }
}

/// Sentinel-Objekt fuer nullable copyWith-Parameter.
const Object _sentinel = Object();
