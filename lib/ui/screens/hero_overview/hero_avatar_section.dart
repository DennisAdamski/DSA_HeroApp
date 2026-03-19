part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroAvatarSection on _HeroOverviewTabState {
  Widget _buildAvatarSection(HeroSheet hero) {
    final avatarFileName = hero.appearance.avatarFileName;
    final hasAvatar = avatarFileName.isNotEmpty;

    // Ohne Avatar nur kompakte Aktionszeile anzeigen.
    if (!hasAvatar) {
      return _AvatarActions(
        heroId: hero.id,
        hero: hero,
        hasAvatar: false,
        isEditing: _editController.isEditing,
      );
    }

    return _SectionCard(
      title: 'Portraet',
      child: Column(
        children: [
          _AvatarDisplay(heroId: hero.id, avatarFileName: avatarFileName),
          const SizedBox(height: _fieldSpacing),
          _AvatarActions(
            heroId: hero.id,
            hero: hero,
            hasAvatar: true,
            isEditing: _editController.isEditing,
          ),
        ],
      ),
    );
  }
}

class _AvatarDisplay extends ConsumerWidget {
  const _AvatarDisplay({
    required this.heroId,
    required this.avatarFileName,
  });

  final String heroId;
  final String avatarFileName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(heroStorageLocationProvider);

    return locationAsync.when(
      data: (location) {
        final storage = ref.read(avatarFileStorageProvider);
        final path = storage.resolveAvatarPath(
          heroStoragePath: location.effectivePath,
          avatarFileName: avatarFileName,
        );
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 350),
            child: Image.file(
              io.File(path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const _AvatarPlaceholder();
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const _AvatarPlaceholder(),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.person_outline,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AvatarActions extends ConsumerWidget {
  const _AvatarActions({
    required this.heroId,
    required this.hero,
    required this.hasAvatar,
    required this.isEditing,
  });

  final String heroId;
  final HeroSheet hero;
  final bool hasAvatar;
  final bool isEditing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiConfigured = ref.watch(avatarApiConfiguredProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (apiConfigured)
          FilledButton.icon(
            onPressed: () => _openGenerationDialog(context, ref),
            icon: const Icon(Icons.auto_awesome),
            label: Text(hasAvatar ? 'Neu generieren' : 'Portraet generieren'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _showApiKeyHint(context),
            icon: const Icon(Icons.key),
            label: const Text('API-Key einrichten'),
          ),
        if (hasAvatar && isEditing)
          OutlinedButton.icon(
            onPressed: () => _removeAvatar(context, ref),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Entfernen'),
          ),
      ],
    );
  }

  void _openGenerationDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AvatarGenerationDialog(
        heroId: heroId,
        hero: hero,
      ),
    );
  }

  void _showApiKeyHint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bitte richte zuerst einen API-Schluessel unter '
          'Einstellungen > Bildgenerierung ein.',
        ),
      ),
    );
  }

  Future<void> _removeAvatar(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Portraet entfernen?'),
        content: const Text('Das generierte Portraet wird unwiderruflich geloescht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Entfernen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref.read(heroActionsProvider).removeHeroAvatar(heroId);
  }
}
