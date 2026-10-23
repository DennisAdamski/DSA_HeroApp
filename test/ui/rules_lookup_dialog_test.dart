import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_settings_repository.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';
import 'package:dsa_heldenverwaltung/state/rules_index_providers.dart';
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

  group('Cloud-Laden im Hintergrund (SPIEL-04)', () {
    late _FesterSync sync;
    late List<RulesIndexSearch?> indexe;

    Future<void> zeige(
      WidgetTester tester, {
      bool angemeldet = true,
      RulesIndexSyncState zustand = const RulesIndexSyncState(),
      List<RulesIndexSearch?>? indexReihe,
    }) async {
      sync = _FesterSync(zustand);
      indexe = indexReihe ?? <RulesIndexSearch?>[null];
      var naechster = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            rulesIndexCloudAvailableProvider.overrideWithValue(true),
            rulesIndexSignedInProvider.overrideWithValue(angemeldet),
            rulesIndexRemoteConfigProvider.overrideWithValue(
              const RulesIndexRemoteConfig(),
            ),
            rulesIndexAutoSyncProvider.overrideWith(() => sync),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: RulesLookupDialog(
                oeffneIndex: () async {
                  final index = indexe[naechster.clamp(0, indexe.length - 1)];
                  naechster++;
                  return index;
                },
              ),
            ),
          ),
        ),
      );
      // Kein pumpAndSettle: ein laufender Fortschrittsbalken animiert ohne
      // Ende und ließe es nie zur Ruhe kommen.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    Finder schluessel(String name) => find.byKey(ValueKey<String>(name));

    testWidgets('angemeldet und bereit: ein Knopf startet das Laden', (
      tester,
    ) async {
      await zeige(tester);
      expect(schluessel('rules-lookup-cloud-bereit'), findsOneWidget);
      expect(find.text('Wissensbasis laden'), findsOneWidget);
      // Der NAS-Weg ist ersetzt, solange der Build die Cloud hat.
      expect(schluessel('rules-lookup-sync-button'), findsNothing);

      await tester.tap(schluessel('rules-lookup-cloud-button'));
      await tester.pump();
      expect(sync.starts, <bool>[true]);
    });

    testWidgets('ohne Anmeldung steht die Aufforderung da, ohne Knopf', (
      tester,
    ) async {
      await zeige(tester, angemeldet: false);
      expect(schluessel('rules-lookup-cloud-anmelden'), findsOneWidget);
      expect(schluessel('rules-lookup-cloud-button'), findsNothing);
    });

    testWidgets('beim Laden zeigt der Dialog den Fortschritt', (tester) async {
      await zeige(
        tester,
        zustand: const RulesIndexSyncState(
          phase: RulesIndexSyncPhase.downloading,
          received: 52 * 1048576,
          total: 117 * 1048576,
        ),
      );
      expect(schluessel('rules-lookup-cloud-laeuft'), findsOneWidget);
      expect(find.textContaining('52 von 117 MB'), findsOneWidget);
      final balken = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(balken.value, closeTo(52 / 117, 0.001));
      expect(find.textContaining('im Hintergrund'), findsOneWidget);
      expect(schluessel('rules-lookup-cloud-button'), findsNothing);
    });

    testWidgets('in der Vorbereitung ist der Fortschritt unbestimmt', (
      tester,
    ) async {
      await zeige(
        tester,
        zustand: const RulesIndexSyncState(
          phase: RulesIndexSyncPhase.preparing,
        ),
      );
      expect(find.text('Wird vorbereitet …'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    });

    testWidgets('ein Fehler steht im Dialog, der Knopf versucht es erneut', (
      tester,
    ) async {
      await zeige(
        tester,
        zustand: const RulesIndexSyncState(
          phase: RulesIndexSyncPhase.failed,
          message: 'Das Katalogpasswort passt nicht zum Server.',
        ),
      );
      expect(
        find.text('Das Katalogpasswort passt nicht zum Server.'),
        findsOneWidget,
      );
      expect(find.text('Erneut versuchen'), findsOneWidget);
      await tester.tap(schluessel('rules-lookup-cloud-button'));
      await tester.pump();
      expect(sync.starts, <bool>[true]);
    });

    testWidgets('eine fertige Installation öffnet die Suche von selbst', (
      tester,
    ) async {
      await zeige(
        tester,
        zustand: const RulesIndexSyncState(
          phase: RulesIndexSyncPhase.downloading,
          received: 1,
          total: 2,
        ),
        indexReihe: <RulesIndexSearch?>[null, _LeererIndex()],
      );
      expect(schluessel('rules-lookup-search-field'), findsNothing);

      sync.setze(
        const RulesIndexSyncState(phase: RulesIndexSyncPhase.done, revision: 1),
      );
      await tester.pumpAndSettle();

      expect(schluessel('rules-lookup-search-field'), findsOneWidget);
      expect(schluessel('rules-lookup-cloud-laeuft'), findsNothing);
    });

    testWidgets('Aktualisieren in der Suche fragt nur nach Neuem und meldet '
        '„schon aktuell“', (tester) async {
      await zeige(tester, indexReihe: <RulesIndexSearch?>[_LeererIndex()]);
      await tester.tap(schluessel('rules-lookup-sync-icon-button'));
      await tester.pump();
      expect(sync.starts, <bool>[false]);

      sync.setze(
        const RulesIndexSyncState(phase: RulesIndexSyncPhase.preparing),
      );
      await tester.pump();
      sync.setze(const RulesIndexSyncState(phase: RulesIndexSyncPhase.done));
      await tester.pump();

      expect(find.text('Die Wissensbasis ist aktuell.'), findsOneWidget);
    });

    testWidgets('während des Ladens ist Aktualisieren gesperrt', (
      tester,
    ) async {
      await zeige(
        tester,
        zustand: const RulesIndexSyncState(
          phase: RulesIndexSyncPhase.downloading,
          total: 10,
        ),
        indexReihe: <RulesIndexSearch?>[_LeererIndex()],
      );
      final knopf = tester.widget<IconButton>(
        schluessel('rules-lookup-sync-icon-button'),
      );
      expect(knopf.onPressed, isNull);
    });
  });
}

/// Hintergrundlader mit festem Zustand; zeichnet Starts auf.
class _FesterSync extends RulesIndexAutoSync {
  _FesterSync(this._anfang);

  final RulesIndexSyncState _anfang;
  final List<bool> starts = <bool>[];

  @override
  RulesIndexSyncState build() => _anfang;

  void setze(RulesIndexSyncState neu) => state = neu;

  @override
  Future<void> start({bool force = false}) async => starts.add(force);
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
