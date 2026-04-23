part of 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

class _SettingsPageList extends StatelessWidget {
  const _SettingsPageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: children);
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _AppearanceSettingsPage extends ConsumerWidget {
  const _AppearanceSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dunkelModus = ref.watch(dunkelModusProvider);
    final variante = ref.watch(uiVarianteProvider);
    final actions = ref.read(settingsActionsProvider);
    final theme = Theme.of(context);

    return _SettingsPageList(
      children: [
        Text(
          'Lege Farbschema und Stil der App für deinen Arbeitsplatz fest.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _SettingsSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dunkelmodus'),
                subtitle: const Text('Dunkles Farbschema'),
                value: dunkelModus,
                onChanged: (_) => actions.toggleDunkelModus(),
              ),
              const Divider(height: 24),
              Text('Design', style: theme.textTheme.titleSmall),
              const SizedBox(height: 12),
              SegmentedButton<UiVariante>(
                segments: const <ButtonSegment<UiVariante>>[
                  ButtonSegment(
                    value: UiVariante.klassisch,
                    label: Text('Klassisch'),
                    icon: Icon(Icons.palette_outlined),
                  ),
                  ButtonSegment(
                    value: UiVariante.codex,
                    label: Text('Codex'),
                    icon: Icon(Icons.auto_stories),
                  ),
                ],
                selected: <UiVariante>{variante},
                onSelectionChanged: (selected) {
                  actions.setUiVariante(selected.first);
                },
              ),
              const SizedBox(height: 12),
              Text(
                variante == UiVariante.codex
                    ? 'Pergament- und Messing-Ästhetik mit Texturen und dekorativen Elementen.'
                    : 'Schlichtes Material-Design ohne dekorative Elemente.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StorageSettingsPage extends ConsumerWidget {
  const _StorageSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final heroStorageLocationAsync = ref.watch(heroStorageLocationProvider);
    final settingsStoragePathAsync = ref.watch(settingsStoragePathProvider);
    final actions = ref.read(settingsActionsProvider);

    return heroStorageLocationAsync.when(
      data: (location) {
        final settingsStoragePath = settingsStoragePathAsync.valueOrNull;
        final canOpenDirectory =
            location.isAccessible && canOpenStorageDirectory();

        return _SettingsPageList(
          children: [
            Text(
              'Heldendaten werden getrennt von App-Einstellungen gespeichert. '
              'Ein eigener Pfad eignet sich zum Beispiel für einen Cloud-Ordner.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _SettingsSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PathInfoTile(
                    label: 'Aktiver Heldenspeicher',
                    value: location.effectivePath,
                  ),
                  const SizedBox(height: 12),
                  _PathInfoTile(
                    label: 'Lokaler Einstellungsordner',
                    value: settingsStoragePath ?? 'Wird geladen ...',
                  ),
                  if (location.usesCustomPath) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Benutzerdefinierter Pfad aktiv',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                  if (location.validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      location.validationError!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (location.customPathSupported) ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _selectHeroStoragePath(
                            context: context,
                            ref: ref,
                          ),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Ordner wählen'),
                        ),
                        OutlinedButton.icon(
                          onPressed: location.usesCustomPath
                              ? () async {
                                  await actions.clearHeroStoragePath();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Heldenspeicher auf Standardpfad zurückgesetzt.',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Standard verwenden'),
                        ),
                        OutlinedButton.icon(
                          onPressed: canOpenDirectory
                              ? () => _openStorageFolder(
                                  context: context,
                                  path: location.effectivePath,
                                )
                              : null,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Ordner öffnen'),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      'Ein benutzerdefinierter Heldenspeicher ist auf dieser '
                      'Plattform derzeit nicht verfügbar.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Hinweis: App-Einstellungen werden nie in den Heldenspeicher synchronisiert.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Warnung: Dieselben Heldendaten sollten nicht gleichzeitig '
                    'auf mehreren Geräten bearbeitet werden, wenn ein Cloud-Ordner verwendet wird.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Speicherorte konnten nicht geladen werden: $error'),
        ),
      ),
    );
  }

  Future<void> _selectHeroStoragePath({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final selectedPath = await ref
        .read(storageDirectoryPickerProvider)
        .pickDirectory(dialogTitle: 'Heldenspeicher wählen');
    if (!context.mounted) {
      return;
    }
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    await ref.read(settingsActionsProvider).setHeroStoragePath(selectedPath);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Heldenspeicher aktualisiert.')),
    );
  }

  Future<void> _openStorageFolder({
    required BuildContext context,
    required String path,
  }) async {
    try {
      await openStorageDirectory(path);
    } on Exception catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ordner konnte nicht geöffnet werden: $error')),
      );
    }
  }
}

