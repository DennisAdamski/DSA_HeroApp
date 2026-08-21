import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/app_layout.dart';
import 'package:dsa_heldenverwaltung/ui/config/platform_adaptive.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/home/hero_home_tablet_panels.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_import_export_actions.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_empty_state.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_page_scaffold.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_split_view.dart';

/// Startscreen fuer die Heldenauswahl mit iPad-tauglicher Vorschau.
class HeroesHomeScreen extends ConsumerStatefulWidget {
  /// Erstellt die Heldenzentrale mit adaptivem Tablet-Layout.
  const HeroesHomeScreen({super.key});

  @override
  ConsumerState<HeroesHomeScreen> createState() => _HeroesHomeScreenState();
}

class _HeroesHomeScreenState extends ConsumerState<HeroesHomeScreen> {
  /// Wartezeit, bevor der Vorbereitungsdialog ueberhaupt erscheint.
  ///
  /// Ein vorgewaermter Katalog ist sofort da; ein aufblitzender Dialog waere
  /// stoerender als die kurze Verzoegerung.
  static const Duration _catalogDialogDelay = Duration(milliseconds: 120);

  /// Obergrenze, ab der ein haengender Ladevorgang als Fehlschlag gilt.
  static const Duration _catalogTimeout = Duration(seconds: 20);

  Future<void>? _catalogPrewarmFuture;
  bool _catalogPrewarmScheduled = false;

  // Teilt einen einzigen Katalog-Load zwischen Home-Prewarm und Heldenoeffnung.
  //
  // Fehler werden hier bewusst **nicht** mehr geschluckt: Der
  // Vorbereitungsdialog muss benennen koennen, warum es klemmt. Reine
  // Vorwaerm-Aufrufe ohne Dialog haengen sich selbst ein `catchError` an.
  Future<void> _startCatalogPrewarm() {
    return _catalogPrewarmFuture ??= _awaitCatalogReady();
  }

  /// Wartet, bis der Regelkatalog einen Wert **oder** einen Fehler hat.
  ///
  /// Bewusst ueber `listenManual` statt ueber `rulesCatalogProvider.future`.
  /// In Riverpod 3.2 hat `.future` zwei Eigenschaften, die zusammen genau den
  /// beobachteten Dauer-Ladebalken erzeugen:
  ///
  /// - Scheitert der Provider, geht er in `AsyncLoading` **mit** angehaengtem
  ///   Fehler, und die Future wird nie erfuellt — auch ihr `onError` feuert
  ///   nie. Der alte Code konnte den Fehler deshalb gar nicht bemerken.
  /// - Ohne aktiven Listener wird ein Provider nach einer Aenderung seiner
  ///   Abhaengigkeiten nicht neu gebaut. Ein `read(...future)` allein haelt
  ///   die Kette nicht am Leben.
  ///
  /// Das Abo loest beides: Es liefert Wert und Fehler, und es haelt die
  /// Katalogkette so lange aktiv, bis eines von beidem da ist.
  ///
  /// [includeCurrentState] muss beim Neuversuch `false` sein: Direkt nach
  /// `invalidate` traegt der Provider noch den Fehler des Vorlaufs, ein
  /// sofortiges Auswerten wuerde den Neuversuch also augenblicklich wieder
  /// als gescheitert melden.
  Future<void> _awaitCatalogReady({bool includeCurrentState = true}) {
    final completer = Completer<void>();

    void settle(AsyncValue<RulesCatalog> value) {
      if (completer.isCompleted) {
        return;
      }
      final error = value.error;
      if (error != null) {
        completer.completeError(error, value.stackTrace ?? StackTrace.current);
      } else if (value.hasValue) {
        completer.complete();
      }
    }

    final subscription = ref.listenManual<AsyncValue<RulesCatalog>>(
      rulesCatalogProvider,
      (_, next) => settle(next),
      fireImmediately: includeCurrentState,
    );
    return completer.future.whenComplete(subscription.close);
  }

