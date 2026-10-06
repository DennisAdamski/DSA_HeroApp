/// Kennung des laufenden Builds, damit sichtbar ist, welcher Stand geladen ist.
///
/// Die Web-CI und `tool/deploy_web.ps1` betten Commit und Bauzeit per
/// `--dart-define` ein. Ein Build ohne diese Angaben (etwa `flutter run`)
/// gilt als lokaler Entwicklungsstand.
class AppBuildInfo {
  const AppBuildInfo({this.commit = '', this.zeit = ''});

  /// Kennung des aktuell laufenden Builds.
  static const AppBuildInfo aktuell = AppBuildInfo(
    commit: String.fromEnvironment('BUILD_COMMIT'),
    zeit: String.fromEnvironment('BUILD_TIME'),
  );

  /// Git-Commit des Builds, bei uncommitteten Änderungen mit `-dirty`.
  final String commit;

  /// Bauzeit als ISO-8601-Zeitstempel (UTC).
  final String zeit;

  /// Commit in der üblichen Kurzform von sieben Zeichen; ein Zusatz wie
  /// `-dirty` bleibt erhalten.
  String get kurzerCommit {
    final trenner = commit.indexOf('-');
    final hash = trenner < 0 ? commit : commit.substring(0, trenner);
    final zusatz = trenner < 0 ? '' : commit.substring(trenner);
    return '${hash.length > 7 ? hash.substring(0, 7) : hash}$zusatz';
  }

  /// Anzeigetext, z. B. `e92ff9f · 05.10.2026 14:32`.
  ///
  /// Die Bauzeit erscheint in der lokalen Zeitzone des Geräts.
  String get anzeige {
    if (commit.isEmpty) return 'Lokaler Entwicklungsstand';
    final gebaut = DateTime.tryParse(zeit)?.toLocal();
    if (gebaut == null) return kurzerCommit;
    return '$kurzerCommit · ${_zweistellig(gebaut.day)}.'
        '${_zweistellig(gebaut.month)}.${gebaut.year} '
        '${_zweistellig(gebaut.hour)}:${_zweistellig(gebaut.minute)}';
  }
}

String _zweistellig(int wert) => wert.toString().padLeft(2, '0');
