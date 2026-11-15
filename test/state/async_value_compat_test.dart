import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';

void main() {
  // Liest über das `Ref` eines Providers, wie es die Aktionsklassen tun.
  Future<T> warte<T>(
    ProviderContainer container,
    FutureProvider<T> provider, {
    Duration zeitlimit = const Duration(seconds: 2),
  }) {
    final leser = Provider<Future<T>>(
      (ref) => warteAufAsyncProvider(ref, provider, zeitlimit: zeitlimit),
    );
    return container.read(leser);
  }

  test('liefert den Wert, sobald er da ist', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final provider = FutureProvider<int>((ref) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return 42;
    });

    expect(await warte(container, provider), 42);
  });

  test('endet bei einem Fehler des Providers mit diesem Fehler', () async {
    // Riverpod wiederholt gescheiterte Provider; `provider.future` endete
    // dabei nie.
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);
    final provider = FutureProvider<int>((ref) async {
      throw StateError('kaputt');
    });

    await expectLater(warte(container, provider), throwsStateError);
  });

  test('endet nach dem Zeitlimit, wenn nichts kommt', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final nie = Completer<int>();
    final provider = FutureProvider<int>((ref) => nie.future);

    await expectLater(
      warte(container, provider, zeitlimit: const Duration(milliseconds: 30)),
      throwsA(isA<TimeoutException>()),
    );
  });
}
