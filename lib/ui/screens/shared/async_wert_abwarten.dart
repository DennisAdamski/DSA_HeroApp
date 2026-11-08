import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:dsa_heldenverwaltung/state/warte_auf_wert.dart';

/// Wartet, bis [provider] einen Wert **oder** einen Fehler trägt.
///
/// Ersatz für `ref.read(provider.future)`: In Riverpod 3.2 wird diese Future
/// bei einem Fehler nie erfüllt (der Provider bleibt in `AsyncLoading` mit
/// angehängtem Fehler), und ohne Listener baut sich ein Provider nach einer
/// Abhängigkeitsänderung nicht neu. Das Abo hält die Kette aktiv, bis Wert
/// oder Fehler da sind; ein Fehler wird als Fehler der Future weitergereicht.
///
/// Die Katalogkette kann Fehler verschlucken, deshalb endet das Warten
/// spätestens nach [timeout] mit einer `TimeoutException`. Die Rechnung selbst
/// steht in `warteAufWertImWidget` (`state/warte_auf_wert.dart`).
Future<T> warteAufAsyncWert<T>(
  WidgetRef ref,
  ProviderListenable<AsyncValue<T>> provider, {
  Duration timeout = const Duration(seconds: 30),
}) => warteAufWertImWidget<T>(ref, provider, zeitlimit: timeout);
