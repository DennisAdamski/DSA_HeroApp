import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/unlesbare_helden_quelle.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui_shared/unlesbare_helden_hinweis.dart';

class _RepositoryMitUnlesbaren extends FakeRepository
    implements UnlesbareHeldenQuelle {
  _RepositoryMitUnlesbaren(this.unlesbareHeldenEintraege);

  @override
  final List<UnlesbarerHeld> unlesbareHeldenEintraege;
}

void main() {
  const attribute = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );

  Future<void> pumpHinweis(WidgetTester tester, FakeRepository repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: UnlesbareHeldenHinweis()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ohne unlesbare Einträge bleibt der Hinweis unsichtbar', (
    tester,
  ) async {
    await pumpHinweis(
      tester,
      FakeRepository(
        heroes: const [
          HeroSheet(id: 'gut', name: 'Alrik', level: 1, attributes: attribute),
        ],
      ),
    );
    expect(
      find.byKey(const ValueKey('unlesbare-helden-hinweis')),
      findsNothing,
    );
  });

  testWidgets('nennt unlesbare Einträge mit Name oder Schlüssel', (
    tester,
  ) async {
    await pumpHinweis(
      tester,
      _RepositoryMitUnlesbaren(const [
        UnlesbarerHeld(schluessel: 'a1', name: 'Alrike'),
        UnlesbarerHeld(schluessel: 'b2'),
      ]),
    );
    expect(
      find.byKey(const ValueKey('unlesbare-helden-hinweis')),
      findsOneWidget,
    );
    expect(
      find.text('2 gespeicherte Helden können nicht gelesen werden'),
      findsOneWidget,
    );
    expect(find.textContaining('Betroffen: Alrike, b2.'), findsOneWidget);
  });

  test('ein leerer Rohname fällt auf den Schlüssel zurück', () {
    expect(const UnlesbarerHeld(schluessel: 'x', name: '  ').anzeigename, 'x');
  });
}
