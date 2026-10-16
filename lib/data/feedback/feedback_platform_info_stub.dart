import 'package:flutter/foundation.dart';

/// Liest auf Web nur nicht identifizierende Plattformangaben.
({String platform, String operatingSystem, String operatingSystemVersion})
loadFeedbackPlatformInfo() => (
  platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
  operatingSystem: kIsWeb ? 'Web' : defaultTargetPlatform.name,
  operatingSystemVersion: '',
);
