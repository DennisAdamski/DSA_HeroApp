import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Wartet auf den nächsten fertigen Wert oder Fehler einer asynchronen Quelle.
///
/// Ersatz für `ref.read(provider.future)` (CLAUDE.md, Regel 9). Jene Future
/// hat in Riverpod 3 zwei Fallen:
///
/// - Scheitert der Provider, geht er in `AsyncLoading` **mit** angehängtem
///   Fehler (automatischer Neuversuch); die Future wird dann nie erfüllt,
///   auch ihr `onError` feuert nie.
/// - Ohne aktiven Listener wird ein Provider nach einer Änderung seiner
///   Abhängigkeiten nicht neu gebaut; ein `read(...future)` allein hält die
///   Kette nicht am Leben.
///
/// Das Abo löst beides: Es endet mit dem ersten Fehler (auch während eines
/// Neuversuchs) oder dem ersten fertigen Wert und hält die Kette bis dahin
/// aktiv. Ein Wert, der gerade neu geladen wird, gilt noch nicht als fertig.
///
/// [aktuellenStandEinbeziehen] muss nach einem `invalidate` `false` sein:
/// Der Provider trägt dann noch den Fehler des Vorlaufs, ein sofortiges
/// Auswerten meldete den Neuversuch augenblicklich als gescheitert.
Future<T> warteAufWert<T>(
  Ref ref,
  ProviderListenable<AsyncValue<T>> quelle, {
  bool aktuellenStandEinbeziehen = true,
}) => _warte<T>(
  (melde) => ref.listen<AsyncValue<T>>(
    quelle,
    (_, naechster) => melde(naechster),
    fireImmediately: aktuellenStandEinbeziehen,
  ),
);

/// Wie [warteAufWert], für Widgets mit einem [WidgetRef].
///
/// Das Abo hängt am [ProviderContainer] und nicht am Widget: `listenManual`
/// würde beim Verlassen des Bildschirms geschlossen, und die Future bliebe für
/// immer offen. So wird sie auch nach dem Dispose noch erfüllt.
///
/// Mit [zeitlimit] endet das Warten spätestens dann mit einer
/// [TimeoutException]; das hilft, wo eine Kette Fehler verschlucken kann.
Future<T> warteAufWertImWidget<T>(
  WidgetRef ref,
  ProviderListenable<AsyncValue<T>> quelle, {
  bool aktuellenStandEinbeziehen = true,
  Duration? zeitlimit,
}) {
  final container = ProviderScope.containerOf(ref.context, listen: false);
  return _warte<T>(
    (melde) => container.listen<AsyncValue<T>>(
      quelle,
      (_, naechster) => melde(naechster),
      fireImmediately: aktuellenStandEinbeziehen,
    ),
    zeitlimit: zeitlimit,
  );
}

Future<T> _warte<T>(
  ProviderSubscription<AsyncValue<T>> Function(
    void Function(AsyncValue<T> wert) melde,
  )
  abonniere, {
  Duration? zeitlimit,
}) {
  final ergebnis = Completer<T>();
  void melde(AsyncValue<T> wert) {
    if (ergebnis.isCompleted) return;
    final fehler = wert.error;
    if (fehler != null) {
      ergebnis.completeError(fehler, wert.stackTrace ?? StackTrace.current);
    } else if (wert.hasValue && !wert.isLoading) {
      ergebnis.complete(wert.requireValue);
    }
  }

  final abo = abonniere(melde);
  final future = zeitlimit == null
      ? ergebnis.future
      : ergebnis.future.timeout(zeitlimit);
  return future.whenComplete(abo.close);
}
