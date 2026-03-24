import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';

/// Umschliessende Seite mit dekorativem Codex-Hintergrund.
class CodexPageScaffold extends StatelessWidget {
  /// Erstellt einen dekorativen Seitenrahmen fuer datenintensive Screens.
  const CodexPageScaffold({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  /// Seiteninhalt.
  final Widget child;

  /// Optionales Aussenpadding.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final codex = context.codexTheme;

    if (!codex.showDecoration) {
      return Container(
        color: codex.parchment,
        padding: padding,
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: codex.parchment,
        image: const DecorationImage(
          image: AssetImage('assets/ui/codex/parchment_texture.png'),
          fit: BoxFit.cover,
          opacity: 0.04,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned(
            right: -24,
            top: -18,
            child: _CodexWatermark(
              assetPath: 'assets/ui/codex/arcane_seal.png',
            ),
          ),
          const Positioned(
            left: -10,
            bottom: -18,
            child: _CodexWatermark(
              assetPath: 'assets/ui/codex/compass_mark.png',
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _CodexWatermark extends StatelessWidget {
  const _CodexWatermark({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.1,
        child: Image.asset(assetPath, width: 140, height: 140),
      ),
    );
  }
}
