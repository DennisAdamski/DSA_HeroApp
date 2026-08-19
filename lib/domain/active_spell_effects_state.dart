import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';

/// Zusatzdaten eines laufenden Zaubereffekts.
///
/// [amount] traegt den effektspezifischen Zahlenwert -- beim `Armatrutz` etwa
/// den zusaetzlichen Ruestungsschutz. [duration] haelt die Wirkungsdauer und
/// ist bewusst optional, weil viele Effekte am Spieltisch ohne feste Dauer
/// gefuehrt werden.
class ActiveSpellEffectDetail {
  /// Erstellt die Zusatzdaten eines Effekts.
  const ActiveSpellEffectDetail({this.amount = 0, this.duration});

  /// Effektspezifischer Zahlenwert (z. B. zusaetzlicher RS beim Armatrutz).
  final int amount;

  /// Wirkungsdauer des Effekts oder `null`, wenn keine erfasst ist.
  final SpellDuration? duration;

  /// `true`, wenn weder Wert noch Wirkungsdauer erfasst sind.
  bool get isEmpty => amount == 0 && duration == null;

  /// Gibt eine Kopie mit geaenderten Feldern zurueck.
  ///
  /// [clearDuration] entfernt die Wirkungsdauer, weil `null` fuer [duration]
  /// bereits "unveraendert lassen" bedeutet.
  ActiveSpellEffectDetail copyWith({
    int? amount,
    SpellDuration? duration,
    bool clearDuration = false,
  }) {
    return ActiveSpellEffectDetail(
      amount: amount ?? this.amount,
      duration: clearDuration ? null : (duration ?? this.duration),
    );
  }

