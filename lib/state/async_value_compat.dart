import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Kompatibilitaets-Getter fuer AsyncValue-Zugriffe im bestehenden Code.
///
/// Gibt den Wert nur dann zurueck, wenn ein Value vorliegt. Bei Loading/Error
/// wird `null` geliefert.
extension AsyncValueCompatX<T> on AsyncValue<T> {
  T? get valueOrNull => hasValue ? value : null;
}

/// Höchstdauer, die [warteAufAsyncProvider] auf Wert oder Fehler wartet.
const Duration kAsyncProviderWartezeit = Duration(seconds: 30);

/// Wartet auf den Wert eines asynchronen Providers, ohne `provider.future`.
///
/// `ref.read(provider.future)` endet in Riverpod 3 nicht, wenn der Provider
/// scheitert (er bleibt im Ladezustand mit angehängtem Fehler), und ein
/// Provider ohne aktiven Listener wird nach einer Änderung seiner
/// Abhängigkeiten nicht neu gebaut. Das Abo liefert Wert **und** Fehler und
/// hält die Kette bis dahin am Leben. Ein vorhandener Wert gilt auch während
/// eines Neuladens; ohne Wert endet das Warten mit dem Fehler des Providers
/// oder nach [zeitlimit] mit einer [TimeoutException].
Future<T> warteAufAsyncProvider<T>(
  Ref ref,
  ProviderListenable<AsyncValue<T>> provider, {
  Duration zeitlimit = kAsyncProviderWartezeit,
}) {
  final ergebnis = Completer<T>();
  final abo = ref.listen<AsyncValue<T>>(
    provider,
    (_, naechster) => _erledige(ergebnis, naechster),
    fireImmediately: true,
  );
  return ergebnis.future.timeout(zeitlimit).whenComplete(abo.close);
}

/// Wie [warteAufAsyncProvider] aus einem Widget heraus.
Future<T> warteAufAsyncProviderImWidget<T>(
  WidgetRef ref,
  ProviderListenable<AsyncValue<T>> provider, {
  Duration zeitlimit = kAsyncProviderWartezeit,
}) {
  final ergebnis = Completer<T>();
  final abo = ref.listenManual<AsyncValue<T>>(
    provider,
    (_, naechster) => _erledige(ergebnis, naechster),
    fireImmediately: true,
  );
  return ergebnis.future.timeout(zeitlimit).whenComplete(abo.close);
}

void _erledige<T>(Completer<T> ergebnis, AsyncValue<T> wert) {
  if (ergebnis.isCompleted) {
    return;
  }
  if (wert.hasValue) {
    ergebnis.complete(wert.value as T);
    return;
  }
  final fehler = wert.error;
  if (fehler != null) {
    ergebnis.completeError(fehler, wert.stackTrace ?? StackTrace.current);
  }
}