  // Verwirft den gemerkten Ladeversuch, damit `Erneut versuchen` tatsaechlich
  // neu laedt, statt derselben gescheiterten Future erneut zuzuhoeren.
  Future<void> _retryCatalogPrewarm() {
    ref.invalidate(rulesCatalogProvider);
    return _catalogPrewarmFuture = _awaitCatalogReady(
      includeCurrentState: false,
    );
  }

  // Startet den Katalog erst nach dem ersten sichtbaren Home-Frame.
  void _scheduleCatalogPrewarmAfterFrame() {
    if (_catalogPrewarmScheduled) {
      return;
    }
    _catalogPrewarmScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_startCatalogPrewarm().catchError((Object _) {}));
    });
  }

  /// Wartet auf den Regelkatalog und zeigt bei spuerbarer Wartezeit einen
  /// Dialog.
  ///
  /// Liefert `true`, wenn der Katalog bereit ist, und `false`, wenn der Nutzer
  /// abgebrochen hat oder der Ladeversuch endgueltig scheiterte.
  Future<bool> _waitForCatalogBeforeOpening(BuildContext context) async {
    final future = _startCatalogPrewarm();

    if (await _settlesWithin(future, _catalogDialogDelay)) {
      try {
        await future;
        return true;
      } on Object {
        // Fehler gehoert in den Dialog, nicht in ein stilles Nichts.
      }
    }

    if (!context.mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CatalogPreparationDialog(
        task: future,
        timeout: _catalogTimeout,
        onRetry: _retryCatalogPrewarm,
      ),
    );
    return result ?? false;
  }

  /// Meldet, ob [future] innerhalb von [limit] abgeschlossen ist — mit Wert
  /// oder mit Fehler.
  static Future<bool> _settlesWithin(Future<void> future, Duration limit) {
    return Future.any<bool>(<Future<bool>>[
      future.then<bool>((_) => true, onError: (Object _) => true),
      Future<bool>.delayed(limit, () => false),
    ]);
  }

  // Buendelt Auswahl, Katalogvorbereitung und Navigation fuer alle Oeffnungspfade.
  Future<void> _openHeroWorkspace(BuildContext context, String heroId) async {
    await ref.read(selectedHeroSelectionActionsProvider).selectHero(heroId);
    if (!context.mounted) {
      return;
    }
    final ready = await _waitForCatalogBeforeOpening(context);
    if (!ready || !context.mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HeroWorkspaceScreen(heroId: heroId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroesAsync = ref.watch(heroListProvider);
    final selectedHeroId = ref.watch(selectedHeroIdProvider);
    const importExportActions = WorkspaceImportExportActions();
    final apple = isApplePlatform(context);
    final layout = appLayoutOf(context);

    Future<void> createHero() async {
      final draft = await _showCreateHeroDialog(context);
      if (draft == null || !context.mounted) {
        return;
      }
      try {
        final id = await ref
            .read(heroActionsProvider)
            .createHero(
              name: draft.name,
              rawStartAttributes: draft.rawStartAttributes,
            );
        if (!context.mounted) {
          return;
        }
        await _openHeroWorkspace(context, id);
      } on Exception catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }

    Future<void> openHeroWorkspace(String heroId) async {
      await _openHeroWorkspace(context, heroId);
    }

    Future<void> showHeroPreviewSheet(HeroSheet hero) async {
      await ref.read(selectedHeroSelectionActionsProvider).selectHero(hero.id);
      if (!context.mounted) {
        return;
      }
      await showAdaptiveDetailSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: HeroHomePreviewPanel(
              hero: hero,
              onOpenWorkspace: () {
                Navigator.of(context, rootNavigator: true).pop();
                openHeroWorkspace(hero.id);
              },
              onExportHero: () => _exportSelectedHero(
                context: context,
                ref: ref,
                hero: hero,
                importExportActions: importExportActions,
              ),
              onDeleteHero: () =>
                  _deleteSelectedHero(context: context, ref: ref, hero: hero),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSA Helden'),
        actions: _buildAppBarActions(
          layout: layout,
          apple: apple,
          onCreateHero: createHero,
          onImportHero: () => _importHero(
            context: context,
            ref: ref,
            importExportActions: importExportActions,
          ),
          onOpenSettings: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ),
      floatingActionButton: layout == AppLayoutClass.compact && !apple
          ? FloatingActionButton.extended(
              onPressed: createHero,
              icon: const Icon(Icons.add),
              label: const Text('Neuer Held'),
            )
          : null,
      body: heroesAsync.when(
        data: (heroes) {
          _scheduleCatalogPrewarmAfterFrame();
          if (heroes.isEmpty) {
            return CodexPageScaffold(
              padding: EdgeInsets.all(layout.contentPadding),
              child: Center(
                child: CodexEmptyState(
                  title: 'Dein Heldenarchiv ist noch leer',
                  message:
                      'Lege deinen ersten Helden an oder importiere einen bestehenden Bogen, um auf dem iPad mit einem digitalen Heldenbogen zu arbeiten.',
                  assetPath: 'assets/ui/codex/empty_ledger.png',
                  action: FilledButton.icon(
                    onPressed: createHero,
                    icon: const Icon(Icons.add),
                    label: const Text('Ersten Helden anlegen'),
                  ),
                ),
              ),
            );
          }

          final selectedHero = _resolveSelectedHero(
            heroes: heroes,
            selectedHeroId: selectedHeroId,
          );
          final archivePane = HeroHomeArchivePane(
            heroes: heroes,
            selectedHeroId: selectedHero?.id,
            layout: layout,
            onSelectHero: (hero) {
              if (layout.hasPersistentDetailPane) {
                ref
                    .read(selectedHeroSelectionActionsProvider)
                    .selectHero(hero.id);
                return;
              }
              if (layout == AppLayoutClass.tabletPortrait) {
                showHeroPreviewSheet(hero);
                return;
              }
              openHeroWorkspace(hero.id);
            },
            onExportHero: (hero) => _exportSelectedHero(
              context: context,
              ref: ref,
              hero: hero,
              importExportActions: importExportActions,
            ),
            onDeleteHero: (hero) =>
                _deleteSelectedHero(context: context, ref: ref, hero: hero),
          );

          if (!layout.hasPersistentDetailPane) {
            return archivePane;
          }

          return CodexSplitView(
            primaryWidth: layout == AppLayoutClass.desktopWide ? 420 : 360,
            primary: archivePane,
            secondary: CodexPageScaffold(
              padding: EdgeInsets.all(layout.contentPadding),
              child: HeroHomePreviewPanel(
                hero: selectedHero!,
                onOpenWorkspace: () => openHeroWorkspace(selectedHero.id),
                onExportHero: () => _exportSelectedHero(
                  context: context,
                  ref: ref,
                  hero: selectedHero,
                  importExportActions: importExportActions,
                ),
                onDeleteHero: () => _deleteSelectedHero(
                  context: context,
                  ref: ref,
                  hero: selectedHero,
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      ),
    );
  }

  List<Widget> _buildAppBarActions({
    required AppLayoutClass layout,
    required bool apple,
    required Future<void> Function() onCreateHero,
    required Future<void> Function() onImportHero,
    required VoidCallback onOpenSettings,
  }) {
    if (layout == AppLayoutClass.compact) {
      return [
        if (apple)
          IconButton(
            tooltip: 'Neuer Held',
            onPressed: onCreateHero,
            icon: const Icon(Icons.add),
          ),
        IconButton(
          tooltip: 'Importieren',
          onPressed: onImportHero,
          icon: const Icon(Icons.download),
        ),
        IconButton(
          tooltip: 'Einstellungen',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings),
        ),
        const SizedBox(width: 12),
      ];
    }

    return [
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: FilledButton.tonalIcon(
          onPressed: onCreateHero,
          icon: const Icon(Icons.add),
          label: const Text('Neuer Held'),
        ),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: OutlinedButton.icon(
          onPressed: onImportHero,
          icon: const Icon(Icons.download),
          label: const Text('Importieren'),
        ),
      ),
      IconButton(
        tooltip: 'Einstellungen',
        onPressed: onOpenSettings,
        icon: const Icon(Icons.settings),
      ),
      const SizedBox(width: 12),
    ];
  }

  HeroSheet? _resolveSelectedHero({
    required List<HeroSheet> heroes,
    required String? selectedHeroId,
  }) {
    for (final hero in heroes) {
      if (hero.id == selectedHeroId) {
        return hero;
      }
    }
    if (heroes.isEmpty) {
      return null;
    }
    return heroes.first;
  }

  Future<void> _deleteSelectedHero({
    required BuildContext context,
    required WidgetRef ref,
    required HeroSheet hero,
  }) async {
    final result = await showAdaptiveConfirmDialog(
      context: context,
      title: 'Held löschen',
      content: 'Soll "${hero.name}" wirklich gelöscht werden?',
      confirmLabel: 'Löschen',
      cancelLabel: 'Abbrechen',
      isDestructive: true,
    );
    if (result != AdaptiveConfirmResult.confirm) {
      return;
    }
    await ref.read(heroActionsProvider).deleteHero(hero.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Held gelöscht: ${hero.name}')));
  }

  Future<void> _exportSelectedHero({
    required BuildContext context,
    required WidgetRef ref,
    required HeroSheet hero,
    required WorkspaceImportExportActions importExportActions,
  }) async {
    try {
      final outcome = await importExportActions.exportHeroData(
        ref: ref,
        hero: hero,
      );
      if (!context.mounted) {
        return;
      }
      if (outcome.result == HeroTransferExportResult.canceled) {
        return;
      }
      if (outcome.result == HeroTransferExportResult.savedToFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Held exportiert: ${outcome.location ?? 'Datei gespeichert'}',
            ),
          ),
        );
        return;
      }
      if (outcome.result == HeroTransferExportResult.downloaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Held exportiert und Download gestartet'),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Held exportiert und geteilt')),
      );
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export fehlgeschlagen: $error')));
    }
  }

  Future<void> _importHero({
    required BuildContext context,
    required WidgetRef ref,
    required WorkspaceImportExportActions importExportActions,
  }) async {
    try {
      final heroId = await importExportActions.importHeroData(
        context: context,
        ref: ref,
      );
      if (heroId == null || !context.mounted) {
        return;
      }
      await _openHeroWorkspace(context, heroId);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Held erfolgreich importiert')),
      );
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import ungültig: ${error.message}')),
      );
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import fehlgeschlagen: $error')));
    }
  }

  Future<_CreateHeroDraft?> _showCreateHeroDialog(BuildContext context) async {
    return showAdaptiveDetailSheet<_CreateHeroDraft>(
      context: context,
      builder: (dialogContext) => const _CreateHeroDialog(),
    );
  }
}

