import 'package:package_info_plus/package_info_plus.dart';

import 'package:dsa_heldenverwaltung/data/feedback/feedback_platform_info.dart';
import 'package:dsa_heldenverwaltung/domain/app_build_info.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';

/// Laufzeitwerte, die ohne personenbezogene oder fachliche Daten auskommen.
class FeedbackRuntimeInfo {
  /// Erstellt eine unveränderliche, testbare Laufzeitbeschreibung.
  const FeedbackRuntimeInfo({
    required this.appVersion,
    required this.buildNumber,
    required this.commit,
    required this.builtAt,
    required this.platform,
    required this.operatingSystem,
    required this.operatingSystemVersion,
  });

  final String appVersion;
  final String buildNumber;
  final String commit;
  final String builtAt;
  final String platform;
  final String operatingSystem;
  final String operatingSystemVersion;

  /// Liest Paket- und Betriebssystemdaten ohne Gerätekennung oder Modell.
  static Future<FeedbackRuntimeInfo> load() async {
    final package = await PackageInfo.fromPlatform();
    final platform = loadFeedbackPlatformInfo();
    return FeedbackRuntimeInfo(
      appVersion: package.version,
      buildNumber: package.buildNumber,
      commit: AppBuildInfo.aktuell.commit,
      builtAt: AppBuildInfo.aktuell.zeit,
      platform: platform.platform,
      operatingSystem: platform.operatingSystem,
      operatingSystemVersion: platform.operatingSystemVersion,
    );
  }
}

/// Baut Vorschau und Payload aus derselben freigegebenen Datenquelle.
class FeedbackDiagnosticsCollector {
  /// Erstellt den Sammler mit einer injizierbaren Laufzeitbeschreibung.
  const FeedbackDiagnosticsCollector({required this.runtime});

  final FeedbackRuntimeInfo runtime;

  /// Liefert die für alle Meldearten sichtbaren Build-Metadaten.
  FeedbackBaseMetadata metadata() => FeedbackBaseMetadata(
    appVersion: runtime.appVersion,
    buildNumber: runtime.buildNumber,
    commit: runtime.commit,
    builtAt: runtime.builtAt,
    platform: runtime.platform,
  );

  /// Liefert das vollständig abwählbare Diagnosepaket eines Bugs.
  BugDiagnostics diagnostics({
    required String locale,
    required double viewportWidth,
    required double viewportHeight,
    required double devicePixelRatio,
    required String layoutClass,
    required String interfaceVariant,
    required String brightness,
    required String tableMode,
    required bool firebaseAvailable,
    required bool authenticated,
  }) => BugDiagnostics(
    operatingSystem: runtime.operatingSystem,
    operatingSystemVersion: runtime.operatingSystemVersion,
    locale: locale,
    viewportWidth: viewportWidth,
    viewportHeight: viewportHeight,
    devicePixelRatio: devicePixelRatio,
    layoutClass: layoutClass,
    interfaceVariant: interfaceVariant,
    brightness: brightness,
    tableMode: tableMode,
    firebaseAvailable: firebaseAvailable,
    authenticated: authenticated,
  );
}
