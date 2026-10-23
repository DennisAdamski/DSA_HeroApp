import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/rules_lookup_dialog.dart';

void main() {
  testWidgets(
    'zeigt zunaechst einen Ladeindikator und wechselt danach in einen '
    'Endzustand (Suche, Desktop- oder Web-Leerzustand)',
    (tester) async {
      // ProviderScope ist seit dem Server-Sync-Feature Pflicht: der Dialog
      // ist ein ConsumerStatefulWidget geworden (Zugriff auf Settings-
      // Provider beim Sync-Button-Tap), auch wenn dieser Test den Button
      // nicht betätigt und daher keine Provider-Overrides benötigt.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: RulesLookupDialog())),
        ),
      );

      // Vor dem ersten Frame nach initState ist openRulesIndexSearch()
      // noch nicht abgeschlossen: der asynchrone Ladezustand muss sichtbar
      // sein statt eines synchronen Sofort-Ergebnisses wie vor der
      // Web-Erweiterung.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final hasSearchField = find
          .byKey(const ValueKey('rules-lookup-search-field'))
          .evaluate()
          .isNotEmpty;
      final hasUnavailableNotice = find
          .textContaining('nicht gefunden')
          .evaluate()
          .isNotEmpty;
      final hasImportNotice = find
          .textContaining('noch nicht importiert')
          .evaluate()
          .isNotEmpty;
      expect(hasSearchField || hasUnavailableNotice || hasImportNotice, isTrue);
    },
  );

  group('Leerzustand ohne Index (SPIEL-04)', () {
    const konfiguriert = RulesIndexRemoteConfig(
      serverUrl: 'https://regeln.example/index.sqlite',
    );

    Future<_Sync> zeige(
      WidgetTester tester, {
      RulesIndexRemoteConfig config = const RulesIndexRemoteConfig(),
      RulesIndexSearch? index,
      Object? syncFehler,
    }) async {
      final sync = _Sync(index: index, fehler: syncFehler);
      final repo = _Settings();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rulesIndexRemoteConfigProvider.overrideWithValue(config),
            catalogContentVisibleProvider.overrideWithValue(true),
            settingsActionsProvider.overrideWithValue(SettingsActions(repo)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RulesLookupDialog(
                oeffneIndex: () async => null,
                syncService: sync,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sync;
    }

    Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

    testWidgets('mit Server: Download steht als Hauptweg bereit', (
      tester,
    ) async {
      await zeige(tester, config: konfiguriert);
      expect(find.textContaining('nicht gefunden'), findsOneWidget);
      expect(find.textContaining('vom Server'), findsWidgets);
      expect(schluessel('rules-lookup-sync-button'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ohne Server: ehrlicher Hinweis statt toter Knopf', (
      tester,
    ) async {
      await zeige(tester);
      expect(schluessel('rules-lookup-sync-button'), findsNothing);
      expect(find.textContaining('kein Regel-Server'), findsOneWidget);
    });

    testWidgets('ein Fehler beim Download steht im Dialog', (tester) async {
      await zeige(
        tester,
        config: konfiguriert,
        syncFehler: const RulesIndexDownloadException(
          RulesIndexDownloadErrorKind.network,
          'Server nicht erreichbar: x',
        ),
      );
      await tester.tap(schluessel('rules-lookup-sync-button'));
      await tester.pumpAndSettle();
      expect(find.text('Server nicht erreichbar: x'), findsOneWidget);
      // Der Knopf ist danach wieder bedienbar.
      expect(
        tester
            .widget<FilledButton>(schluessel('rules-lookup-sync-button'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('nach dem Download erscheint die Suche mit Stand', (
      tester,
    ) async {
      final sync = await zeige(
        tester,
        config: konfiguriert.copyWith(lastSyncedAt: DateTime(2026, 10, 20, 9)),
        index: _LeererIndex(),
      );
      await tester.tap(schluessel('rules-lookup-sync-button'));
      await tester.pumpAndSettle();
      expect(sync.aufrufe, 1);
      expect(schluessel('rules-lookup-search-field'), findsOneWidget);
      expect(find.text('Vom Server geladen am 20.10.2026'), findsOneWidget);
      expect(schluessel('rules-lookup-sync-icon-button'), findsOneWidget);
    });
  });
}

class _Sync extends RulesIndexSyncService {
  _Sync({this.index, this.fehler});

  final RulesIndexSearch? index;
  final Object? fehler;
  int aufrufe = 0;

  @override
  Future<RulesIndexSearch> syncFromServer(RulesIndexRemoteConfig config) async {
    aufrufe++;
    if (fehler != null) throw fehler!;
    return index!;
  }
}

class _LeererIndex implements RulesIndexSearch {
  @override
  List<RulesSearchHit> search(
    String query, {
    required Set<RulesSourceCategory> categories,
    int limit = 20,
  }) => const <RulesSearchHit>[];

  @override
  String loadChunkContext(int chunkId, {int window = 1}) => '';

  @override
  void dispose() {}
}

class _Settings implements HiveSettingsRepository {
  AppSettings settings = const AppSettings();

  @override
  AppSettings load() => settings;

  @override
  Future<void> save(AppSettings next) async {
    settings = next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
