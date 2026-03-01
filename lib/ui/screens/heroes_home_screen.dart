import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_workspace_screen.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_import_export_actions.dart';

class HeroesHomeScreen extends ConsumerWidget {
  const HeroesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroesAsync = ref.watch(heroListProvider);
    final selectedHeroId = ref.watch(selectedHeroIdProvider);
    const importExportActions = WorkspaceImportExportActions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSA Helden'),
        actions: heroesAsync.when(
          data: (heroes) {
            final selectedHero = _selectedHeroFor(
              heroes: heroes,
              selectedHeroId: selectedHeroId,
            );
            return [
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Held loeschen',
                onPressed: selectedHero == null
                    ? null
                    : () => _deleteSelectedHero(
                        context: context,
                        ref: ref,
                        hero: selectedHero,
                      ),
                icon: const Icon(Icons.delete_outline),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Held exportieren',
                onPressed: selectedHero == null
                    ? null
                    : () => _exportSelectedHero(
                        context: context,
                        ref: ref,
                        hero: selectedHero,
                        importExportActions: importExportActions,
                      ),
                icon: const Icon(Icons.upload_file),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Held importieren',
                onPressed: () => _importHero(
                  context: context,
                  ref: ref,
                  importExportActions: importExportActions,
                ),
                icon: const Icon(Icons.download),
              ),
              const SizedBox(width: 12),
            ];
          },
          loading: () => const <Widget>[SizedBox(width: 12)],
          error: (error, stackTrace) => const <Widget>[SizedBox(width: 12)],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final navigator = Navigator.of(context);
          final id = await ref.read(heroActionsProvider).createHero();
          if (!context.mounted) {
            return;
          }
          navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => HeroWorkspaceScreen(heroId: id)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Neuer Held'),
      ),
      body: heroesAsync.when(
        data: (heroes) {
          if (heroes.isEmpty) {
            return const Center(
              child: Text(
                'Noch keine Helden angelegt. Erstelle deinen ersten Helden.',
              ),
            );
          }

          return ListView.separated(
            itemCount: heroes.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final hero = heroes[index];
              return ListTile(
                selected: selectedHeroId == hero.id,
                title: Text(hero.name),
                subtitle: Text('Level ${hero.level}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.read(selectedHeroIdProvider.notifier).state = hero.id;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => HeroWorkspaceScreen(heroId: hero.id),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Fehler: $error')),
      ),
    );
  }

  HeroSheet? _selectedHeroFor({
    required List<HeroSheet> heroes,
    required String? selectedHeroId,
  }) {
    if (heroes.isEmpty) {
      return null;
    }
    if (selectedHeroId == null) {
      return heroes.first;
    }
    for (final hero in heroes) {
      if (hero.id == selectedHeroId) {
        return hero;
      }
    }
    return heroes.first;
  }

  Future<void> _deleteSelectedHero({
    required BuildContext context,
    required WidgetRef ref,
    required HeroSheet hero,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Held loeschen'),
          content: Text('Soll "${hero.name}" wirklich geloescht werden?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Loeschen'),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) {
      return;
    }
    await ref.read(heroActionsProvider).deleteHero(hero.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Held geloescht: ${hero.name}')));
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
      final importedId = await importExportActions.importHeroData(
        context: context,
        ref: ref,
      );
      if (importedId == null || !context.mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HeroWorkspaceScreen(heroId: importedId),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Held erfolgreich importiert')),
      );
    } on FormatException catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import ungueltig: ${error.message}')),
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
}
