import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/epic_activation_dialog.dart';

void main() {
  const startAttributes = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );

  /// Oeffnet den Dialog und liefert das Ergebnis ueber [onResult] zurueck.
  Future<void> pumpDialog(
    WidgetTester tester, {
    required void Function(EpicActivationResult?) onResult,
    bool isEdit = false,
    Attributes initialMaxBonus = const Attributes.zero(),
    Attributes initialMainAttributes = const Attributes.zero(),
    String? initialPolicy,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  final result = await showDialog<EpicActivationResult>(
                    context: context,
                    builder: (_) => EpicActivationDialog(
                      currentValues: startAttributes,
                      effectiveStartAttributes: startAttributes,
                      isEdit: isEdit,
                      initialMaxBonus: initialMaxBonus,
                      initialMainAttributes: initialMainAttributes,
                      initialPolicy: initialPolicy,
                    ),
                  );
                  onResult(result);
                },
                child: const Text('Öffnen'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
  }

  /// Scrollt das Ziel in den sichtbaren Bereich und tippt es an.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Aktivierungsmodus startet ohne Auswahl und ohne Punkte', (
    tester,
  ) async {
    await pumpDialog(tester, onResult: (_) {});

    expect(find.text('Epischen Status aktivieren'), findsOneWidget);
    expect(find.text('Aktivieren'), findsOneWidget);
    expect(find.text('Vergeben: 0 / 5 Punkte'), findsOneWidget);

    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('epic-dialog-confirm')),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('Edit-Modus belegt Punkte, Haupteigenschaften und Policy vor', (
    tester,
  ) async {
    EpicActivationResult? result;
    await pumpDialog(
      tester,
      onResult: (value) => result = value,
      isEdit: true,
      initialMaxBonus: const Attributes.zero().copyWith(kl: 2, kk: 1),
      initialMainAttributes: const Attributes.zero().copyWith(kl: 1, ge: 1),
      initialPolicy: 'paktierer',
    );

    expect(find.text('Epischen Status bearbeiten'), findsOneWidget);
    expect(find.text('Speichern'), findsOneWidget);
    expect(find.text('Vergeben: 3 / 5 Punkte'), findsOneWidget);

    final mentalChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey<String>('epic-dialog-mental-kl')),
    );
    expect(mentalChip.selected, isTrue);
    final physicalChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey<String>('epic-dialog-physical-ge')),
    );
    expect(physicalChip.selected, isTrue);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('epic-dialog-confirm')),
    );

    expect(result, isNotNull);
    expect(result!.maxBonus.kl, 2);
    expect(result!.maxBonus.kk, 1);
    expect(result!.mainAttributes.kl, 1);
    expect(result!.mainAttributes.ge, 1);
    expect(result!.policy, 'paktierer');
  });

  testWidgets('fehlende Haupteigenschaften lassen sich nachtragen', (
    tester,
  ) async {
    EpicActivationResult? result;
    await pumpDialog(
      tester,
      onResult: (value) => result = value,
      isEdit: true,
      initialMaxBonus: const Attributes.zero().copyWith(mu: 2),
    );

    // Ohne beide Haupteigenschaften bleibt Speichern gesperrt.
    var confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('epic-dialog-confirm')),
    );
    expect(confirm.onPressed, isNull);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('epic-dialog-mental-mu')),
    );

    confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('epic-dialog-confirm')),
    );
    expect(confirm.onPressed, isNull);

    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('epic-dialog-physical-kk')),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey<String>('epic-dialog-confirm')),
    );

    expect(result, isNotNull);
    expect(result!.mainAttributes.mu, 1);
    expect(result!.mainAttributes.kk, 1);
    expect(result!.maxBonus.mu, 2);
  });
}