class _CatalogSettingsPage extends ConsumerWidget {
  const _CatalogSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heroStorageLocation = ref.watch(heroStorageLocationProvider);
    final effectivePath =
        heroStorageLocation.valueOrNull?.effectivePath ?? 'Wird geladen ...';
    final theme = Theme.of(context);

    return _SettingsPageList(
      children: [
        _SettingsSectionCard(
          title: 'Custom-Kataloge',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alle Basis-Katalogdaten können hier eingesehen werden. '
                'Eigene Einträge werden als Custom-Kataloge im Heldenspeicher abgelegt '
                'und lassen sich dadurch über einen Cloud-Ordner synchronisieren.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              _PathInfoTile(
                label: 'Aktiver Speicher für Custom-Kataloge',
                value: effectivePath,
              ),
              const SizedBox(height: 12),
              Text(
                'Hinweis: Änderungen aus einem synchronisierten Ordner werden erst nach '
                '„Katalog neu laden“ oder nach einem App-Neustart sichtbar.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CatalogManagementScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.library_books_outlined),
                label: const Text('Katalogverwaltung öffnen'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _CatalogContentPasswordCard(),
      ],
    );
  }
}

class _HouseRulesSettingsPage extends ConsumerWidget {
  const _HouseRulesSettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final disabled = ref.watch(disabledHouseRulePackIdsProvider);
    final actions = ref.read(settingsActionsProvider);
    final packCatalogAsync = ref.watch(houseRulePackCatalogProvider);
    final issuesAsync = ref.watch(houseRuleIssueSnapshotProvider);

