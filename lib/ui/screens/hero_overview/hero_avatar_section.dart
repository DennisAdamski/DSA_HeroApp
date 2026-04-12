part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

Future<void> _pickAndUploadImage(
  BuildContext context,
  WidgetRef ref,
  String heroId,
) async {
  final result = await FilePicker.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final bytes = result.files.first.bytes;
  if (bytes == null || bytes.isEmpty) return;
  if (!context.mounted) return;
  await ref
      .read(heroActionsProvider)
      .uploadHeroImage(heroId: heroId, imageBytes: bytes);
}

class _AvatarDisplay extends ConsumerWidget {
  const _AvatarDisplay({required this.heroId, required this.avatarFileName});

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
                  return const _SketchedAvatarPlaceholder();
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
      error: (_, _) => const _SketchedAvatarPlaceholder(),
    );
  }

  void _openFullscreen(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      builder: (context) => _AvatarFullscreenDialog(imagePath: path),
    );
  }
}

class _SketchedAvatarPlaceholder extends StatelessWidget {
  const _SketchedAvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colorScheme.outlineVariant,
          borderRadius: 12,
          dashWidth: 6,
          dashSpace: 4,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                size: 72,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Kein Portraet',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashSpace,
  });

  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.borderRadius != borderRadius ||
      old.dashWidth != dashWidth ||
      old.dashSpace != dashSpace;
}

class _NoAvatarActions extends ConsumerWidget {
  const _NoAvatarActions({required this.heroId, required this.hero});

  final String heroId;
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiConfigured = ref.watch(avatarApiConfiguredProvider);

    if (apiConfigured) {
      return FilledButton.icon(
        onPressed: () => _openGenerationDialog(context, ref),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Avatar generieren'),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _pickAndUploadImage(context, ref, heroId),
      icon: const Icon(Icons.upload_file),
      label: const Text('Bild hochladen'),
    );
  }

  void _openGenerationDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AvatarGenerationDialog(heroId: heroId, hero: hero),
    );
  }
}

class _HasAvatarActions extends ConsumerWidget {
  const _HasAvatarActions({required this.heroId, required this.hero});

  final String heroId;
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiConfigured = ref.watch(avatarApiConfiguredProvider);
    final gallery = hero.appearance.avatarGallery;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (apiConfigured)
          FilledButton.icon(
            onPressed: () => _openGenerationDialog(context, ref),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Neu generieren'),
          ),
        OutlinedButton.icon(
          onPressed: () => _pickAndUploadImage(context, ref, heroId),
          icon: const Icon(Icons.upload_file),
          label: const Text('Bild hochladen'),
        ),
        if (gallery.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _openAlbum(context),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text('Avatar Album (${gallery.length})'),
          ),
      ],
    );
  }

  void _openGenerationDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) => AvatarGenerationDialog(heroId: heroId, hero: hero),
    );
  }

  void _openAlbum(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _AvatarAlbumDialog(heroId: heroId, hero: hero),
    );
  }
}

class _AvatarAlbumDialog extends ConsumerWidget {
  const _AvatarAlbumDialog({required this.heroId, required this.hero});

