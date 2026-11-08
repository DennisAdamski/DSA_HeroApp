/// Zeitpunkt eines Abgleichs als kurzer Text, in beiden Oberflächen gleich.
///
/// Am selben Tag „um 14:03“, sonst „am 07.11. 14:03“, in einem anderen Jahr
/// „am 07.11.2025 14:03“. Absolut statt „vor 5 Minuten“: ein relativer Text
/// bliebe zwischen zwei Abgleichen veraltet stehen.
String formatiereSyncZeitpunkt(DateTime zeitpunkt, {required DateTime jetzt}) {
  final lokal = zeitpunkt.toLocal();
  final heute = jetzt.toLocal();
  String zwei(int zahl) => zahl.toString().padLeft(2, '0');
  final uhr = '${zwei(lokal.hour)}:${zwei(lokal.minute)}';
  final selberTag =
      lokal.year == heute.year &&
      lokal.month == heute.month &&
      lokal.day == heute.day;
  if (selberTag) return 'um $uhr';
  final tag = '${zwei(lokal.day)}.${zwei(lokal.month)}.';
  final jahr = lokal.year == heute.year ? '' : '${lokal.year}';
  return 'am $tag$jahr $uhr';
}
