import 'dart:io';

/// Liest Betriebssystem und Version ohne Gerätekennung oder Modell.
({String platform, String operatingSystem, String operatingSystemVersion})
loadFeedbackPlatformInfo() => (
  platform: Platform.operatingSystem,
  operatingSystem: Platform.operatingSystem,
  operatingSystemVersion: Platform.operatingSystemVersion,
);
