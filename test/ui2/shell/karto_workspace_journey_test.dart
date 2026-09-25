import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/inspector/widgets/inspector_attribute_card.dart';

import 'karto_acceptance_support.dart';
import 'karto_test_support.dart';

void main() {
  testWidgets(
    'Held öffnen, würfeln, korrigieren, planen und einmal übernehmen',
    (tester) async {
      final hero = testHero().copyWith(apAvailable: 1375, apTotal: 1875);
      final repository = AcceptanceRepository(heroes: [hero]);
      final container = await pumpAcceptanceWorkspace(
        tester,
        repository: repository,
        size: const Size(1440, 1200),
      );
      await tester.tap(
        find.byKey(ValueKey<String>('karto-heldenwahl-held-${hero.id}')),
      );
      await tester.pumpAndSettle();
      expect(container.read(selectedHeroIdProvider), hero.id);

      await tester.tap(find.byKey(const ValueKey('inspector-probe-attr-MU')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Würfeln').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schließen'));
      await tester.pumpAndSettle();
      expect(repository.stateWrites, hasLength(1));
      final log = repository.stateWrites.single.diceLog.single;
      expect(log.title, contains('MU'));
      expect(find.text(log.title), findsWidgets);
      expect(repository.heroWrites, isEmpty);

      await selectAcceptanceMode(tester, 'Held verwalten');
      await pressAcceptanceAction(tester, 'Bearbeiten');
      await tester.enterText(
        find.byKey(const ValueKey('overview-field-name')),
        'Rondra von Gareth',
      );
      await pressAcceptanceAction(tester, 'Speichern');
      expect(repository.heroWrites, hasLength(1));
      expect(repository.heroWrites.single.name, 'Rondra von Gareth');

      await selectAcceptanceMode(tester, 'Entwicklung planen');
      final planAction = find.byKey(
        const ValueKey('advancement-plan-attribute-mu'),
      );
      await tester.ensureVisible(planAction);
      await tester.tap(planAction);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vormerken'));
      await tester.pumpAndSettle();
      final session = container.read(advancementSessionProvider(hero.id))!;
      expect(session.entries, hasLength(1));
      expect(repository.heroWrites, hasLength(1));
      final storedBeforeCommit = (await repository.loadHeroById(hero.id))!;
      expect(storedBeforeCommit.attributes.toJson(), hero.attributes.toJson());

      await selectAcceptanceMode(tester, 'Spielen');
      final card = tester.widget<InspectorAttributeCard>(
        find.byKey(const ValueKey('inspector-probe-attr-MU')),
      );
      expect(card.value, hero.attributes.mu);
      await selectAcceptanceMode(tester, 'Held verwalten');
      expect(find.text('Zur Planung'), findsOneWidget);
      expect(find.byKey(const ValueKey('overview-field-name')), findsNothing);
      await tester.tap(find.text('Zur Planung'));
      await tester.pumpAndSettle();
      expect(
        container.read(advancementSessionProvider(hero.id))!.sessionId,
        session.sessionId,
      );
      await tester.tap(find.byKey(const ValueKey('karto-plan-commit')));
      await tester.pumpAndSettle();
      expect(repository.heroWrites, hasLength(2));
      final saved = (await repository.loadHeroById(hero.id))!;
      expect(saved.attributes.toJson(), session.preview.attributes.toJson());
      expect(saved.apAvailable, session.preview.apAvailable);
      expect(saved.advancementHistory.single.id, session.entries.single.id);
      expect(container.read(advancementSessionProvider(hero.id)), isNull);
      expect(find.text('Entwicklung übernommen.'), findsOneWidget);
      final updatedCard = tester.widget<InspectorAttributeCard>(
        find.byKey(const ValueKey('inspector-probe-attr-MU')),
      );
      expect(updatedCard.value, session.preview.attributes.mu);
      final savedLog = (await repository.loadHeroState(hero.id))!
          .diceLog
          .single;
      expect(savedLog.toJson(), log.toJson());
      expect(tester.takeException(), isNull);
    },
  );
}