/// Blockiert das Oeffnen eines Helden, solange der Regelkatalog laedt.
///
/// Der Dialog verwaltet seine Lebensdauer **selbst**, und das ist der Kern
/// dieser Klasse: Frueher schloss ihn der Aufrufer per `Navigator.pop()`, aber
/// nur solange dessen `context.mounted` galt. Die Dialog-Route haengt jedoch am
/// Root-Navigator der `MaterialApp`, waehrend `SyncConflictGate` den
/// `HeroesHomeScreen` darunter jederzeit austauschen kann. Genau dann blieb ein
/// `canPop: false`-Dialog ohne Barrier-Tap und ohne Zurueck-Weg stehen — die
/// App war hart blockiert.
///
/// Zusaetzlich endet das Warten nach [timeout], statt unbegrenzt zu drehen.
class _CatalogPreparationDialog extends StatefulWidget {
  const _CatalogPreparationDialog({
    required this.task,
    required this.timeout,
    required this.onRetry,
  });

  /// Laufender Katalog-Ladevorgang.
  final Future<void> task;

  /// Zeit, nach der ein nicht abgeschlossener Ladevorgang als Fehlschlag gilt.
  final Duration timeout;

  /// Startet einen echten neuen Ladeversuch und liefert dessen Future.
  final Future<void> Function() onRetry;

