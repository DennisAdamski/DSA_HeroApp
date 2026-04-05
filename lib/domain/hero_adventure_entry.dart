import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

/// Status eines Abenteuers in der Heldenchronik.
enum HeroAdventureStatus {
  /// Das Abenteuer läuft aktuell noch.
  current,

  /// Das Abenteuer wurde abgeschlossen.
  completed,
}

/// Zieltyp einer Abenteuer-Sondererfahrung.
enum HeroAdventureSeTargetType {
  /// Sondererfahrung fuer ein Talent.
  talent,

  /// Sondererfahrung fuer einen kaufbaren Grundwert.
  grundwert,

  /// Sondererfahrung fuer eine Eigenschaft.
  eigenschaft,
}

/// Strukturierte SE-Zeile eines Abenteuers.
class HeroAdventureSeReward {
  /// Erzeugt eine persistierbare Abenteuer-SE-Zeile.
  const HeroAdventureSeReward({
    this.targetType = HeroAdventureSeTargetType.talent,
    this.targetId = '',
    this.targetLabel = '',
    this.count = 1,
  });

  /// Typ des Zielwerts.
  final HeroAdventureSeTargetType targetType;

  /// Persistierter Zielschluessel, z. B. Talent-ID oder Wertcode.
  final String targetId;

  /// Anzeigename des Zielwerts zum stabilen Anzeigen ohne Katalogzugriff.
  final String targetLabel;

  /// Anzahl der SE fuer das Ziel.
  final int count;

  /// Gibt an, ob die Zeile fachlich belegt ist.
  bool get hasContent {
    return targetId.trim().isNotEmpty && count > 0;
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventureSeReward copyWith({
    HeroAdventureSeTargetType? targetType,
    String? targetId,
    String? targetLabel,
    int? count,
  }) {
    return HeroAdventureSeReward(
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      targetLabel: targetLabel ?? this.targetLabel,
      count: _normalizeCount(count ?? this.count),
    );
  }

  /// Serialisiert die Zeile fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'targetType': targetType.name,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'count': count,
    };
  }

  /// Laedt eine SE-Zeile tolerant gegenueber fehlenden Feldern.
  static HeroAdventureSeReward fromJson(Map<String, dynamic> json) {
    return HeroAdventureSeReward(
      targetType: _parseAdventureSeTargetType(json['targetType']),
      targetId: (json['targetId'] as String?) ?? '',
      targetLabel: (json['targetLabel'] as String?) ?? '',
      count: _normalizeCount((json['count'] as num?)?.toInt() ?? 1),
    );
  }
}

/// Strukturierter Datumswert fuer Abenteuerangaben.
class HeroAdventureDateValue {
  /// Erzeugt ein persistierbares Abenteuerdatum.
  const HeroAdventureDateValue({
    this.day = '',
    this.month = '',
    this.year = '',
  });

  /// Tag des Datums.
  final String day;

  /// Monat des Datums.
  final String month;

  /// Jahr des Datums.
  final String year;

  /// Gibt an, ob mindestens ein Datumsfeld belegt ist.
  bool get hasContent {
    return day.trim().isNotEmpty ||
        month.trim().isNotEmpty ||
        year.trim().isNotEmpty;
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventureDateValue copyWith({String? day, String? month, String? year}) {
    return HeroAdventureDateValue(
      day: day ?? this.day,
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }

  /// Serialisiert das Datum fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'day': day, 'month': month, 'year': year};
  }

  /// Laedt ein Abenteuerdatum tolerant gegenueber fehlenden Feldern.
  static HeroAdventureDateValue fromJson(Map<String, dynamic> json) {
    String getString(String key) => json[key]?.toString() ?? '';

    return HeroAdventureDateValue(
      day: getString('day'),
      month: getString('month'),
      year: getString('year'),
    );
  }

  /// Wandelt ein `DateTime` in ein weltliches Abenteuerdatum um.
  static HeroAdventureDateValue fromDateTime(DateTime value) {
    final localValue = value.toLocal();
    return HeroAdventureDateValue(
      day: localValue.day.toString().padLeft(2, '0'),
      month: localValue.month.toString().padLeft(2, '0'),
      year: localValue.year.toString(),
    );
  }
}

/// Beschreibt eine abenteuerspezifische Person oder NSC-Referenz.
class HeroAdventurePersonEntry {
  /// Erzeugt einen persistierbaren Personeneintrag.
  const HeroAdventurePersonEntry({
    required this.id,
    this.name = '',
    this.description = '',
  });

  /// Stabile ID der Person innerhalb des Abenteuers.
  final String id;

