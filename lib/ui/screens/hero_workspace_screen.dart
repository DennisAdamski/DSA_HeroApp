import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_basis_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/heroes_home_screen.dart';

class HeroWorkspaceScreen extends ConsumerWidget {
  const HeroWorkspaceScreen({super.key, required this.heroId});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroes =
        ref.watch(heroListProvider).valueOrNull ?? const <HeroSheet>[];

    HeroSheet? hero;
    for (final item in heroes) {
      if (item.id == heroId) {
        hero = item;
        break;
      }
    }

    if (hero == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Held')),
        body: const Center(child: Text('Held nicht gefunden.')),
      );
    }

    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text(hero.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Heldenauswahl',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HeroesHomeScreen()),
              );
            },
          ),
          actions: [
            IconButton(
              onPressed: () => _exportHeroData(context, ref, hero!),
              icon: const Icon(Icons.upload_file),
              tooltip: 'Held exportieren',
            ),
            IconButton(
              onPressed: () => _importHeroData(context, ref),
              icon: const Icon(Icons.download),
              tooltip: 'Held importieren',
            ),
            IconButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref.read(heroActionsProvider).deleteHero(heroId);
                if (!context.mounted) {
                  return;
                }
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const HeroesHomeScreen()),
                );
              },
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Held loeschen',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Uebersicht'),
              Tab(text: 'Basis'),
              Tab(text: 'Kampf'),
              Tab(text: 'Magie'),
              Tab(text: 'Talente'),
              Tab(text: 'Inventar'),
              Tab(text: 'Notizen'),
            ],
          ),
        ),
        body: Column(
          children: [
            _CoreAttributesHeader(hero: hero),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(heroId: heroId, hero: hero),
                  HeroBasisTab(heroId: heroId),
                  const _PlaceholderTab(title: 'Kampf'),
                  const _CatalogPlaceholderTab(
                    title: 'Magie',
                    section: _CatalogSection.spells,
                  ),
                  HeroTalentsTab(heroId: heroId),
                  const _CatalogPlaceholderTab(
                    title: 'Inventar',
                    section: _CatalogSection.weapons,
                  ),
                  const _PlaceholderTab(title: 'Notizen'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportHeroData(
    BuildContext context,
    WidgetRef ref,
    HeroSheet hero,
  ) async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final payload = await ref
          .read(heroActionsProvider)
          .buildExportJson(hero.id);
      final gateway = ref.read(heroTransferFileGatewayProvider);
      final outcome = await gateway.exportJson(
        fileNameBase: hero.name,
        jsonPayload: payload,
      );

      if (!context.mounted) {
        return;
      }

      if (outcome.result.name == 'canceled') {
        return;
      }
      if (outcome.result.name == 'savedToFile') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Held exportiert: ${outcome.location ?? 'Datei gespeichert'}',
            ),
          ),
        );
        return;
      }
      if (outcome.result.name == 'downloaded') {
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

  Future<void> _importHeroData(BuildContext context, WidgetRef ref) async {
    final gateway = ref.read(heroTransferFileGatewayProvider);
    final rawJson = await gateway.pickImportJson();
    if (rawJson == null) {
      return;
    }

    try {
      final actions = ref.read(heroActionsProvider);
      final bundle = await actions.parseImportJson(rawJson);
      if (!context.mounted) {
        return;
      }
      final resolution = await _resolveConflict(context, ref, bundle);
      if (resolution == null) {
        return;
      }

      final importedId = await actions.importHeroBundle(
        bundle,
        resolution: resolution,
      );

      if (!context.mounted) {
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

  Future<ImportConflictResolution?> _resolveConflict(
    BuildContext context,
    WidgetRef ref,
    HeroTransferBundle bundle,
  ) async {
    final heroes = await ref.read(heroListProvider.future);
    var exists = false;
    for (final hero in heroes) {
      if (hero.id == bundle.hero.id) {
        exists = true;
        break;
      }
    }
    if (!exists) {
      return ImportConflictResolution.overwriteExisting;
    }

    if (!context.mounted) {
      return null;
    }
    return showDialog<ImportConflictResolution>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Held bereits vorhanden'),
          content: const Text(
            'Die importierte Held-ID existiert bereits. Soll der vorhandene Held '
            'ueberschrieben oder als neuer Held importiert werden?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ImportConflictResolution.createNewHero),
              child: const Text('Als neu erstellen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(ImportConflictResolution.overwriteExisting),
              child: const Text('Ueberschreiben'),
            ),
          ],
        );
      },
    );
  }
}

class _CoreAttributesHeader extends StatelessWidget {
  const _CoreAttributesHeader({required this.hero});

  final HeroSheet hero;