  @override
  State<_CatalogPreparationDialog> createState() =>
      _CatalogPreparationDialogState();
}

class _CatalogPreparationDialogState extends State<_CatalogPreparationDialog> {
  Object? _error;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    unawaited(_observe(widget.task));
  }

  /// Begleitet einen Ladeversuch und schliesst den Dialog bei Erfolg selbst.
  Future<void> _observe(Future<void> task) async {
    try {
      await task.timeout(widget.timeout);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _timedOut = true;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _timedOut = false;
        _error = error;
      });
    }
  }

  void _retry() {
    setState(() {
      _timedOut = false;
      _error = null;
    });
    unawaited(_observe(widget.onRetry()));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final failed = _timedOut || error != null;

    if (!failed) {
      return const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Flexible(child: Text('Regelkatalog wird vorbereitet ...')),
            ],
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Regelkatalog nicht bereit'),
      content: Text(
        _timedOut
            ? 'Der Regelkatalog braucht ungewöhnlich lange. Du kannst es '
                  'erneut versuchen oder abbrechen und später weitermachen.'
            : 'Der Regelkatalog konnte nicht geladen werden.\n\n$error',
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('catalog-preparation-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('catalog-preparation-retry'),
          onPressed: _retry,
          child: const Text('Erneut versuchen'),
        ),
      ],
    );
  }
}

