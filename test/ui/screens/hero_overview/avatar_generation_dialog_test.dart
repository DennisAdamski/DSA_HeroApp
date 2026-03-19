import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_style.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/avatar_generation_dialog.dart';

void main() {
  HeroSheet buildHero() {
    return HeroSheet(
      id: 'hero-1',
      name: 'Laila',
      level: 1,
      attributes: const Attributes(
        mu: 11,
        kl: 11,
        inn: 11,
        ch: 11,
        ff: 11,
        ge: 11,
        ko: 11,
        kk: 11,
      ),
      background: const HeroBackground(
        rasse: 'Halbelfe',
        kultur: 'Aranien',
        profession: 'Balayan',
      ),
      appearance: const HeroAppearance(
        geschlecht: 'Weiblich',
        haarfarbe: 'Weissblond',
        augenfarbe: 'Hellblau',
      ),
    );
  }

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [avatarApiClientProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: AvatarGenerationDialog(heroId: 'hero-1', hero: buildHero()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextField promptField(WidgetTester tester) {
    return tester.widget<TextField>(
      find.byKey(const ValueKey<String>('avatar-generation-prompt-field')),
    );
  }

  group('AvatarGenerationDialog', () {
    testWidgets(
      'stilwechsel regeneriert Auto-Prompt vor manueller Bearbeitung',
      (tester) async {
        await pumpDialog(tester);

        expect(
          promptField(tester).controller!.text,
          contains(AvatarStyle.fantasyIllustration.promptFragment),
        );

        await tester.tap(find.text(AvatarStyle.watercolor.displayName));
        await tester.pumpAndSettle();

        expect(
          promptField(tester).controller!.text,
          contains(AvatarStyle.watercolor.promptFragment),
        );
      },
    );

    testWidgets('manuelle Aenderungen bleiben erhalten bis zum Reset', (
      tester,
    ) async {
      await pumpDialog(tester);

      await tester.enterText(
        find.byKey(const ValueKey<String>('avatar-generation-prompt-field')),
        'Custom prompt',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(AvatarStyle.watercolor.displayName));
      await tester.pumpAndSettle();

      expect(promptField(tester).controller!.text, 'Custom prompt');

      final resetFinder = find.byKey(
        const ValueKey<String>('avatar-generation-reset-prompt'),
      );
      await tester.ensureVisible(resetFinder);
      await tester.tap(resetFinder);
      await tester.pumpAndSettle();

      final resetPrompt = promptField(tester).controller!.text;
      expect(resetPrompt, contains(AvatarStyle.watercolor.promptFragment));
      expect(resetPrompt, isNot('Custom prompt'));
    });
  });
}
