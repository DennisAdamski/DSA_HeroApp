import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/workspace_header_stat_rail.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Kompakter Workspace-Header fuer Tablet- und Desktop-Layouts.
class WorkspaceHeroHeader extends ConsumerWidget {
  /// Erstellt den kombinierten Header aus Identitaetszeile und Kernwerte-Rail.
  const WorkspaceHeroHeader({
    super.key,
    required this.heroId,
    required this.hero,
  });

  /// ID des aktuell angezeigten Helden.
  final String heroId;

  /// Aktueller Held.
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codex = context.codexTheme;
    final theme = Theme.of(context);
    final portraitBytesAsync = ref.watch(activeAvatarBytesProvider(heroId));
    final activeEntry = _resolveActiveEntry(hero);

    return Container(
      key: const ValueKey<String>('workspace-hero-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        gradient: codex.heroGradient,
        border: Border(
          bottom: BorderSide(color: codex.rule.withValues(alpha: 0.88)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isPortraitTablet = width < 1024;
          final isDesktopWide = width >= 1366;
          final portraitWidth = isDesktopWide
              ? 124.0
              : isPortraitTablet
              ? 88.0
              : 104.0;
          final portraitHeight = isDesktopWide
              ? 82.0
              : isPortraitTablet
              ? 64.0
              : 72.0;
          final titleStyle =
              (isPortraitTablet
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.headlineMedium)
                  ?.copyWith(color: Colors.white);
          final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFFF4E7CF),
            height: 1.25,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _WorkspaceHeroPortrait(
                    heroName: hero.name,
                    activeEntry: activeEntry,
                    portraitBytesAsync: portraitBytesAsync,
                    width: portraitWidth,
                    height: portraitHeight,
                  ),
                  SizedBox(width: isPortraitTablet ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hero.name,
                          maxLines: isPortraitTablet ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _roleText(hero),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isPortraitTablet ? 10 : 16),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeaderInfoChip(
                        label: 'Stufe',
                        value: hero.level.toString(),
                        icon: Icons.workspace_premium_outlined,
                      ),
                      _HeaderInfoChip(
                        label: 'AP frei',
                        value: hero.apAvailable.toString(),
                        icon: Icons.account_balance_wallet_outlined,
                        highlight: hero.apAvailable > 0,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              WorkspaceHeaderStatRail(
                heroId: heroId,
                hero: hero,
                variant: WorkspaceHeaderStatRailVariant.embedded,
              ),
            ],
          );
        },
      ),
    );
  }

  AvatarGalleryEntry? _resolveActiveEntry(HeroSheet hero) {
    final gallery = hero.appearance.avatarGallery;
    if (gallery.isEmpty) return null;

    final aktivesBildId = hero.appearance.aktivesBildId;
    if (aktivesBildId.isNotEmpty) {
      for (final entry in gallery) {
        if (entry.id == aktivesBildId) return entry;
      }
    }
    final avatarFileName = hero.appearance.avatarFileName;
    if (avatarFileName.isNotEmpty) {
      for (final entry in gallery) {
        if (entry.fileName == avatarFileName) return entry;
      }
    }
    final primaerbildId = hero.appearance.primaerbildId;
    if (primaerbildId.isNotEmpty) {
      for (final entry in gallery) {
        if (entry.id == primaerbildId) return entry;
      }
    }
    return null;
  }

  String _roleText(HeroSheet hero) {
    final parts = <String>[
      if (hero.background.profession.trim().isNotEmpty)
        hero.background.profession.trim(),
      if (hero.background.kultur.trim().isNotEmpty)
        hero.background.kultur.trim(),
      if (hero.background.rasse.trim().isNotEmpty) hero.background.rasse.trim(),
    ];
    if (parts.isEmpty) {
      return 'Unbeschriebener Held';
    }
    return parts.join(' | ');
  }
}

/// Flacher Portraet-Slot fuer den kompakten Workspace-Header.
class _WorkspaceHeroPortrait extends StatelessWidget {
  const _WorkspaceHeroPortrait({
    required this.heroName,
    required this.activeEntry,
    required this.portraitBytesAsync,
    required this.width,
    required this.height,
  });

  final String heroName;
  final AvatarGalleryEntry? activeEntry;
  final AsyncValue<List<int>?> portraitBytesAsync;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(
          color: const Color(0xFFD8B985).withValues(alpha: 0.84),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: portraitBytesAsync.when(
        data: (bytes) {
          if (bytes == null || bytes.isEmpty) {
            return _InitialsPortrait(heroName: heroName);
          }
          return _HeaderPortraitImage(bytes: bytes, activeEntry: activeEntry);
        },
        loading: () => Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: codex.brass,
            ),
          ),
        ),
        error: (_, _) => _InitialsPortrait(heroName: heroName),
      ),
    );
  }
}

/// Zeigt das aktive Avatar-Bild mit gespeichertem Fokuspunkt als breiten Header-Ausschnitt.
class _HeaderPortraitImage extends StatelessWidget {
  const _HeaderPortraitImage({required this.bytes, required this.activeEntry});

  final List<int> bytes;
  final AvatarGalleryEntry? activeEntry;

  @override
  Widget build(BuildContext context) {
    final focusX = activeEntry?.headerFocusX ?? 0.5;
    final focusY = activeEntry?.headerFocusY ?? 0.5;
    final zoom = (activeEntry?.headerZoom ?? 1.0).clamp(1.0, 8.0);
    final alignment = Alignment((focusX * 2) - 1, (focusY * 2) - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: Transform.scale(
            scale: zoom,
            alignment: alignment,
            child: Image.memory(
              Uint8List.fromList(bytes),
              key: const ValueKey<String>('workspace-header-portrait-image'),
              fit: BoxFit.cover,
              alignment: alignment,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
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
    );
  }
}

/// Fallback-Karte mit Initialen, wenn kein Primärbild verfügbar ist.
class _InitialsPortrait extends StatelessWidget {
  const _InitialsPortrait({required this.heroName});

  final String heroName;

  @override
  Widget build(BuildContext context) {
    final initials = heroName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 0.18,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              'assets/ui/codex/arcane_seal.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        Center(
          child: Text(
            key: const ValueKey<String>('workspace-header-portrait-initials'),
            initials.isEmpty ? '?' : initials,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontFamily: 'Cinzel',
            ),
          ),
        ),
      ],
    );
  }
}

/// Kleine Kennzahl-Kachel für die Identitätszeile des Headers.
class _HeaderInfoChip extends StatelessWidget {
  const _HeaderInfoChip({
    required this.label,
    required this.value,
    this.icon,
    this.highlight = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = highlight
        ? const Color(0xFFD8B985).withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.18);
    final backgroundColor = highlight
        ? const Color(0xFFD0A35A).withValues(alpha: 0.2)
        : Colors.white.withValues(alpha: 0.06);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFFEADCC5)),
            const SizedBox(width: 6),
          ],
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFEADCC5),
                    letterSpacing: 0.4,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
