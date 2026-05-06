/// Anzahl Kreuzer, die einem Dukaten entsprechen.
const int dsaKreuzerPerDukat = 1000;

/// Anzahl Kreuzer, die einem Silbertaler entsprechen.
const int dsaKreuzerPerSilber = 100;

/// Anzahl Kreuzer, die einem Heller entsprechen.
const int dsaKreuzerPerHeller = 10;

/// Wandelt einen Dukatenwert in Kreuzer um.
///
/// Die Umrechnung nutzt Kreuzer als kleinste Einheit, damit Silber- und
/// Kreuzerschritte ohne Rundungsverlust erhalten bleiben.
int dukatenToDsaKreuzer(double value) {
  return (value * dsaKreuzerPerDukat).round();
}

/// Liest einen gespeicherten Geldwert als Kreuzer.
///
/// Unterstützt freie numerische Dukatenwerte wie `12,5` sowie Münzschreibweisen
/// wie `12 D 5 S 3 K`. Ein leerer Wert wird als `0` behandelt.
int? parseDsaCurrencyToKreuzer(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return 0;
  }

  final decimalValue = _parseDecimalDukaten(trimmed);
  if (decimalValue != null) {
    return decimalValue;
  }

  return _parseCoinNotation(trimmed);
}

/// Formatiert Kreuzer als kompakten Dukatenwert mit deutschem Dezimalkomma.
String formatDsaCurrencyDukaten(int kreuzer) {
  final normalized = kreuzer < 0 ? 0 : kreuzer;
  final dukaten = normalized ~/ dsaKreuzerPerDukat;
  final remainder = normalized % dsaKreuzerPerDukat;
  if (remainder == 0) {
    return dukaten.toString();
  }

  final decimalDigits = remainder
      .toString()
      .padLeft(3, '0')
      .replaceFirst(RegExp(r'0+$'), '');
  return '$dukaten,$decimalDigits';
}

/// Formatiert Kreuzer als sichtbare Münzaufschlüsselung in D/S/K.
String formatDsaCurrencyBreakdown(int kreuzer) {
  final normalized = kreuzer < 0 ? 0 : kreuzer;
  final dukaten = normalized ~/ dsaKreuzerPerDukat;
  final afterDukaten = normalized % dsaKreuzerPerDukat;
  final silber = afterDukaten ~/ dsaKreuzerPerSilber;
  final kreuzerRemainder = afterDukaten % dsaKreuzerPerSilber;
  final parts = <String>[];

  if (dukaten > 0) {
    parts.add('$dukaten D');
  }
  if (silber > 0) {
    parts.add('$silber S');
  }
  if (kreuzerRemainder > 0) {
    parts.add('$kreuzerRemainder K');
  }

  return parts.isEmpty ? '0 D' : parts.join(' / ');
}

/// Addiert eine Kreuzerdifferenz auf einen Geldwert und gibt Dukaten-Text zurück.
///
/// Rückgaben werden bei `0` begrenzt; `null` signalisiert nicht lesbaren
/// Ausgangstext.
String? adjustDsaCurrencyText({
  required String rawValue,
  required int deltaKreuzer,
}) {
  final current = parseDsaCurrencyToKreuzer(rawValue);
  if (current == null) {
    return null;
  }

  final next = current + deltaKreuzer;
  return formatDsaCurrencyDukaten(next < 0 ? 0 : next);
}

int? _parseDecimalDukaten(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  var sign = 1;
  var unsigned = compact;
  if (unsigned.startsWith('-')) {
    sign = -1;
    unsigned = unsigned.substring(1);
  } else if (unsigned.startsWith('+')) {
    unsigned = unsigned.substring(1);
  }

  final normalized = unsigned.replaceAll(',', '.');
  if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(normalized)) {
    return null;
  }

  final parsed = double.tryParse(normalized);
  if (parsed == null) {
    return null;
  }
  return sign * dukatenToDsaKreuzer(parsed);
}

int? _parseCoinNotation(String value) {
  final pattern = RegExp(r'([+-]?\d+)\s*([A-Za-zÄÖÜäöüß]+)');
  var cursor = 0;
  var hasMatch = false;
  var total = 0;

  for (final match in pattern.allMatches(value)) {
    final separator = value.substring(cursor, match.start);
    if (!_isCoinSeparator(separator)) {
      return null;
    }

    final amountText = match.group(1);
    final unitText = match.group(2);
    final amount = int.tryParse(amountText ?? '');
    final factor = _coinFactor(unitText ?? '');
    if (amount == null || factor == null) {
      return null;
    }

    total += amount * factor;
    cursor = match.end;
    hasMatch = true;
  }

  final tail = value.substring(cursor);
  if (!hasMatch || !_isCoinSeparator(tail)) {
    return null;
  }
  return total;
}

bool _isCoinSeparator(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  final withoutPunctuation = normalized.replaceAll(RegExp(r'[,;/+\s]+'), '');
  return withoutPunctuation.isEmpty || withoutPunctuation == 'und';
}

int? _coinFactor(String unitText) {
  final unit = unitText.toLowerCase();
  if (unit == 'd' || unit.startsWith('dukat')) {
    return dsaKreuzerPerDukat;
  }
  if (unit == 's' || unit == 'st' || unit.startsWith('silber')) {
    return dsaKreuzerPerSilber;
  }
  if (unit == 'h' || unit.startsWith('heller')) {
    return dsaKreuzerPerHeller;
  }
  if (unit == 'k' || unit.startsWith('kreuzer')) {
    return 1;
  }
  return null;
}
