import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/state/warte_auf_wert.dart';

// Gibt Tests einen [Ref], wie ihn Aktionsklassen im Provider bekommen.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  // Ersatz für `ref.read(provider.future)` (Regel 9, REV-27).
  group('warteAufWert', () {
    test('liefert den Wert eines FutureProviders', () async {
      final quelle = FutureProvider<int>((ref) async => 42);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final wert = await warteAufWert(container.read(_refProvider), quelle);

      expect(wert, 42);
    });

    test('endet mit dem Fehler eines scheiternden Providers', () async {
      final quelle = FutureProvider<int>(
        (ref) async => throw StateError('kaputt'),
        retry: (_, _) => null,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        warteAufWert(container.read(_refProvider), quelle),
        throwsA(isA<StateError>()),
      );
    });

    test('endet auch, wenn Riverpod den Fehler neu versucht', () async {
      final quelle = FutureProvider<int>(
        (ref) async => throw StateError('kaputt'),
        retry: (_, _) => const Duration(minutes: 1),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        warteAufWert(
          container.read(_refProvider),
          quelle,
        ).timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
      );
    });

    test('wartet auf einen später fertigen Wert', () async {
      final fertig = Completer<int>();
      final quelle = FutureProvider<int>((ref) => fertig.future);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ergebnis = warteAufWert(container.read(_refProvider), quelle);
      fertig.complete(7);

      expect(await ergebnis, 7);
    });
  });

  group('warteAufWertImWidget', () {
    testWidgets('wird auch nach dem Verlassen des Widgets erfüllt', (
      tester,
    ) async {
      final fertig = Completer<int>();
      final quelle = FutureProvider<int>((ref) => fertig.future);
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                widgetRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final antwort = warteAufWertImWidget(widgetRef, quelle);
      // Bildschirm verlassen, bevor der Provider fertig ist.
      await tester.pumpWidget(const ProviderScope(child: SizedBox()));
      fertig.complete(7);
      await tester.pump();
      await tester.pump();

      expect(await antwort, 7);
    });
  });
}
