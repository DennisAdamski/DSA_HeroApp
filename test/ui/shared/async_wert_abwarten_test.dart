import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/screens/shared/async_wert_abwarten.dart';

void main() {
  Future<WidgetRef> baueRef(WidgetTester tester) async {
    late WidgetRef gefangen;
    final kind = Consumer(
      builder: (context, ref, _) {
        gefangen = ref;
        return const SizedBox.shrink();
      },
    );
    await tester.pumpWidget(ProviderScope(child: kind));
    return gefangen;
  }

  testWidgets('liefert den Wert eines geladenen Providers', (tester) async {
    final provider = FutureProvider<int>((ref) async => 42);
    final ref = await baueRef(tester);

    final ergebnis = warteAufAsyncWert(ref, provider);
    await tester.pump();

    expect(await ergebnis, 42);
  });

  testWidgets('beendet das Warten bei einem Fehler des Providers', (
    tester,
  ) async {
    final provider = FutureProvider<int>(
      (ref) async => throw StateError('Katalog kaputt'),
    );
    final ref = await baueRef(tester);

    Object? fehler;
    final ergebnis = warteAufAsyncWert(
      ref,
      provider,
    ).then<void>((_) {}, onError: (Object error) => fehler = error);
    await tester.pump();
    await ergebnis;

    expect(fehler, isA<StateError>());
  });

  testWidgets('beendet das Warten spätestens nach dem Timeout', (tester) async {
    final nieFertig = Completer<int>();
    final provider = FutureProvider<int>((ref) => nieFertig.future);
    final ref = await baueRef(tester);

    Object? fehler;
    final ergebnis = warteAufAsyncWert(
      ref,
      provider,
      timeout: const Duration(seconds: 1),
    ).then<void>((_) {}, onError: (Object error) => fehler = error);
    await tester.pump(const Duration(seconds: 2));
    await ergebnis;

    expect(fehler, isA<TimeoutException>());
  });

  testWidgets('wartet auf den Wert eines Providers mit AsyncValue', (
    tester,
  ) async {
    final quelle = FutureProvider<String>((ref) async => 'Held-Katalog');
    final abgeleitet = Provider<AsyncValue<String>>((ref) => ref.watch(quelle));
    final ref = await baueRef(tester);

    // Abgeleitete Provider baut Riverpod mit dem nächsten Frame neu; erst
    // die Frames treiben das Abo weiter, daher kein direktes `await`.
    String? wert;
    unawaited(warteAufAsyncWert(ref, abgeleitet).then((w) => wert = w));
    await tester.pump();
    await tester.pump();

    expect(wert, 'Held-Katalog');
  });
}
