import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Wartet, bis [provider] einen Wert **oder** einen Fehler trägt.
///
/// Ersatz für `ref.read(provider.future)`: In Riverpod 3.2 wird diese Future
/// bei einem Fehler nie erfüllt (der Provider bleibt in `AsyncLoading` mit
/// angehängtem Fehler), und ohne Listener baut sich ein Provider nach einer
/// Abhängigkeitsänderung nicht neu. Das Abo hält die Kette aktiv, bis Wert
/// oder Fehler da sind; ein Fehler wird als Fehler der Future weitergereicht.
///
/// Die Katalogkette kann Fehler verschlucken, deshalb endet das Warten
/// spätestens nach [timeout] mit einer [TimeoutException].
/// Muster: `_awaitCatalogReady` in `heroes_home_screen.dart`.
Future<T> warteAufAsyncWert<T>(
  WidgetRef ref,
  ProviderListenable<AsyncValue<T>> provider, {
  Duration timeout = const Duration(seconds: 30),
}) {
  final completer = Completer<T>();

  void settle(AsyncValue<T> value) {
    if (completer.isCompleted) {
      return;
    }
    final error = value.error;
    if (error != null) {
      completer.completeError(error, value.stackTrace ?? StackTrace.current);
    } else if (value.hasValue) {
      completer.complete(value.requireValue);
    }
  }

  final subscription = ref.listenManual<AsyncValue<T>>(
    provider,
    (_, next) => settle(next),
    fireImmediately: true,
  );
  return completer.future.timeout(timeout).whenComplete(subscription.close);
}
