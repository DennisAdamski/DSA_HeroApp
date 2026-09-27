import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_workspace.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

import 'karto_acceptance_support.dart';
import 'karto_test_support.dart';

void main() {
  testWidgets('Bestandsliste erreicht Import und Export aus dem UI2-Menü', (
    tester,
  ) async {
    final repository = AcceptanceRepository(heroes: [testHero()]);
    final gateway = _TransferGateway();
    await pumpAcceptanceWorkspace(
      tester,
      repository: repository,
      selectedHeroId: 'rondra',
      transferGateway: gateway,
    );
    await _openMenu(tester, 'Helden verwalten');
    expect(find.byType(HeroesHomeScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.upload_file).first);
    await tester.pumpAndSettle();
    expect(gateway.exported, contains('Rondra'));
    await tester.tap(find.byIcon(Icons.download).first);
    await tester.pumpAndSettle();
    expect(gateway.importCalls, 1);
    expect(repository.heroWrites, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HeroesHomeScreen), findsNothing);
    expect(find.byTooltip('Entwicklung planen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Einstellungen bieten Konto, Darstellung und Katalogwege', (
    tester,
  ) async {
    final repository = AcceptanceRepository(heroes: [testHero()]);
    await pumpAcceptanceWorkspace(
      tester,
      repository: repository,
      selectedHeroId: 'rondra',
    );
    await _openMenu(tester, 'Einstellungen');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Konto & Sync'), findsWidgets);
    expect(find.text('Darstellung'), findsWidgets);
    expect(find.text('Hausregeln'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(repository.heroWrites, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Held öffnen aus der Bestandsliste bleibt in Kartograph', (
    tester,
  ) async {
    // Frueher legte die Liste den klassischen Arbeitsbereich darueber; unter
    // Kartograph waehlt sie den Helden fuer den eigenen Workspace.
    final repository = AcceptanceRepository(
      heroes: [testHero(), testHero('alrik', 'Alrik')],
    );
    final container = await pumpAcceptanceWorkspace(
      tester,
      repository: repository,
      selectedHeroId: 'rondra',
    );
    await _openMenu(tester, 'Helden verwalten');
    expect(find.byType(HeroesHomeScreen), findsOneWidget);
    await tester.tap(find.text('Alrik').first);
    await tester.pumpAndSettle();
    final oeffnen = find.text('Held öffnen');
    if (oeffnen.evaluate().isNotEmpty) {
      await tester.tap(oeffnen.first);
      await tester.pumpAndSettle();
    }
    expect(container.read(selectedHeroIdProvider), 'alrik');
    expect(find.byType(HeroesHomeScreen), findsNothing);
    expect(find.byType(HeroWorkspaceScreen), findsNothing);
    expect(find.byType(KartoWorkspace), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Einstellungen liegen unter Kartograph auf Papier', (
    tester,
  ) async {
    await pumpAcceptanceWorkspace(
      tester,
      repository: AcceptanceRepository(heroes: [testHero()]),
      selectedHeroId: 'rondra',
    );
    await _openMenu(tester, 'Einstellungen');
    expect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(KartoPapier),
      ),
      findsOneWidget,
    );
  });
}

// Betätigt den tatsächlichen geschützten Menüpfad des Workspace.
Future<void> _openMenu(WidgetTester tester, String action) async {
  await tester.tap(
    find.byTooltip('Workspace-Menü'),
    kind: PointerDeviceKind.mouse,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

// Nur die Betriebssystem-Dateiauswahl wird ersetzt; Exportdaten baut HeroActions.
class _TransferGateway implements HeroTransferFileGateway {
  String? exported;
  int importCalls = 0;

  @override
  Future<HeroTransferExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    exported = jsonPayload;
    return const HeroTransferExportOutcome(
      result: HeroTransferExportResult.savedToFile,
    );
  }

  @override
  Future<String?> pickImportJson() async {
    importCalls++;
    return null;
  }
}
