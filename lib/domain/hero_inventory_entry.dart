import 'package:dsa_heldenverwaltung/domain/abgelegter_kampfgegenstand.dart';
import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

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
    this.slotRef,
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
    // Gemeinsames Gegenstandsmodell (ARCH-03)
    this.instanzId,
    this.menge,
    this.abgelegt,
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
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

  /// Verweis auf einen Kampf-Slot oder einen anderen fachlichen Ursprung.
  ///
  /// Kampf-Eintraege tragen hier den Namensverweis (`w:<Name>`, `a:<Name>`,
  /// `oh:<Name>`, `w:<Waffe>|p:<Geschoss>`), den auch die bereits
  /// veroeffentlichte App-Version versteht; zugeordnet wird ueber [slotRef]
  /// (siehe `inventar_verweise.dart`). Andere Urspruenge wie Abenteuerbeute
  /// behalten ihre eigenen Verweisformate.
  ///
  /// `null` bei manuell angelegten Eintraegen.
  final String? sourceRef;

  /// Stabiler ID-Verweis auf den Kampf-Slot (`w#<id>`, `a#<id>`, `oh#<id>`,
  /// `w#<waffenId>|p#<geschossId>`).
  ///
  /// Unterscheidet gleichnamige Exemplare. `null` bei Eintraegen ohne
  /// Kampf-Slot und bei solchen, die zuletzt eine aeltere App-Version
  /// gespeichert hat; sie erhalten ihn beim Laden ueber den Namen.
  final String? slotRef;

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

  // --- Gemeinsames Gegenstandsmodell (ARCH-03) ---

  /// Stabile Instanz-ID dieses Stapels bzw. Exemplars.
  ///
  /// Eindeutig nur innerhalb eines Helden und bei einer Heldenkopie
  /// unverändert (Entscheidung vom 04.10.2026). Wird erst beim Speichern
  /// vergeben (`HeroActions.saveHero`), nie beim Laden, weil sonst jeder
  /// Bestandsheld einen neuen Inhalts-Hash bekäme. `null` bei Altdaten.
  final String? instanzId;

  /// Stückzahl des Stapels. `null`, solange nur der Freitext [anzahl]
  /// vorliegt; dann gilt die Menge als offen (Altdarstellung). Ein Stapel
  /// ist ein Gegenstand mit einer Menge; Teilen erzeugt einen zweiten
  /// Eintrag mit eigener [instanzId].
  final int? menge;

  /// Gemerkte Kampfwerte, wenn das Exemplar im Kampfbereich nur abgelegt
  /// wurde; `null` sonst. „In Kampfbereich übernehmen“ legt daraus den Slot
  /// wieder an (`kampfgegenstand_ablegen_rules.dart`). Nur geschrieben, wenn
  /// belegt.
  final AbgelegterKampfgegenstand? abgelegt;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzaehlungswerte einer neueren App-Version (JSON-Schluessel
  /// -> Rohwert). Die Felder tragen den Ersatzwert, mit dem Regeln rechnen;
  /// geschrieben wird der Rohwert, bis jemand das Feld auf einen anderen Wert
  /// setzt (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich der nur bedingt
  /// geschriebenen; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'gegenstand',
    'woGetragen',
    'typ',
    'welchesAbenteuer',
    'gewicht',
    'wert',
    'artefakt',
    'anzahl',
    'amKoerper',
    'woDann',
    'gruppe',
    'beschreibung',
    'itemType',
    'source',
    'sourceRef',
    'slotRef',
    'istAusgeruestet',
    'modifiers',
    'gewichtGramm',
    'wertSilber',
    'herkunft',
    'isMagisch',
    'magischDescription',
    'isGeweiht',
    'geweihtDescription',
    'traegerTyp',
    'traegerId',
    'instanzId',
    'menge',
    'abgelegt',
  };

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
    Object? slotRef = keepFieldValue,
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
    Object? instanzId = keepFieldValue,
    Object? menge = keepFieldValue,
    Object? abgelegt = keepFieldValue,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
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
      slotRef: slotRef == keepFieldValue ? this.slotRef : slotRef as String?,
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
      instanzId: instanzId == keepFieldValue
          ? this.instanzId
          : instanzId as String?,
      menge: menge == keepFieldValue ? this.menge : menge as int?,
      abgelegt: abgelegt == keepFieldValue
          ? this.abgelegt
          : abgelegt as AbgelegterKampfgegenstand?,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'itemType': itemType != null && itemType != this.itemType,
            'source': source != null && source != this.source,
            'traegerTyp': traegerTyp != null && traegerTyp != this.traegerTyp,
          }),
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

    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
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
        if (slotRef != null) 'slotRef': slotRef,
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
        // ARCH-03: nur bei belegtem Wert, sonst ändern sich Bestands-Hashes.
        if (instanzId != null) 'instanzId': instanzId,
        if (menge != null) 'menge': menge,
        if (abgelegt != null) 'abgelegt': abgelegt!.toJson(),
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Deserialisiert einen Inventar-Eintrag aus einem JSON-Map.
  static HeroInventoryEntry fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    String getString(String key) => (json[key] as String?) ?? '';

    final modifiersRaw = json['modifiers'];
    final modifiers = modifiersRaw is List
        ? modifiersRaw
              .whereType<Map>()
              .map(
                (entry) => InventoryItemModifier.fromJson(
                  entry.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false)
        : const <InventoryItemModifier>[];
    final legacyArtifact = getString('artefakt').trim();
    final abgelegtRoh = json['abgelegt'];
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
      itemType: leseEnumWert(
        json['itemType'],
        'itemType',
        erkenne: (roh) => enumNachName(InventoryItemType.values, roh),
        ersatz: InventoryItemType.sonstiges,
        unbekannt: enumRoh,
      ),
      source: leseEnumWert(
        json['source'],
        'source',
        erkenne: (roh) => enumNachName(InventoryItemSource.values, roh),
        ersatz: InventoryItemSource.manuell,
        unbekannt: enumRoh,
      ),
      sourceRef: json['sourceRef'] as String?,
      slotRef: json['slotRef'] as String?,
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
      traegerTyp: leseEnumWert(
        json['traegerTyp'],
        'traegerTyp',
        erkenne: (roh) => enumNachName(InventoryTraeger.values, roh),
        ersatz: InventoryTraeger.held,
        unbekannt: enumRoh,
      ),
      traegerId: json['traegerId'] as String?,
      instanzId: json['instanzId'] as String?,
      menge: (json['menge'] as num?)?.toInt(),
      abgelegt: abgelegtRoh is Map
          ? AbgelegterKampfgegenstand.fromJson(
              abgelegtRoh.cast<String, dynamic>(),
            )
          : null,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
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