  /// Anzeigename der Person.
  final String name;

  /// Kurze Kontextbeschreibung der Person.
  final String description;

  /// Gibt an, ob der Eintrag fachlich belegt ist.
  bool get hasContent {
    return name.trim().isNotEmpty || description.trim().isNotEmpty;
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventurePersonEntry copyWith({
    String? id,
    String? name,
    String? description,
  }) {
    return HeroAdventurePersonEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  /// Serialisiert die Person fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
    };
  }

  /// Laedt einen Personeneintrag tolerant gegenueber fehlenden Feldern.
  static HeroAdventurePersonEntry fromJson(Map<String, dynamic> json) {
    String getString(String key) => json[key]?.toString() ?? '';

    return HeroAdventurePersonEntry(
      id: getString('id'),
      name: getString('name'),
      description: getString('description'),
    );
  }
}

/// Persistierte Beutezeile aus dem Abenteuer-Abschluss.
class HeroAdventureLootEntry {
  /// Erzeugt eine persistierbare Beutezeile mit stabiler ID.
  const HeroAdventureLootEntry({
    required this.id,
    this.name = '',
    this.quantity = '',
    this.itemType = InventoryItemType.sonstiges,
    this.weightGramm = 0,
    this.valueSilver = 0,
    this.origin = '',
    this.description = '',
  });

  /// Stabile ID der Beutezeile innerhalb des Abenteuers.
  final String id;

  /// Anzeigename des Gegenstands.
  final String name;

  /// Erfasste Anzahl oder Mengennotiz.
  final String quantity;

  /// Typ des Gegenstands fuer die Inventaruebernahme.
  final InventoryItemType itemType;

  /// Gewicht in Gramm.
  final int weightGramm;

  /// Wert in Silbertalern.
  final int valueSilver;

  /// Herkunft oder Fundnotiz fuer die Inventaranzeige.
  final String origin;

  /// Freitextbeschreibung des Gegenstands.
  final String description;

  /// Gibt an, ob die Zeile fachlich belegt ist.
  bool get hasContent {
    return name.trim().isNotEmpty ||
        quantity.trim().isNotEmpty ||
        weightGramm > 0 ||
        valueSilver > 0 ||
        origin.trim().isNotEmpty ||
        description.trim().isNotEmpty;
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventureLootEntry copyWith({
    String? id,
    String? name,
    String? quantity,
    InventoryItemType? itemType,
    int? weightGramm,
    int? valueSilver,
    String? origin,
    String? description,
  }) {
    return HeroAdventureLootEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      itemType: itemType ?? this.itemType,
      weightGramm: _normalizeReward(weightGramm ?? this.weightGramm),
      valueSilver: _normalizeReward(valueSilver ?? this.valueSilver),
      origin: origin ?? this.origin,
      description: description ?? this.description,
    );
  }

  /// Serialisiert die Beutezeile fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'quantity': quantity,
      'itemType': itemType.name,
      'weightGramm': weightGramm,
      'valueSilver': valueSilver,
      'origin': origin,
      'description': description,
    };
  }

  /// Laedt eine Beutezeile tolerant gegenueber fehlenden Feldern.
  static HeroAdventureLootEntry fromJson(Map<String, dynamic> json) {
    String getString(String key) => json[key]?.toString() ?? '';

    return HeroAdventureLootEntry(
      id: getString('id'),
      name: getString('name'),
      quantity: getString('quantity'),
      itemType: _parseInventoryItemType(json['itemType']),
      weightGramm: _normalizeReward(
        (json['weightGramm'] as num?)?.toInt() ?? 0,
      ),
      valueSilver: _normalizeReward(
        (json['valueSilver'] as num?)?.toInt() ?? 0,
      ),
      origin: getString('origin'),
      description: getString('description'),
    );
  }
}

/// Manuell gepflegter Abenteuer-Eintrag eines Helden.
class HeroAdventureEntry {
  /// Erzeugt ein persistierbares Abenteuer mit stabiler ID.
  const HeroAdventureEntry({
    required this.id,
    this.status = HeroAdventureStatus.current,
    this.title = '',
    this.summary = '',
    this.notes = const <HeroNoteEntry>[],
    this.people = const <HeroAdventurePersonEntry>[],
    this.startWorldDate = const HeroAdventureDateValue(),
    this.startAventurianDate = const HeroAdventureDateValue(),
    this.endWorldDate = const HeroAdventureDateValue(),
    this.endAventurianDate = const HeroAdventureDateValue(),
    this.currentAventurianDate = const HeroAdventureDateValue(),
    this.apReward = 0,
    this.seRewards = const <HeroAdventureSeReward>[],
    this.dukatenReward = 0,
    this.lootRewards = const <HeroAdventureLootEntry>[],
    this.rewardsApplied = false,
  });

