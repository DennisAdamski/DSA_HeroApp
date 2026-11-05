import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Strukturierter Datumswert fuer Abenteuerangaben.
class HeroAdventureDateValue {
  /// Erzeugt ein persistierbares Abenteuerdatum.
  const HeroAdventureDateValue({
    this.day = '',
    this.month = '',
    this.year = '',
    this.unbekannteFelder = const <String, Object?>{},
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

  /// Anzeigetext wie `17. Boron 1020 BF`; fehlende Teile entfallen, ohne
  /// Angabe leer ([formatAventurianDate]).
  String get anzeigeText =>
      formatAventurianDate(AventurianDate.fromParts(day, month, year));

  /// Ob Tag, Monat und Jahr mit [other] übereinstimmen; unbekannte Felder
  /// zählen nicht.
  bool gleicheAngabe(HeroAdventureDateValue other) =>
      day == other.day && month == other.month && year == other.year;

  /// Ob das Datum ins JSON gehört: belegt oder mit Feldern einer neueren
  /// App-Version. Leere Daten bleiben weg, damit sich Inhalts-Hashes nicht
  /// ändern.
  bool get istBelegt => hasContent || unbekannteFelder.isNotEmpty;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'day', 'month', 'year'};

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  HeroAdventureDateValue copyWith({
    String? day,
    String? month,
    String? year,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroAdventureDateValue(
      day: day ?? this.day,
      month: month ?? this.month,
      year: year ?? this.year,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert das Datum fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'day': day,
      'month': month,
      'year': year,
    }, unbekannteFelder);
  }

  /// Laedt ein Abenteuerdatum tolerant gegenueber fehlenden Feldern.
  static HeroAdventureDateValue fromJson(Map<String, dynamic> json) {
    String getString(String key) => json[key]?.toString() ?? '';

    return HeroAdventureDateValue(
      day: getString('day'),
      month: getString('month'),
      year: getString('year'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  /// Liest ein gespeichertes Datumsfeld tolerant.
  ///
  /// Ein Objekt wird über [fromJson] gelesen. Ein Text stammt aus einer
  /// Zwischenfassung, die Notiz- und Personendaten als Freitext speicherte
  /// (`17. Boron 1020 BF`): Er wird in Tag, Monat und Jahr zerlegt; lässt er
  /// sich nicht zerlegen, bleibt er vollständig im Jahr stehen, damit nichts
  /// verloren geht. Alles andere ergibt ein leeres Datum.
  static HeroAdventureDateValue lese(Object? roh) {
    if (roh is Map) {
      return HeroAdventureDateValue.fromJson(Map<String, dynamic>.from(roh));
    }
    if (roh is String && roh.trim().isNotEmpty) {
      return _ausText(roh.trim());
    }
    return const HeroAdventureDateValue();
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

// `17. Boron 1020 BF`, `17 Boron`, `Boron 1020 BF`: Tag optional, Monat als
// Anzeigename oder Schlüssel, Rest als Jahr.
final RegExp _datumsText = RegExp(
  r'^(?:(\d{1,2})\.?\s+)?(namenlose tage|[a-zäöü]+)(?:\s+(.+))?$',
  caseSensitive: false,
);

HeroAdventureDateValue _ausText(String text) {
  final treffer = _datumsText.firstMatch(text);
  final monat = treffer == null
      ? ''
      : normalizeAventurianMonth(treffer.group(2) ?? '');
  if (treffer == null || monat.isEmpty) {
    return HeroAdventureDateValue(year: text);
  }
  return HeroAdventureDateValue(
    day: treffer.group(1) ?? '',
    month: monat,
    year: (treffer.group(3) ?? '').trim(),
  );
}
