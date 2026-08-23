/// Ein Monat des aventurischen Kalenders.
///
/// [value] ist der persistierte Schluessel, [label] der Anzeigename.
class AventurianMonth {
  /// Erzeugt einen Kalendermonat mit Schluessel und Anzeigename.
  const AventurianMonth({required this.value, required this.label});

  /// Persistierter Schluessel, z. B. `praios`.
  final String value;

  /// Anzeigename, z. B. `Praios`.
  final String label;
}

/// Die kanonische Monatsfolge des aventurischen Kalenders.
///
/// Zwoelf Goettermonate zu je 30 Tagen, danach die fuenf Namenlosen Tage
/// (Geographia Aventurica, Immerwaehrender Kalender S. 253). Die Reihenfolge
/// ist bindend: aus ihr leitet sich die Tagesnummer im Jahr ab.
const List<AventurianMonth> aventurianMonths = <AventurianMonth>[
  AventurianMonth(value: 'praios', label: 'Praios'),
  AventurianMonth(value: 'rondra', label: 'Rondra'),
  AventurianMonth(value: 'efferd', label: 'Efferd'),
  AventurianMonth(value: 'travia', label: 'Travia'),
  AventurianMonth(value: 'boron', label: 'Boron'),
  AventurianMonth(value: 'hesinde', label: 'Hesinde'),
  AventurianMonth(value: 'firun', label: 'Firun'),
  AventurianMonth(value: 'tsa', label: 'Tsa'),
  AventurianMonth(value: 'phex', label: 'Phex'),
  AventurianMonth(value: 'peraine', label: 'Peraine'),
  AventurianMonth(value: 'ingerimm', label: 'Ingerimm'),
  AventurianMonth(value: 'rahja', label: 'Rahja'),
  AventurianMonth(value: 'namenlose_tage', label: 'Namenlose Tage'),
];

/// Schluessel der Namenlosen Tage, die als 13. Kalenderabschnitt gefuehrt werden.
const String aventurianNamenloseTageKey = 'namenlose_tage';

/// Tage je regulaerem Goettermonat.
const int aventurianDaysPerMonth = 30;

/// Anzahl der Namenlosen Tage am Jahresende.
const int aventurianNamenloseTageCount = 5;

/// Ein aventurisches Datum aus Tag, Monat und Jahr.
///
/// Alle Felder bleiben `String`, weil die Eingabefelder der App Freitext
/// zulassen (z. B. `1027 BF` im Jahr) und Teilangaben gueltig sind. Die
/// Auswertung uebernimmt `lib/rules/derived/aventurian_age_rules.dart`.
class AventurianDate {
  /// Erzeugt ein persistierbares aventurisches Datum.
  const AventurianDate({this.day = '', this.month = '', this.year = ''});

  /// Erzeugt ein Datum aus einzelnen, moeglicherweise ungetrimmten Teilen.
  factory AventurianDate.fromParts(String day, String month, String year) {
    return AventurianDate(
      day: day.trim(),
      month: normalizeAventurianMonth(month),
      year: year.trim(),
    );
  }

  /// Tag im Monat als Freitext.
  final String day;

  /// Monatsschluessel aus [aventurianMonths].
  final String month;

  /// Jahr als Freitext, ueblicherweise in BF.
  final String year;

  /// Gibt an, ob mindestens ein Feld belegt ist.
  bool get hasContent {
    return day.trim().isNotEmpty ||
        month.trim().isNotEmpty ||
        year.trim().isNotEmpty;
  }

  /// Liefert eine Kopie mit gezielt ersetzten Feldern.
  AventurianDate copyWith({String? day, String? month, String? year}) {
    return AventurianDate(
      day: day ?? this.day,
      month: month ?? this.month,
      year: year ?? this.year,
    );
  }

  /// Serialisiert das Datum fuer Persistenz und Export.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'day': day, 'month': month, 'year': year};
  }

  /// Laedt ein Datum tolerant gegenueber fehlenden Feldern.
  static AventurianDate fromJson(Map<String, dynamic> json) {
    String getString(String key) => json[key]?.toString().trim() ?? '';

    return AventurianDate(
      day: getString('day'),
      month: normalizeAventurianMonth(getString('month')),
      year: getString('year'),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AventurianDate &&
        other.day == day &&
        other.month == month &&
        other.year == year;
  }

  @override
  int get hashCode => Object.hash(day, month, year);

  @override
  String toString() => 'AventurianDate($day, $month, $year)';
}

/// Fuehrt eine Monatsangabe auf ihren Schluessel zurueck.
///
/// Akzeptiert Schluessel und Anzeigenamen; unbekannte Angaben liefern `''`,
/// damit Dropdowns keinen ungueltigen Wert zugewiesen bekommen.
String normalizeAventurianMonth(String rawValue) {
  final normalizedValue = rawValue.trim().toLowerCase();
  if (normalizedValue.isEmpty) {
    return '';
  }
  for (final month in aventurianMonths) {
    final matchesKey = month.value == normalizedValue;
    final matchesLabel = month.label.toLowerCase() == normalizedValue;
    if (matchesKey || matchesLabel) {
      return month.value;
    }
  }
  return '';
}

/// Liefert den Anzeigenamen zu einer Monatsangabe.
///
/// Unbekannte Angaben werden unveraendert (getrimmt) zurueckgegeben, damit
/// selbst gepflegte Fremdangaben in der Anzeige nicht verschwinden.
String aventurianMonthLabel(String rawValue) {
  final normalizedValue = normalizeAventurianMonth(rawValue);
  if (normalizedValue.isEmpty) {
    return rawValue.trim();
  }
  final month = aventurianMonths.firstWhere(
    (entry) => entry.value == normalizedValue,
  );
  return month.label;
}

/// Position eines Monats in der Kalenderfolge, oder `null` bei Unbekanntem.
int? aventurianMonthIndex(String rawValue) {
  final normalizedValue = normalizeAventurianMonth(rawValue);
  if (normalizedValue.isEmpty) {
    return null;
  }
  return aventurianMonths.indexWhere((entry) => entry.value == normalizedValue);
}

/// Formatiert ein Datum als `12. Praios 1027 BF`.
///
/// Fehlende Bestandteile entfallen ersatzlos; `BF` wird nur an rein numerische
/// Jahresangaben angehaengt, damit eine bereits eingetippte Aera nicht doppelt
/// erscheint.
String formatAventurianDate(AventurianDate date) {
  final parts = <String>[];

  final day = date.day.trim();
  if (day.isNotEmpty) {
    parts.add('$day.');
  }

  final monthLabel = aventurianMonthLabel(date.month);
  if (monthLabel.isNotEmpty) {
    parts.add(monthLabel);
  }

  final year = date.year.trim();
  if (year.isNotEmpty) {
    final isPlainNumber = RegExp(r'^-?\d+$').hasMatch(year);
    parts.add(isPlainNumber ? '$year BF' : year);
  }

  return parts.join(' ');
}