  /// Stabile ID des Abenteuers.
  final String id;

  /// Fortschrittsstatus des Abenteuers.
  final HeroAdventureStatus status;

  /// Anzeigename des Abenteuers.
  final String title;

  /// Kurze Zusammenfassung oder Etappenbeschreibung.
  final String summary;

  /// Abenteuerbezogene Detailnotizen.
  final List<HeroNoteEntry> notes;

  /// Abenteuerspezifische Personen und NSCs.
  final List<HeroAdventurePersonEntry> people;

  /// Weltliches Startdatum.
  final HeroAdventureDateValue startWorldDate;

  /// Aventurisches Startdatum.
  final HeroAdventureDateValue startAventurianDate;

  /// Weltliches Enddatum.
  final HeroAdventureDateValue endWorldDate;

  /// Aventurisches Enddatum.
  final HeroAdventureDateValue endAventurianDate;

  /// Aktueller aventurischer Stand innerhalb des Abenteuers.
  final HeroAdventureDateValue currentAventurianDate;

  /// AP-Belohnung fuer das Abenteuer.
  final int apReward;

  /// Strukturierte SE-Belohnungen des Abenteuers.
  final List<HeroAdventureSeReward> seRewards;

  /// Numerische Dukaten-Belohnung fuer den Abschluss.
  final double dukatenReward;

  /// Gegenstaende, die beim Abschluss ins Inventar uebernommen werden.
  final List<HeroAdventureLootEntry> lootRewards;

  /// Kennzeichnet, ob die Belohnungen bereits auf den Helden angewendet wurden.
  final bool rewardsApplied;

  /// Gibt an, ob das Abenteuer fachlich gefuellt ist.
  bool get hasContent {
    if (rewardsApplied || apReward > 0 || dukatenReward > 0) {
      return true;
    }
    if (title.trim().isNotEmpty || summary.trim().isNotEmpty) {
      return true;
    }
    if (people.any((entry) => entry.hasContent)) {
      return true;
    }
    if (startWorldDate.hasContent ||
        startAventurianDate.hasContent ||
        endWorldDate.hasContent ||
        endAventurianDate.hasContent ||
        currentAventurianDate.hasContent) {
      return true;
    }
    if (seRewards.any((entry) => entry.hasContent)) {
      return true;
    }
    if (lootRewards.any((entry) => entry.hasContent)) {
      return true;
    }
    return notes.any((entry) => _hasAdventureNoteContent(entry));
  }

