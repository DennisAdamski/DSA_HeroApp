import 'dart:io';

import 'package:flutter/widgets.dart';

Widget buildFileImage(
  String path, {
  BoxFit? fit,
  bool gaplessPlayback = false,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  Widget? fallback,
}) {
  return Image.file(
    File(path),
    fit: fit,
    gaplessPlayback: gaplessPlayback,
    errorBuilder: errorBuilder,
  );
}