class _CreateHeroDialog extends StatefulWidget {
  const _CreateHeroDialog();

  @override
  State<_CreateHeroDialog> createState() => _CreateHeroDialogState();
}

class _CreateHeroDialogState extends State<_CreateHeroDialog> {
  late final TextEditingController _nameController;
  late final Map<String, TextEditingController> _attributeControllers;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _attributeControllers = <String, TextEditingController>{
      'mu': TextEditingController(text: '11'),
      'kl': TextEditingController(text: '11'),
      'inn': TextEditingController(text: '11'),
      'ch': TextEditingController(text: '11'),
      'ff': TextEditingController(text: '11'),
      'ge': TextEditingController(text: '11'),
      'ko': TextEditingController(text: '11'),
      'kk': TextEditingController(text: '11'),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _attributeControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuen Helden anlegen'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: kDialogWidthSmall,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey<String>('create-hero-name'),
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _attributeFields(_attributeControllers),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CreateHeroDraft(
                name: _nameController.text.trim(),
                rawStartAttributes: Attributes(
                  mu: _readCreateAttributeValue(_attributeControllers, 'mu'),
                  kl: _readCreateAttributeValue(_attributeControllers, 'kl'),
                  inn: _readCreateAttributeValue(_attributeControllers, 'inn'),
                  ch: _readCreateAttributeValue(_attributeControllers, 'ch'),
                  ff: _readCreateAttributeValue(_attributeControllers, 'ff'),
                  ge: _readCreateAttributeValue(_attributeControllers, 'ge'),
                  ko: _readCreateAttributeValue(_attributeControllers, 'ko'),
                  kk: _readCreateAttributeValue(_attributeControllers, 'kk'),
                ),
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }

  List<Widget> _attributeFields(
    Map<String, TextEditingController> attributeControllers,
  ) {
    final labels = <(String, String)>[
      ('MU', 'mu'),
      ('KL', 'kl'),
      ('IN', 'inn'),
      ('CH', 'ch'),
      ('FF', 'ff'),
      ('GE', 'ge'),
      ('KO', 'ko'),
      ('KK', 'kk'),
    ];

    return labels
        .map(
          (entry) => SizedBox(
            width: 88,
            child: TextField(
              key: ValueKey<String>('create-hero-${entry.$2}'),
              controller: attributeControllers[entry.$2],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: entry.$1,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        )
        .toList(growable: false);
  }

  int _readCreateAttributeValue(
    Map<String, TextEditingController> attributeControllers,
    String key,
  ) {
    final value = int.tryParse(attributeControllers[key]!.text.trim()) ?? 8;
    if (value < 0) {
      return 0;
    }
    if (value > 99) {
      return 99;
    }
    return value;
  }
}

class _CreateHeroDraft {
  const _CreateHeroDraft({
    required this.name,
    required this.rawStartAttributes,
  });

  final String name;
  final Attributes rawStartAttributes;
}