  /// Gibt an, ob das Abenteuer eine anwendbare Belohnung besitzt.
  bool get hasRewards {
    return apReward > 0 ||
        dukatenReward > 0 ||
        seRewards.any((entry) => entry.hasContent) ||
        lootRewards.any((entry) => entry.hasContent);
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventureEntry copyWith({
    String? id,
    HeroAdventureStatus? status,
    String? title,
    String? summary,
    List<HeroNoteEntry>? notes,
    List<HeroAdventurePersonEntry>? people,
    HeroAdventureDateValue? startWorldDate,
    HeroAdventureDateValue? startAventurianDate,
    HeroAdventureDateValue? endWorldDate,
    HeroAdventureDateValue? endAventurianDate,
    HeroAdventureDateValue? currentAventurianDate,
    int? apReward,
    List<HeroAdventureSeReward>? seRewards,
    double? dukatenReward,
    List<HeroAdventureLootEntry>? lootRewards,
    bool? rewardsApplied,
  }) {
    return HeroAdventureEntry(
      id: id ?? this.id,
      status: status ?? this.status,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      notes: notes ?? this.notes,
      people: people ?? this.people,
      startWorldDate: startWorldDate ?? this.startWorldDate,
      startAventurianDate: startAventurianDate ?? this.startAventurianDate,
      endWorldDate: endWorldDate ?? this.endWorldDate,
      endAventurianDate: endAventurianDate ?? this.endAventurianDate,
      currentAventurianDate:
          currentAventurianDate ?? this.currentAventurianDate,
      apReward: _normalizeReward(apReward ?? this.apReward),
      seRewards: seRewards ?? this.seRewards,
      dukatenReward: _normalizeDukatenReward(
        dukatenReward ?? this.dukatenReward,
      ),
      lootRewards: lootRewards ?? this.lootRewards,
      rewardsApplied: rewardsApplied ?? this.rewardsApplied,
    );
  }

  /// Serialisiert das Abenteuer fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'status': status.name,
      'title': title,
      'summary': summary,
      'notes': notes.map((entry) => entry.toJson()).toList(growable: false),
      'people': people.map((entry) => entry.toJson()).toList(growable: false),
      'startWorldDate': startWorldDate.toJson(),
      'startAventurianDate': startAventurianDate.toJson(),
      'endWorldDate': endWorldDate.toJson(),
      'endAventurianDate': endAventurianDate.toJson(),
      'currentAventurianDate': currentAventurianDate.toJson(),
      'apReward': apReward,
      'seRewards': seRewards
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'dukatenReward': dukatenReward,
      'lootRewards': lootRewards
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'rewardsApplied': rewardsApplied,
    };
  }

  /// Laedt ein Abenteuer tolerant gegenueber fehlenden Feldern.
  static HeroAdventureEntry fromJson(Map<String, dynamic> json) {
    final rawNotes = (json['notes'] as List?) ?? const <dynamic>[];
    final rawPeople = (json['people'] as List?) ?? const <dynamic>[];
    final rawSeRewards = (json['seRewards'] as List?) ?? const <dynamic>[];
    final rawLootRewards = (json['lootRewards'] as List?) ?? const <dynamic>[];

    return HeroAdventureEntry(
      id: (json['id'] as String?) ?? '',
      status: _parseAdventureStatus(json['status']),
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      notes: rawNotes
          .whereType<Map>()
          .map((entry) => HeroNoteEntry.fromJson(entry.cast<String, dynamic>()))
          .toList(growable: false),
      people: rawPeople
          .whereType<Map>()
          .map(
            (entry) => HeroAdventurePersonEntry.fromJson(
              entry.cast<String, dynamic>(),
            ),
          )
          .where((entry) => entry.hasContent)
          .toList(growable: false),
      startWorldDate: _parseAdventureDateValue(json['startWorldDate']),
      startAventurianDate: _parseAdventureDateValue(
        json['startAventurianDate'],
      ),
      endWorldDate: _parseAdventureDateValue(json['endWorldDate']),
      endAventurianDate: _parseAdventureDateValue(json['endAventurianDate']),
      currentAventurianDate: _parseAdventureDateValue(
        json['currentAventurianDate'],
      ),
      apReward: _normalizeReward((json['apReward'] as num?)?.toInt() ?? 0),
      seRewards: rawSeRewards
          .whereType<Map>()
          .map(
            (entry) =>
                HeroAdventureSeReward.fromJson(entry.cast<String, dynamic>()),
          )
          .where((entry) => entry.hasContent)
          .toList(growable: false),
      dukatenReward: _normalizeDukatenReward(
        (json['dukatenReward'] as num?)?.toDouble() ?? 0,
      ),
      lootRewards: rawLootRewards
          .whereType<Map>()
          .map(
            (entry) =>
                HeroAdventureLootEntry.fromJson(entry.cast<String, dynamic>()),
          )
          .where((entry) => entry.hasContent)
          .toList(growable: false),
      rewardsApplied: json['rewardsApplied'] as bool? ?? false,
    );
  }
}

HeroAdventureStatus _parseAdventureStatus(dynamic raw) {
  return switch ((raw as String?)?.trim().toLowerCase()) {
    'completed' => HeroAdventureStatus.completed,
    _ => HeroAdventureStatus.current,
  };
}

HeroAdventureSeTargetType _parseAdventureSeTargetType(dynamic raw) {
  return switch ((raw as String?)?.trim().toLowerCase()) {
    'grundwert' => HeroAdventureSeTargetType.grundwert,
    'eigenschaft' => HeroAdventureSeTargetType.eigenschaft,
    _ => HeroAdventureSeTargetType.talent,
  };
}

HeroAdventureDateValue _parseAdventureDateValue(dynamic raw) {
  if (raw is Map) {
    return HeroAdventureDateValue.fromJson(raw.cast<String, dynamic>());
  }
  return const HeroAdventureDateValue();
}

InventoryItemType _parseInventoryItemType(dynamic raw) {
  return InventoryItemType.values.firstWhere(
    (entry) => entry.name == raw,
    orElse: () => InventoryItemType.sonstiges,
  );
}

bool _hasAdventureNoteContent(HeroNoteEntry entry) {
  return entry.title.trim().isNotEmpty || entry.description.trim().isNotEmpty;
}

int _normalizeCount(int value) {
  return value < 0 ? 0 : value;
}

int _normalizeReward(int value) {
  return value < 0 ? 0 : value;
}

double _normalizeDukatenReward(double value) {
  return value < 0 ? 0 : value;
}
