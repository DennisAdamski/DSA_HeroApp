import 'package:flutter/widgets.dart';

import 'package:dsa_heldenverwaltung/ui/widgets/platform_file_image_stub.dart'
    if (dart.library.io) 'package:dsa_heldenverwaltung/ui/widgets/platform_file_image_io.dart'
    as impl;

/// Erzeugt ein Image-Widget aus einem Dateipfad.
/// Auf Web wird [fallback] oder ein leeres Widget angezeigt.
Widget buildFileImage(
  String path, {
  BoxFit? fit,
  bool gaplessPlayback = false,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget? fallback,
}) {
  return impl.buildFileImage(
    path,
    fit: fit,
    gaplessPlayback: gaplessPlayback,
    errorBuilder: errorBuilder,
    fallback: fallback,
  );
}
