import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_appearance.dart';
import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/hero_avatar.dart';

HeroSheet _buildHeld({
  String rasse = '',
  String geschlecht = '',
  String haarfarbe = '',
  String augenfarbe = '',
}) {
  return HeroSheet(
    id: 'test-id',
    name: 'Testheld',
    level: 1,
    attributes: const Attributes(mu: 8, kl: 8, inn: 8, ch: 8, ff: 8, ge: 8, ko: 8, kk: 8),
    background: HeroBackground(rasse: rasse),
    appearance: HeroAppearance(
      geschlecht: geschlecht,
      haarfarbe: haarfarbe,
      augenfarbe: augenfarbe,
    ),
  );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('HeroAvatar', () {
    testWidgets('rendert ohne Fehler bei leeren Erscheinungsfeldern', (tester) async {
      await tester.pumpWidget(_wrap(HeroAvatar(hero: _buildHeld())));
      expect(find.byType(HeroAvatar), findsOneWidget);
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('rendert Elf weiblich mit blonden Haaren und grünen Augen', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HeroAvatar(
            hero: _buildHeld(
              rasse: 'Waldelf',
              geschlecht: 'weiblich',
              haarfarbe: 'blond',
              augenfarbe: 'grün',
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('rendert Zwerg männlich mit braunen Haaren (mit Bart)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HeroAvatar(
            hero: _buildHeld(
              rasse: 'Amboss-Zwerg',
              geschlecht: 'männlich',
              haarfarbe: 'braun',
              augenfarbe: 'grau',
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('rendert Mensch männlich mit schwarzen Haaren', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HeroAvatar(
            hero: _buildHeld(
              rasse: 'Mittelländer+',
              geschlecht: 'männlich',
              haarfarbe: 'schwarz',
              augenfarbe: 'braun',
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('rendert Ork neutral ohne Fehler', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HeroAvatar(
            hero: _buildHeld(rasse: 'Ork', geschlecht: 'divers'),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('SizedBox hat korrekte Standardgröße 48', (tester) async {
      await tester.pumpWidget(_wrap(HeroAvatar(hero: _buildHeld())));
      final box = tester.renderObject<RenderBox>(find.byType(SizedBox).first);
      expect(box.size.width, closeTo(48.0, 1.0));
      expect(box.size.height, closeTo(48.0, 1.0));
    });

    testWidgets('SizedBox hat korrekte benutzerdefinierte Größe', (tester) async {
      await tester.pumpWidget(_wrap(HeroAvatar(hero: _buildHeld(), size: 72.0)));
      final box = tester.renderObject<RenderBox>(
        find.ancestor(of: find.byType(CustomPaint), matching: find.byType(SizedBox)).first,
      );
      expect(box.size.width, closeTo(72.0, 1.0));
      expect(box.size.height, closeTo(72.0, 1.0));
    });
  });
}
