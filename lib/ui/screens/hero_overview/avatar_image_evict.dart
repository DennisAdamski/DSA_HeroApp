// Plattformspezifische Cache-Invalidierung fuer Avatarbilder.
// Auf Desktop/Mobile leert der IO-Helper den FileImage-Cache fuer ein
// gerade ueberschriebenes Avatarbild. Auf Web ist die Operation ein No-Op.
export 'avatar_image_evict_io.dart'
    if (dart.library.html) 'avatar_image_evict_web.dart';
