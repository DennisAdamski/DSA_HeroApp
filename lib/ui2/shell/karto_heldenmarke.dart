import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Identitaetsbereich der dunklen Bereichsnavigation.
///
/// Zeigt, wessen Bogen offen ist: Bild oder Monogramm, Name, Herkunft. Rein
/// darstellend — das Bild kommt als fertiges Widget von der Bestandsbruecke,
/// weil Avatare ausschliesslich ueber `AvatarGalleryImage` gerendert werden.
///
/// Bild und Monogramm tragen dieselbe Ringfassung. Der Ring ist damit die
/// Konstante und nur sein Inhalt wechselt; ohne ihn saehen Helden mit und ohne
/// Bild an dieser Stelle verschieden gebaut aus.
class KartoHeldenmarke extends StatelessWidget {
  /// Erstellt die Marke fuer genau einen Helden.
  const KartoHeldenmarke({
    super.key,
    required this.name,
    this.herkunft,
    this.bild,
    this.groesse = 96,
  });

  /// Ausgeschriebener Heldenname.
  final String name;

  /// Ruhige Zweitzeile, etwa die Profession. Leer wird weggelassen.
  final String? herkunft;

  /// Baut das Bild der Bruecke um den uebergebenen Ersatz herum.
  ///
  /// Callback statt fertigem Widget, weil der Ersatz das Monogramm ist und
  /// dieses hier entsteht. Ein `null` zeigt direkt das Monogramm.
  final Widget Function(Widget ersatz)? bild;

  /// Kantenlaenge der Fassung.
  final double groesse;

  // Erster Buchstabe des Namens; leere Namen bekommen ein neutrales Zeichen,
  // damit die Fassung nie leer steht.
  String get _monogramm {
    final getrimmt = name.trim();
    if (getrimmt.isEmpty) return '?';
    return getrimmt.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final token = KartoTheme.of(context);
    final texte = Theme.of(context).textTheme;
    final zweitzeile = herkunft?.trim() ?? '';

    final monogramm = Center(
      child: Text(
        _monogramm,
        style: texte.titelGross.copyWith(
          color: token.navigationMuted,
          height: 1,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: groesse,
          height: groesse,
          // Der Ring liegt im Vordergrund, damit ein randvolles Bild ihn
          // nicht ueberdeckt.
          child: Container(
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: token.navigationMuted,
                width: Strich.grat,
              ),
            ),
            child: ClipOval(child: bild?.call(monogramm) ?? monogramm),
          ),
        ),
        const SizedBox(height: Abstand.weit),
        Tooltip(
          message: name,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: texte.titel.copyWith(color: token.navigationText),
          ),
        ),
        if (zweitzeile.isNotEmpty) ...[
          const SizedBox(height: Abstand.eng),
          Text(
            zweitzeile,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: texte.etikett.copyWith(color: token.navigationMuted),
          ),
        ],
      ],
    );
  }
}