  final String heroId;
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = hero.appearance.avatarGallery;
    final primaerbildId = hero.appearance.primaerbildId;
    final locationAsync = ref.watch(heroStorageLocationProvider);
    final snapshotDiff = ref.watch(avatarSnapshotDiffProvider(heroId));

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Avatar Album',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (snapshotDiff != null && snapshotDiff.hatAenderungen) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message:
                          'Der Held hat sich seit dem Primärbild verändert.',
                      child: Chip(
                        avatar: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: const Text('Änderungen'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: locationAsync.when(
                  data: (location) {
                    final storage = ref.read(avatarFileStorageProvider);
                    return GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: gallery.length,
                      itemBuilder: (context, index) {
                        final entry = gallery[index];
                        final isPrimaer = entry.id == primaerbildId;
                        final path = storage.resolveAvatarPath(
                          heroStoragePath: location.effectivePath,
                          avatarFileName: entry.fileName,
                        );
                        return _AlbumCard(
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
                  error: (_, _) => const Center(
                    child: Text('Fehler beim Laden der Galerie.'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  const _AlbumCard({
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  io.File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, size: 32),
                  ),
                ),
              ),
              if (isPrimaer)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.star,
                      size: 14,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              tooltip: 'Vergrößern',
              icon: const Icon(Icons.fullscreen),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => _openFullscreen(context),
            ),
            IconButton(
              tooltip: 'Header-Ausschnitt',
              icon: const Icon(Icons.filter_center_focus),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => _openHeaderFocusDialog(context),
            ),
            IconButton(
              tooltip: 'Als aktives Bild setzen',
              icon: const Icon(Icons.image_outlined),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => ref
                  .read(heroActionsProvider)
                  .setActiveAvatar(heroId: heroId, galleryEntryId: entry.id),
            ),
            IconButton(
              tooltip: isPrimaer ? 'Ist Primärbild' : 'Als Primärbild setzen',
              icon: Icon(isPrimaer ? Icons.star : Icons.star_outline),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              color: isPrimaer ? colorScheme.primary : null,
              onPressed: isPrimaer
                  ? null
                  : () => ref
                        .read(heroActionsProvider)
                        .setPrimaerbild(
                          heroId: heroId,
                          galleryEntryId: entry.id,
                        ),
            ),
            IconButton(
              tooltip: 'Entfernen',
              icon: const Icon(Icons.delete_outline),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmRemove(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _AvatarFullscreenDialog(imagePath: path),
    );
  }

  void _openHeaderFocusDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) =>
          _HeaderFocusDialog(heroId: heroId, entry: entry, imagePath: path),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bild entfernen?'),
        content: const Text('Das Bild wird unwiderruflich gelöscht.'),
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
    await ref
        .read(heroActionsProvider)
        .removeGalleryImage(heroId: heroId, galleryEntryId: entry.id);
  }
}

class _HeaderFocusDialog extends ConsumerStatefulWidget {
  const _HeaderFocusDialog({
    required this.heroId,
    required this.entry,
    required this.imagePath,
  });

  final String heroId;
  final AvatarGalleryEntry entry;
  final String imagePath;

  @override
  ConsumerState<_HeaderFocusDialog> createState() => _HeaderFocusDialogState();
}

class _HeaderFocusDialogState extends ConsumerState<_HeaderFocusDialog> {
  late Offset _focusPoint;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _focusPoint = Offset(
      widget.entry.headerFocusX ?? 0.5,
      widget.entry.headerFocusY ?? 0.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Header-Ausschnitt', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Tippe im Bild auf den Bereich, der im kompakten Workspace-Header sichtbar sein soll.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text('Vorschau', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 4.8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          io.File(widget.imagePath),
                          fit: BoxFit.cover,
                          alignment: Alignment(
                            (_focusPoint.dx * 2) - 1,
                            (_focusPoint.dy * 2) - 1,
                          ),
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 32),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.06),
                                Colors.black.withValues(alpha: 0.26),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Fokuspunkt setzen', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          final width = constraints.maxWidth;
                          final height = constraints.maxHeight;
                          if (width <= 0 || height <= 0) {
                            return;
                          }
                          setState(() {
                            _focusPoint = Offset(
                              (details.localPosition.dx / width)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                              (details.localPosition.dy / height)
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                            );
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              io.File(widget.imagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.12),
                              ),
                            ),
                            Positioned(
                              left:
                                  (_focusPoint.dx * constraints.maxWidth) - 16,
                              top:
                                  (_focusPoint.dy * constraints.maxHeight) - 16,
                              child: IgnorePointer(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.16),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.center_focus_strong,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _saveFocus,
                    child: Text(_saving ? 'Speichert...' : 'Übernehmen'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveFocus() async {
    setState(() {
      _saving = true;
    });
    try {
      await ref
          .read(heroActionsProvider)
          .setAvatarHeaderFocus(
            heroId: widget.heroId,
            galleryEntryId: widget.entry.id,
            focusX: _focusPoint.dx,
            focusY: _focusPoint.dy,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
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
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 64),
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
