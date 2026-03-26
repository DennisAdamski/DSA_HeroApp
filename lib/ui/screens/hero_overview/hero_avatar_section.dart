part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

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
        return GestureDetector(
          onTap: () => _openFullscreen(context, path),
          child: ClipRRect(
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

  void _openFullscreen(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      builder: (context) => _AvatarFullscreenDialog(imagePath: path),
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
        OutlinedButton.icon(
          onPressed: () => _uploadImage(context, ref),
          icon: const Icon(Icons.upload_file),
          label: const Text('Bild hochladen'),
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

  Future<void> _uploadImage(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (!context.mounted) return;

    await ref.read(heroActionsProvider).uploadHeroImage(
      heroId: heroId,
      imageBytes: bytes,
    );
  }

  Future<void> _removeAvatar(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Portraet entfernen?'),
        content: const Text(
          'Das generierte Portraet wird unwiderruflich geloescht.',
        ),
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

// ---------------------------------------------------------------------------
// Vollbild-Dialog fuer Avatar-Bilder
// ---------------------------------------------------------------------------

class _AvatarFullscreenDialog extends StatelessWidget {
  const _AvatarFullscreenDialog({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(
                io.File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar-Galerie-Streifen
// ---------------------------------------------------------------------------

class _AvatarGalleryStrip extends ConsumerWidget {
  const _AvatarGalleryStrip({
    required this.heroId,
    required this.gallery,
    required this.primaerbildId,
  });

  final String heroId;
  final List<AvatarGalleryEntry> gallery;
  final String primaerbildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (gallery.isEmpty) return const SizedBox.shrink();

    final locationAsync = ref.watch(heroStorageLocationProvider);
    final snapshotDiff = ref.watch(avatarSnapshotDiffProvider(heroId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Galerie', style: Theme.of(context).textTheme.titleSmall),
            if (snapshotDiff != null && snapshotDiff.hatAenderungen) ...[
              const SizedBox(width: 8),
              Tooltip(
                message: 'Der Held hat sich seit dem Primaerbild veraendert.',
                child: Chip(
                  avatar: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  label: const Text('Aenderungen'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: locationAsync.when(
            data: (location) {
              final storage = ref.read(avatarFileStorageProvider);
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: gallery.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = gallery[index];
                  final isPrimaer = entry.id == primaerbildId;
                  final path = storage.resolveAvatarPath(
                    heroStoragePath: location.effectivePath,
                    avatarFileName: entry.fileName,
                  );
                  return _GalleryThumbnail(
                    heroId: heroId,
                    entry: entry,
                    path: path,
                    isPrimaer: isPrimaer,
                  );
                },
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _GalleryThumbnail extends ConsumerWidget {
  const _GalleryThumbnail({
    required this.heroId,
    required this.entry,
    required this.path,
    required this.isPrimaer,
  });

  final String heroId;
  final AvatarGalleryEntry entry;
  final String path;
  final bool isPrimaer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      onLongPress: () => _showContextMenu(context, ref),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Image.file(
                io.File(path),
                fit: BoxFit.cover,
                cacheWidth: 144,
                errorBuilder: (_, _, _) => Container(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined, size: 24),
                ),
              ),
            ),
          ),
          if (isPrimaer)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.star,
                  size: 14,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _AvatarFullscreenDialog(imagePath: path),
    );
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Vergroessern'),
              onTap: () {
                Navigator.pop(context);
                _openFullscreen(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Als aktives Bild setzen'),
              onTap: () {
                Navigator.pop(context);
                ref.read(heroActionsProvider).setActiveAvatar(
                  heroId: heroId,
                  galleryEntryId: entry.id,
                );
              },
            ),
            ListTile(
              leading: Icon(
                isPrimaer ? Icons.star : Icons.star_outline,
              ),
              title: Text(
                isPrimaer
                    ? 'Primaerbild (aktiv)'
                    : 'Als Primaerbild setzen',
              ),
              enabled: !isPrimaer,
              onTap: isPrimaer
                  ? null
                  : () {
                      Navigator.pop(context);
                      ref.read(heroActionsProvider).setPrimaerbild(
                        heroId: heroId,
                        galleryEntryId: entry.id,
                      );
                    },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Entfernen'),
              onTap: () {
                Navigator.pop(context);
                ref.read(heroActionsProvider).removeGalleryImage(
                  heroId: heroId,
                  galleryEntryId: entry.id,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