    return packCatalogAsync.when(
      data: (catalog) {
        final roots = catalog.roots;
        return _SettingsPageList(
          children: [
            Text(
              'Optionale Regelpakete liegen über dem offiziellen Katalog. '
              'Deaktivierte Pakete blenden ihre Inhalte und Überschreibungen aus, '
              'ohne bestehende Heldendaten zu löschen.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (roots.isEmpty)
              Text(
                'Keine Hausregel-Pakete gefunden.',
                style: theme.textTheme.bodySmall,
              )
            else
              ...roots.expand(
                (root) => <Widget>[
                  _HouseRuleGroup(
                    root: root,
                    catalog: catalog,
                    disabled: disabled,
                    onToggle: (packId, enabled) =>
                        actions.setHouseRuleEnabled(packId, enabled),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HouseRulePackManagementScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Hausregelverwaltung öffnen'),
              ),
            ),
            const SizedBox(height: 8),
            issuesAsync.maybeWhen(
              data: (issues) {
                if (issues.isEmpty) {
                  return const SizedBox.shrink();
                }
                return _HouseRuleIssuesCard(issues: issues);
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Hausregel-Pakete konnten nicht geladen werden: $error',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      ),
    );
  }
}

class _HouseRuleGroup extends StatelessWidget {
  const _HouseRuleGroup({
    required this.root,
    required this.catalog,
    required this.disabled,
    required this.onToggle,
  });

  final HouseRulePackManifest root;
  final HouseRulePackCatalog catalog;
  final Set<String> disabled;
  final void Function(String packId, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rootEnabled = !disabled.contains(root.id);
    final children = catalog.childrenOf(root.id);

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            title: Text(root.title),
            subtitle: Text(
              root.isBuiltIn
                  ? root.description
                  : '${root.description}\nImportiertes Paket',
            ),
            value: rootEnabled,
            onChanged: (value) => onToggle(root.id, value),
          ),
          if (children.isNotEmpty) ...[
            const Divider(height: 1),
            ...children.map(
              (child) => _HouseRuleChildTile(
                child: child,
                childDisabled: disabled.contains(child.id),
                parentEnabled: rootEnabled,
                onToggle: onToggle,
                captionStyle: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HouseRuleChildTile extends StatelessWidget {
  const _HouseRuleChildTile({
    required this.child,
    required this.childDisabled,
    required this.parentEnabled,
    required this.onToggle,
    required this.captionStyle,
  });

  final HouseRulePackManifest child;
  final bool childDisabled;
  final bool parentEnabled;
  final void Function(String packId, bool enabled) onToggle;
  final TextStyle? captionStyle;

  @override
  Widget build(BuildContext context) {
    final ownEnabled = !childDisabled;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: SwitchListTile.adaptive(
        title: Text(child.title),
        subtitle: Text(
          parentEnabled
              ? child.description
              : '${child.description}\n(Parent-Regel deaktiviert)',
          style: captionStyle,
        ),
        isThreeLine: !parentEnabled,
        value: ownEnabled,
        onChanged: parentEnabled ? (value) => onToggle(child.id, value) : null,
      ),
    );
  }
}

class _HouseRuleIssuesCard extends StatelessWidget {
  const _HouseRuleIssuesCard({required this.issues});

  final List<HouseRulePackIssue> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Probleme in Hausregel-Paketen',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  [
                    if (issue.packTitle.isNotEmpty) issue.packTitle,
                    issue.message,
                    if (issue.entryId.isNotEmpty) 'Eintrag: ${issue.entryId}',
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogContentPasswordCard extends ConsumerWidget {
  const _CatalogContentPasswordCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final visible = ref.watch(catalogContentVisibleProvider);

    return _SettingsSectionCard(
      title: 'Passwortschutz',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bestimmte Kataloginhalte (lange Erklärungen, Wirkung, Varianten) '
            'sind verschlüsselt und können mit dem passenden Passwort '
            'freigeschaltet werden. Eigens erstellte Einträge sind davon nicht betroffen.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (visible) ...[
            Row(
              children: [
                Icon(Icons.lock_open, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Katalog-Inhalte freigeschaltet',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _removePassword(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Passwort entfernen'),
            ),
          ] else
            FilledButton.icon(
              onPressed: () =>
                  showCatalogUnlockDialog(context: context, ref: ref),
              icon: const Icon(Icons.lock_open),
              label: const Text('Inhalte freischalten'),
            ),
        ],
      ),
    );
  }

  Future<void> _removePassword(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Passwort entfernen?'),
        content: const Text(
          'Geschützte Kataloginhalte werden danach wieder als gesperrt angezeigt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(settingsActionsProvider).setCatalogContentPassword(null);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Katalog-Passwort entfernt.')));
  }
}

class _AvatarApiSettingsPage extends ConsumerStatefulWidget {
  const _AvatarApiSettingsPage();

  @override
  ConsumerState<_AvatarApiSettingsPage> createState() =>
      _AvatarApiSettingsPageState();
}

class _AvatarApiSettingsPageState
    extends ConsumerState<_AvatarApiSettingsPage> {
  final _apiKeyController = TextEditingController();
  AvatarApiProvider _selectedProvider = AvatarApiProvider.openaiDalle3;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider).valueOrNull;
    if (settings != null) {
      _apiKeyController.text = settings.avatarApiConfig.apiKey;
      _selectedProvider = settings.avatarApiConfig.provider;
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SettingsPageList(
      children: [
        _SettingsSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Über eine KI-API können Heldenporträts generiert werden. '
                'Die Kosten werden über deinen eigenen API-Schlüssel abgerechnet.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AvatarApiProvider>(
                initialValue: _selectedProvider,
                decoration: const InputDecoration(
                  labelText: 'Anbieter',
                  border: OutlineInputBorder(),
                ),
                items: AvatarApiProvider.values
                    .map(
                      (provider) => DropdownMenuItem(
                        value: provider,
                        child: Text(provider.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedProvider = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: 'API-Schlüssel',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save),
                label: const Text('Speichern'),
              ),
              const SizedBox(height: 12),
              Text(
                'Der API-Schlüssel wird nur lokal auf diesem Gerät gespeichert '
                'und nie an Dritte übertragen.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveConfig() async {
    final config = AvatarApiConfig(
      provider: _selectedProvider,
      apiKey: _apiKeyController.text.trim(),
    );
    await ref.read(settingsActionsProvider).saveAvatarApiConfig(config);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bildgenerierung-Einstellungen gespeichert.'),
      ),
    );
  }
}

class _PathInfoTile extends StatelessWidget {
  const _PathInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
