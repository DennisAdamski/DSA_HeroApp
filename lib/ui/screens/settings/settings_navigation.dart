part of 'package:dsa_heldenverwaltung/ui/screens/settings_screen.dart';

enum _SettingsDestination {
  appearance,
  storage,
  catalog,
  houseRules,
  imageGeneration,
  legal,
  debugMode,
}

extension _SettingsDestinationX on _SettingsDestination {
  String get title => switch (this) {
    _SettingsDestination.appearance => 'Darstellung',
    _SettingsDestination.storage => 'Speicher',
    _SettingsDestination.catalog => 'Katalogverwaltung',
    _SettingsDestination.houseRules => 'Hausregeln',
    _SettingsDestination.imageGeneration => 'Bildgenerierung',
    _SettingsDestination.legal => 'Rechtliches',
    _SettingsDestination.debugMode => 'Debugmodus',
  };

  String get subtitle => switch (this) {
    _SettingsDestination.appearance => 'Dunkelmodus und Design',
    _SettingsDestination.storage => 'Heldenspeicher und Einstellungsordner',
    _SettingsDestination.catalog => 'Custom-Kataloge und Passwortschutz',
    _SettingsDestination.houseRules => 'Pakete aktivieren und verwalten',
    _SettingsDestination.imageGeneration => 'Anbieter und API-Schlüssel',
    _SettingsDestination.legal => 'Autor, Marken und Fan-Hinweis',
    _SettingsDestination.debugMode =>
      'Variablennamen statt Anzeigebezeichnungen',
  };

  IconData get icon => switch (this) {
    _SettingsDestination.appearance => Icons.palette_outlined,
    _SettingsDestination.storage => Icons.folder_outlined,
    _SettingsDestination.catalog => Icons.library_books_outlined,
    _SettingsDestination.houseRules => Icons.rule_folder_outlined,
    _SettingsDestination.imageGeneration => Icons.auto_awesome_outlined,
    _SettingsDestination.legal => Icons.info_outline,
    _SettingsDestination.debugMode => Icons.bug_report_outlined,
  };

  bool get isDirectToggle => this == _SettingsDestination.debugMode;

  ValueKey<String> get tileKey => ValueKey<String>('settings-menu-$name');

  ValueKey<String> get detailTitleKey =>
      ValueKey<String>('settings-detail-$name');

  Widget buildPage() => switch (this) {
    _SettingsDestination.appearance => const _AppearanceSettingsPage(),
    _SettingsDestination.storage => const _StorageSettingsPage(),
    _SettingsDestination.catalog => const _CatalogSettingsPage(),
    _SettingsDestination.houseRules => const _HouseRulesSettingsPage(),
    _SettingsDestination.imageGeneration => const _AvatarApiSettingsPage(),
    _SettingsDestination.legal => const _LegalSettingsPage(),
    _SettingsDestination.debugMode => const SizedBox.shrink(),
  };
}

class _SettingsSplitView extends StatelessWidget {
  const _SettingsSplitView({
    required this.selectedDestination,
    required this.onSelectDestination,
    required this.onToggleDebugMode,
  });

  final _SettingsDestination selectedDestination;
  final ValueChanged<_SettingsDestination> onSelectDestination;
  final Future<void> Function() onToggleDebugMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: _SettingsNavigationPane(
            selectedDestination: selectedDestination,
            showSelection: true,
            onSelectDestination: onSelectDestination,
            onToggleDebugMode: onToggleDebugMode,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _SettingsDetailPane(destination: selectedDestination)),
      ],
    );
  }
}

class _SettingsMenuOverview extends StatelessWidget {
  const _SettingsMenuOverview({
    required this.onSelectDestination,
    required this.onToggleDebugMode,
  });

  final ValueChanged<_SettingsDestination> onSelectDestination;
  final Future<void> Function() onToggleDebugMode;

  @override
  Widget build(BuildContext context) {
    return _SettingsNavigationPane(
      showSelection: false,
      onSelectDestination: onSelectDestination,
      onToggleDebugMode: onToggleDebugMode,
    );
  }
}

class _SettingsNavigationPane extends ConsumerWidget {
  const _SettingsNavigationPane({
    required this.showSelection,
    required this.onSelectDestination,
    required this.onToggleDebugMode,
    this.selectedDestination,
  });

  final bool showSelection;
  final _SettingsDestination? selectedDestination;
  final ValueChanged<_SettingsDestination> onSelectDestination;
  final Future<void> Function() onToggleDebugMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final debugModus = ref.watch(debugModusProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Bereiche', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          showSelection
              ? 'Wähle links einen Bereich und bearbeite die Details rechts.'
              : 'Öffne einen Bereich, um die zugehörigen Einstellungen zu sehen.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (
                var index = 0;
                index < _SettingsDestination.values.length;
                index++
              ) ...[
                if (index > 0) const Divider(height: 1),
                _buildMenuItem(
                  context: context,
                  destination: _SettingsDestination.values[index],
                  debugModus: debugModus,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required _SettingsDestination destination,
    required bool debugModus,
  }) {
    if (destination.isDirectToggle) {
      return SwitchListTile.adaptive(
        key: destination.tileKey,
        secondary: Icon(destination.icon),
        title: Text(destination.title),
        subtitle: Text(destination.subtitle),
        value: debugModus,
        onChanged: (_) => onToggleDebugMode(),
      );
    }

    return ListTile(
      key: destination.tileKey,
      leading: Icon(destination.icon),
      title: Text(destination.title),
      subtitle: Text(destination.subtitle),
      selected: showSelection && destination == selectedDestination,
      trailing: showSelection ? null : const Icon(Icons.chevron_right),
      onTap: () => onSelectDestination(destination),
    );
  }
}

class _SettingsDetailPane extends StatelessWidget {
  const _SettingsDetailPane({required this.destination});

  final _SettingsDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.title,
                key: destination.detailTitleKey,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(destination.subtitle, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: destination.buildPage()),
      ],
    );
  }
}

class _SettingsDetailScreen extends StatelessWidget {
  const _SettingsDetailScreen({required this.destination});

  final _SettingsDestination destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(destination.title)),
      body: destination.buildPage(),
    );
  }
}
