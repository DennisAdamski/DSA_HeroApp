import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';

Widget _buildHost({
  required TargetPlatform platform,
  required void Function(BuildContext) onPressed,
}) {
  return MaterialApp(
    theme: ThemeData(platform: platform),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => onPressed(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Widget _sampleDialog() => const AdaptiveInputDialog(
      title: 'Test-Dialog',
      content: SizedBox(
        height: 80,
        child: TextField(
          key: ValueKey<String>('input'),
          decoration: InputDecoration(labelText: 'Eingabe'),
        ),
      ),
      actions: [Text('Speichern')],
    );

void main() {
  group('showAdaptiveInputDialog', () {
    testWidgets('rendert auf iOS als BottomSheet', (tester) async {
      await tester.pumpWidget(
        _buildHost(
          platform: TargetPlatform.iOS,
          onPressed: (ctx) => showAdaptiveInputDialog<void>(
            context: ctx,
            builder: (_) => _sampleDialog(),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Test-Dialog'), findsOneWidget);
    });

    testWidgets('rendert auf macOS als BottomSheet', (tester) async {
      await tester.pumpWidget(
        _buildHost(
          platform: TargetPlatform.macOS,
          onPressed: (ctx) => showAdaptiveInputDialog<void>(
            context: ctx,
            builder: (_) => _sampleDialog(),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('rendert auf Android als zentrierten Dialog', (tester) async {
      await tester.pumpWidget(
        _buildHost(
          platform: TargetPlatform.android,
          onPressed: (ctx) => showAdaptiveInputDialog<void>(
            context: ctx,
            builder: (_) => _sampleDialog(),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Test-Dialog'), findsOneWidget);
    });

    testWidgets('BottomSheet-Inhalt erhaelt Bottom-Padding aus viewInsets',
        (tester) async {
      const keyboardInset = 320.0;
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboardInset * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        _buildHost(
          platform: TargetPlatform.iOS,
          onPressed: (ctx) => showAdaptiveInputDialog<void>(
            context: ctx,
            builder: (_) => _sampleDialog(),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final paddings = tester
          .widgetList<Padding>(find.byType(Padding))
          .where(
            (p) =>
                p.padding is EdgeInsets &&
                (p.padding as EdgeInsets).bottom == keyboardInset &&
                (p.padding as EdgeInsets).top == 0 &&
                (p.padding as EdgeInsets).left == 0 &&
                (p.padding as EdgeInsets).right == 0,
          );
      expect(
        paddings,
        isNotEmpty,
        reason: 'BottomSheet-Inhalt muss viewInsets.bottom als Padding setzen',
      );
    });
  });

  group('showAdaptiveDetailSheet', () {
    testWidgets('Detail-Sheet erhaelt viewInsets-Padding auf iOS',
        (tester) async {
      const keyboardInset = 280.0;
      tester.view.viewInsets = FakeViewPadding(
        bottom: keyboardInset * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        _buildHost(
          platform: TargetPlatform.iOS,
          onPressed: (ctx) => showAdaptiveDetailSheet<void>(
            context: ctx,
            builder: (_) => const SizedBox(
              height: 200,
              child: Center(child: Text('Detail')),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final paddings = tester
          .widgetList<Padding>(find.byType(Padding))
          .where(
            (p) =>
                p.padding is EdgeInsets &&
                (p.padding as EdgeInsets).bottom == keyboardInset &&
                (p.padding as EdgeInsets).top == 0 &&
                (p.padding as EdgeInsets).left == 0 &&
                (p.padding as EdgeInsets).right == 0,
          );
      expect(
        paddings,
        isNotEmpty,
        reason:
            'DraggableScrollableSheet-Inhalt muss viewInsets.bottom als '
            'Padding setzen, damit die Soft-Tastatur Eingaben nicht verdeckt',
      );
    });
  });
}
