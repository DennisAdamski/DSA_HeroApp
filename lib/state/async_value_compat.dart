import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kompatibilitaets-Getter fuer AsyncValue-Zugriffe im bestehenden Code.
///
/// Gibt den Wert nur dann zurueck, wenn ein Value vorliegt. Bei Loading/Error
/// wird `null` geliefert.
extension AsyncValueCompatX<T> on AsyncValue<T> {
  T? get valueOrNull => hasValue ? value : null;
}