  @override
  Widget build(BuildContext context) {
    final attrs = [
      ('MU', hero.attributes.mu),
      ('KL', hero.attributes.kl),
      ('IN', hero.attributes.inn),
      ('CH', hero.attributes.ch),
      ('FF', hero.attributes.ff),
      ('GE', hero.attributes.ge),
      ('KO', hero.attributes.ko),
      ('KK', hero.attributes.kk),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: attrs
            .map(
              (entry) => Chip(
                label: Text('${entry.$1}: ${entry.$2}'),
                visualDensity: VisualDensity.compact,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.heroId, required this.hero});

  final String heroId;
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final derivedAsync = ref.watch(derivedStatsProvider(heroId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Basisinformationen',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _summaryRow('Name', hero.name),
        _summaryRow('Rasse', hero.rasse),
        _summaryRow('Rasse Modifikatoren', hero.rasseModText),
        _summaryRow('Kultur', hero.kultur),
        _summaryRow('Kultur Modifikatoren', hero.kulturModText),
        _summaryRow('Profession', hero.profession),
        _summaryRow('Profession Modifikatoren', hero.professionModText),
        _summaryRow('Geschlecht', hero.geschlecht),
        _summaryRow('Alter', hero.alter),
        _summaryRow('Groesse', hero.groesse),
        _summaryRow('Gewicht', hero.gewicht),
        _summaryRow('Haarfarbe', hero.haarfarbe),
        _summaryRow('Augenfarbe', hero.augenfarbe),
        _summaryRow('Aussehen', hero.aussehen),
        _summaryRow('Stand', hero.stand),
        _summaryRow('Titel', hero.titel),
        _summaryRow(
          'Familie/Herkunft/Hintergrund',
          hero.familieHerkunftHintergrund,
        ),
        _summaryRow('Sozialstatus', hero.sozialstatus.toString()),
        _summaryRow('Vorteile', hero.vorteileText),
        _summaryRow('Nachteile', hero.nachteileText),
        _summaryRow('AP Gesamt', hero.apTotal.toString()),
        _summaryRow('AP Ausgegeben', hero.apSpent.toString()),
        _summaryRow('AP Verfuegbar', hero.apAvailable.toString()),
        _summaryRow('Level', hero.level.toString()),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _editAttributes(context, ref),
          icon: const Icon(Icons.edit),
          label: const Text('Eigenschaften bearbeiten'),
        ),
        if (hero.unknownModifierFragments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Parser-Warnungen',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hero.unknownModifierFragments
                .map((entry) => Chip(label: Text(entry)))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Abgeleitete Werte',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        derivedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('Fehler: $error'),
          data: (derived) {
            final entries = [
              ('LeP Max', derived.maxLep),
              ('Au Max', derived.maxAu),
              ('AsP Max', derived.maxAsp),
              ('KaP Max', derived.maxKap),
              ('MR', derived.mr),
              ('Ini-Basis', derived.iniBase),
              ('GS', derived.gs),
              ('Ausweichen', derived.ausweichen),
            ];
            return Column(
              children: entries
                  .map(
                    (entry) => Card(
                      child: ListTile(
                        title: Text(entry.$1),
                        trailing: Text(
                          entry.$2.toString(),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    final shown = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 220, child: Text('$label:')),
          Expanded(child: Text(shown)),
        ],
      ),
    );
  }

  Future<void> _editAttributes(BuildContext context, WidgetRef ref) async {
    final mu = TextEditingController(text: hero.attributes.mu.toString());
    final kl = TextEditingController(text: hero.attributes.kl.toString());
    final inn = TextEditingController(text: hero.attributes.inn.toString());
    final ch = TextEditingController(text: hero.attributes.ch.toString());
    final ff = TextEditingController(text: hero.attributes.ff.toString());
    final ge = TextEditingController(text: hero.attributes.ge.toString());
    final ko = TextEditingController(text: hero.attributes.ko.toString());
    final kk = TextEditingController(text: hero.attributes.kk.toString());

    int parseInRange(TextEditingController c) {
      final value = int.tryParse(c.text.trim()) ?? 8;
      if (value < 1) {
        return 1;
      }
      if (value > 30) {
        return 30;
      }
      return value;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eigenschaften bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _attrField('MU', mu),
                _attrField('KL', kl),
                _attrField('IN', inn),
                _attrField('CH', ch),
                _attrField('FF', ff),
                _attrField('GE', ge),
                _attrField('KO', ko),
                _attrField('KK', kk),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final updated = hero.copyWith(
        attributes: Attributes(
          mu: parseInRange(mu),
          kl: parseInRange(kl),
          inn: parseInRange(inn),
          ch: parseInRange(ch),
          ff: parseInRange(ff),
          ge: parseInRange(ge),
          ko: parseInRange(ko),
          kk: parseInRange(kk),
        ),
      );
      await ref.read(heroActionsProvider).saveHero(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eigenschaften gespeichert')),
        );
      }
    }

    mu.dispose();
    kl.dispose();
    inn.dispose();
    ch.dispose();
    ff.dispose();
    ge.dispose();
    ko.dispose();
    kk.dispose();
  }

  Widget _attrField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title wird als naechstes ausgearbeitet.'));
  }
}

enum _CatalogSection { talents, spells, weapons }

class _CatalogPlaceholderTab extends ConsumerWidget {
  const _CatalogPlaceholderTab({required this.title, required this.section});

  final String title;
  final _CatalogSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(rulesCatalogProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Katalog-Fehler: $error')),
      data: (catalog) {
        final count = switch (section) {
          _CatalogSection.talents => catalog.talents.length,
          _CatalogSection.spells => catalog.spells.length,
          _CatalogSection.weapons => catalog.weapons.length,
        };

        final details = switch (section) {
          _CatalogSection.talents =>
            'mit Waffengattung: ${catalog.talents.where((t) => t.weaponCategory.isNotEmpty).length}',
          _CatalogSection.spells =>
            'mit Verfuegbarkeit: ${catalog.spells.where((s) => s.availability.isNotEmpty).length}',
          _CatalogSection.weapons =>
            'mit Waffengattung: ${catalog.weapons.where((w) => w.weaponCategory.isNotEmpty).length}',
        };

        return Center(
          child: Text(
            '$title: $count Eintraege aus ${catalog.version} geladen ($details).',
          ),
        );
      },
    );
  }
}
