import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asset-Pfad der Lizenz des BlazeFace-Modells (Apache 2.0).
const String kBlazeFaceLizenzAsset = 'assets/models/LICENSE_blazeface.txt';

/// Meldet die Modelllizenz bei der Flutter-Lizenzseite an.
///
/// Das Modell ist ein Asset und kein Pub-Paket, seine Lizenz erscheint deshalb
/// nicht von selbst unter `showLicensePage`.
void registriereBlazeFaceLizenz() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(kBlazeFaceLizenzAsset);
    yield LicenseEntryWithLineBreaks(const <String>[
      'BlazeFace (MediaPipe Face Detector)',
    ], text);
  });
}