  /// Serialisiert die Zusatzdaten fuer Persistenz und Sync.
  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      if (duration != null) 'duration': duration!.toJson(),
    };
  }

  /// Laedt die Zusatzdaten robust aus JSON.
  static ActiveSpellEffectDetail fromJson(Map<String, dynamic> json) {
    final rawDuration = (json['duration'] as Map?)?.cast<String, dynamic>();
    return ActiveSpellEffectDetail(
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      duration: rawDuration == null ? null : SpellDuration.fromJson(rawDuration),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveSpellEffectDetail &&
        other.amount == amount &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(amount, duration);
}

/// Laufzeitzustand fuer aktivierte wichtige Zaubereffekte.
///
/// Die IDs referenzieren definierte Effekte aus den Regelmodulen und bleiben
/// bewusst getrennt von `HeroSheet.spells`, das bekannte bzw. gelernte Zauber
/// beschreibt. [effectDetails] haengt einzelnen Effekten Zusatzdaten an; die
/// Trennung von [activeEffectIds] haelt aeltere Daten und Aufrufer gueltig,
/// die nur wissen wollen, ob ein Effekt laeuft.
class ActiveSpellEffectsState {
  /// Erstellt einen unveraenderlichen Effektzustand.
  const ActiveSpellEffectsState({
    this.activeEffectIds = const <String>[],
    this.effectDetails = const <String, ActiveSpellEffectDetail>{},
  });

  /// IDs aller aktuell aktiven Zaubereffekte.
  final List<String> activeEffectIds;

  /// Zusatzdaten je Effekt-ID; Effekte ohne Eintrag laufen ohne Zusatzdaten.
  final Map<String, ActiveSpellEffectDetail> effectDetails;

  /// Prueft, ob ein Effekt mit [effectId] aktiv ist.
  bool isActive(String effectId) {
    return activeEffectIds.contains(effectId.trim());
  }

  /// Liefert die Zusatzdaten eines Effekts, notfalls die leeren Standardwerte.
  ActiveSpellEffectDetail detailFor(String effectId) {
    return effectDetails[effectId.trim()] ?? const ActiveSpellEffectDetail();
  }

  /// Gibt eine Kopie mit optional ersetzten Feldern zurueck.
  ActiveSpellEffectsState copyWith({
    List<String>? activeEffectIds,
    Map<String, ActiveSpellEffectDetail>? effectDetails,
  }) {
    final nextIds = _normalizeEffectIds(activeEffectIds ?? this.activeEffectIds);
    return ActiveSpellEffectsState(
      activeEffectIds: nextIds,
      effectDetails: _normalizeDetails(
        effectDetails ?? this.effectDetails,
        nextIds,
      ),
    );
  }

  /// Aktiviert oder deaktiviert einen einzelnen Effekt.
  ///
  /// Beim Deaktivieren fallen auch die Zusatzdaten weg, damit ein spaeter
  /// erneut aktivierter Effekt nicht mit alten Werten und einer abgelaufenen
  /// Wirkungsdauer startet.
  ActiveSpellEffectsState withToggled(String effectId, bool isActive) {
    final normalizedId = effectId.trim();
    if (normalizedId.isEmpty) {
      return this;
    }
    final next = List<String>.from(activeEffectIds);
    final containsId = next.contains(normalizedId);
    if (isActive && !containsId) {
      next.add(normalizedId);
    } else if (!isActive && containsId) {
      next.remove(normalizedId);
    }
    return copyWith(activeEffectIds: next);
  }

  /// Setzt die Zusatzdaten eines Effekts; leere Daten werden entfernt.
  ActiveSpellEffectsState withDetail(
    String effectId,
    ActiveSpellEffectDetail? detail,
  ) {
    final normalizedId = effectId.trim();
    if (normalizedId.isEmpty) {
      return this;
    }
    final next = Map<String, ActiveSpellEffectDetail>.from(effectDetails);
    if (detail == null || detail.isEmpty) {
      next.remove(normalizedId);
    } else {
      next[normalizedId] = detail;
    }
    return copyWith(effectDetails: next);
  }

  /// Serialisiert den Effektzustand fuer Persistenz und Transfer.
  Map<String, dynamic> toJson() {
    final normalizedIds = _normalizeEffectIds(activeEffectIds);
    final normalizedDetails = _normalizeDetails(effectDetails, normalizedIds);
    return {
      'activeEffectIds': normalizedIds,
      'effectDetails': normalizedDetails.map(
        (effectId, detail) => MapEntry(effectId, detail.toJson()),
      ),
    };
  }

  /// Laedt den Effektzustand rueckwaertskompatibel aus JSON.
  ///
  /// Aeltere Staende kennen `effectDetails` nicht; sie laufen dann schlicht
  /// ohne Zusatzdaten weiter.
  static ActiveSpellEffectsState fromJson(Map<String, dynamic> json) {
    final rawIds = (json['activeEffectIds'] as List?) ?? const <dynamic>[];
    final normalizedIds = _normalizeEffectIds(rawIds);
    final rawDetails = (json['effectDetails'] as Map?) ?? const <dynamic, dynamic>{};
    final details = <String, ActiveSpellEffectDetail>{};
    rawDetails.forEach((key, value) {
      if (value is! Map) {
        return;
      }
      details[key.toString().trim()] = ActiveSpellEffectDetail.fromJson(
        value.cast<String, dynamic>(),
      );
    });
    return ActiveSpellEffectsState(
      activeEffectIds: normalizedIds,
      effectDetails: _normalizeDetails(details, normalizedIds),
    );
  }
}

List<String> _normalizeEffectIds(Iterable<dynamic> values) {
  final seen = <String>{};
  final normalized = <String>[];
  for (final value in values) {
    final id = value.toString().trim();
    if (id.isEmpty || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    normalized.add(id);
  }
  return List<String>.unmodifiable(normalized);
}

// Behaelt nur Zusatzdaten aktiver Effekte, damit keine verwaisten Eintraege
// mitgeschleppt und synchronisiert werden.
Map<String, ActiveSpellEffectDetail> _normalizeDetails(
  Map<String, ActiveSpellEffectDetail> details,
  List<String> activeIds,
) {
  final normalized = <String, ActiveSpellEffectDetail>{};
  for (final entry in details.entries) {
    final id = entry.key.trim();
    if (id.isEmpty || !activeIds.contains(id) || entry.value.isEmpty) {
      continue;
    }
    normalized[id] = entry.value;
  }
  return Map<String, ActiveSpellEffectDetail>.unmodifiable(normalized);
}
