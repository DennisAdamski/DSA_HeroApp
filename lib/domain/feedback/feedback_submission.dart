/// Fachlich getrennte Arten von öffentlichem App-Feedback.
enum FeedbackKind { bug, feature, rules }

/// Stabile, heldenunabhängige Herkunftsbereiche einer Meldung.
enum FeedbackSurface {
  heroSelection('heroSelection', 'Heldenauswahl'),
  overview('overview', 'Übersicht'),
  talents('talents', 'Talente'),
  combat('combat', 'Kampf'),
  magic('magic', 'Magie'),
  inventory('inventory', 'Inventar'),
  notes('notes', 'Notizen'),
  travelLog('travelLog', 'Reisebericht'),
  companions('companions', 'Begleiter'),
  group('group', 'Gruppe'),
  play('play', 'Spielmodus'),
  advancement('advancement', 'Entwicklung'),
  settings('settings', 'Einstellungen'),
  catalog('catalog', 'Katalogverwaltung'),
  other('other', 'Sonstiges');

  const FeedbackSurface(this.apiValue, this.label);

  /// Wert im versionierten Feedbackvertrag.
  final String apiValue;

  /// Nutzerlesbare Bezeichnung im Formular und Issue.
  final String label;
}

/// Nicht personenbezogene Build-Metadaten jeder Meldung.
class FeedbackBaseMetadata {
  /// Erstellt den gemeinsamen, sichtbaren App-Kontext.
  const FeedbackBaseMetadata({
    required this.appVersion,
    required this.buildNumber,
    required this.commit,
    required this.builtAt,
    required this.platform,
  });

  final String appVersion;
  final String buildNumber;
  final String commit;
  final String builtAt;
  final String platform;

  /// Serialisiert ausschließlich die öffentlich freigegebenen Basiswerte.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'commit': commit,
    'builtAt': builtAt,
    'platform': platform,
  };
}

/// Sichtbares und abwählbares Diagnosepaket ausschließlich für Bugs.
class BugDiagnostics {
  /// Erstellt eine Momentaufnahme ohne Gerätekennung oder Heldendaten.
  const BugDiagnostics({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.locale,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.devicePixelRatio,
    required this.layoutClass,
    required this.interfaceVariant,
    required this.brightness,
    required this.tableMode,
    required this.firebaseAvailable,
    required this.authenticated,
  });

  final String operatingSystem;
  final String operatingSystemVersion;
  final String locale;
  final double viewportWidth;
  final double viewportHeight;
  final double devicePixelRatio;
  final String layoutClass;
  final String interfaceVariant;
  final String brightness;
  final String tableMode;
  final bool firebaseAvailable;
  final bool authenticated;

  /// Serialisiert genau die in der Vorschau gezeigten Diagnosewerte.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'operatingSystem': operatingSystem,
    'operatingSystemVersion': operatingSystemVersion,
    'locale': locale,
    'viewportWidth': viewportWidth,
    'viewportHeight': viewportHeight,
    'devicePixelRatio': devicePixelRatio,
    'layoutClass': layoutClass,
    'interfaceVariant': interfaceVariant,
    'brightness': brightness,
    'tableMode': tableMode,
    'firebaseAvailable': firebaseAvailable,
    'authenticated': authenticated,
  };
}

/// Gemeinsamer Vertrag aller Feedbackmeldungen.
sealed class FeedbackSubmission {
  const FeedbackSubmission({
    required this.requestId,
    required this.title,
    required this.surface,
    required this.metadata,
  });

  /// Idempotenzschlüssel dieses Sendeversuchs.
  final String requestId;

  /// Öffentlicher Issue-Titel.
  final String title;

  /// Korrigierbarer, heldenunabhängiger App-Bereich.
  final FeedbackSurface surface;

  /// Sichtbarer Build-Kontext.
  final FeedbackBaseMetadata metadata;

  /// Fachliche Meldeart.
  FeedbackKind get kind;

  /// Serialisiert den versionierten Serververtrag.
  Map<String, dynamic> toJson();

  Map<String, dynamic> _baseJson() => <String, dynamic>{
    'schemaVersion': 1,
    'requestId': requestId,
    'kind': kind.name,
    'title': title.trim(),
    'surface': surface.apiValue,
    'metadata': metadata.toJson(),
  };
}

/// Strukturierte Bugmeldung mit optionaler Diagnose.
class BugFeedbackSubmission extends FeedbackSubmission {
  const BugFeedbackSubmission({
    required super.requestId,
    required super.title,
    required super.surface,
    required super.metadata,
    required this.actualBehavior,
    required this.expectedBehavior,
    this.reproductionSteps,
    this.diagnostics,
  });

  final String actualBehavior;
  final String expectedBehavior;
  final String? reproductionSteps;
  final BugDiagnostics? diagnostics;

  @override
  FeedbackKind get kind => FeedbackKind.bug;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._baseJson(),
    'actualBehavior': actualBehavior.trim(),
    'expectedBehavior': expectedBehavior.trim(),
    if (reproductionSteps?.trim().isNotEmpty ?? false)
      'reproductionSteps': reproductionSteps!.trim(),
    if (diagnostics != null) 'diagnostics': diagnostics!.toJson(),
  };
}

/// Strukturierte Feature-Anfrage mit Problem und Zielzustand.
class FeatureFeedbackSubmission extends FeedbackSubmission {
  const FeatureFeedbackSubmission({
    required super.requestId,
    required super.title,
    required super.surface,
    required super.metadata,
    required this.problem,
    required this.desiredBehavior,
  });

  final String problem;
  final String desiredBehavior;

  @override
  FeedbackKind get kind => FeedbackKind.feature;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._baseJson(),
    'problem': problem.trim(),
    'desiredBehavior': desiredBehavior.trim(),
  };
}

/// Strukturierte Regelfrage mit optionaler Fundstelle und Auslegung.
class RulesFeedbackSubmission extends FeedbackSubmission {
  const RulesFeedbackSubmission({
    required super.requestId,
    required super.title,
    required super.surface,
    required super.metadata,
    required this.question,
    this.source,
    this.interpretation,
  });

  final String question;
  final String? source;
  final String? interpretation;

  @override
  FeedbackKind get kind => FeedbackKind.rules;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ..._baseJson(),
    'question': question.trim(),
    if (source?.trim().isNotEmpty ?? false) 'source': source!.trim(),
    if (interpretation?.trim().isNotEmpty ?? false)
      'interpretation': interpretation!.trim(),
  };
}
