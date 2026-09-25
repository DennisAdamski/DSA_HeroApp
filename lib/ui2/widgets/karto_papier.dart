import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Seitengrund der neuen Oberflaeche: `blatt`, hell mit Papierstruktur.
///
/// Die Struktur ist die vorhandene Pergamenttextur des Bestands, gekachelt und
/// per Multiplikation mit `blatt` eingefaerbt: ihr heller Grund faellt dadurch
/// auf `blatt` zurueck, nur die Fasern bleiben als leichte Abdunklung stehen.
/// Die Palette bleibt damit massgeblich, die Textur schattiert nur.
///
/// Dunkel ("Tiefdruck") bleibt der Grund glatt: auf `#101820` wuerde eine
/// abdunkelnde Faser verschwinden und eine aufhellende wie Staub wirken.
///
/// Liegt **hinter** allem Inhalt. Flaechen darauf (`feld`, `senke`) decken die
/// Struktur ab; sie zeigt sich nur auf dem freien Grund zwischen Abschnitten.
class KartoPapier extends StatelessWidget {
  /// Legt [child] auf den Seitengrund.
  const KartoPapier({super.key, required this.child});

  /// Inhalt ueber dem Grund.
  final Widget child;

  /// Die Textur, fuer Aufrufer, die sie vorab laden muessen (Rasterbilder).
  static const AssetImage textur = AssetImage(
    'assets/ui/codex/parchment_texture.png',
  );

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final hell = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: token.blatt,
        image: hell
            ? DecorationImage(
                image: textur,
                repeat: ImageRepeat.repeat,
                alignment: Alignment.topLeft,
                opacity: 0.4,
                colorFilter: ColorFilter.mode(token.blatt, BlendMode.multiply),
              )
            : null,
      ),
      child: child,
    );
  }
}
