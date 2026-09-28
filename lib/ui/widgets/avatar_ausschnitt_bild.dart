import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';

/// Ausrichtung ohne Befund: horizontal mittig, vertikal im oberen Bereich.
///
/// Bei Querformat hat `BoxFit.cover` keinen vertikalen Ueberstand, der Wert
/// wirkt dann nicht. Bei Hochformat zeigt er Kopf statt Brust — naeherungsweise
/// derselbe Rueckfall wie `berechneAvatarAusschnitt` ohne Gesicht.
const Alignment kAvatarRueckfallAusrichtung = Alignment(0, -0.4);

/// Zeigt einen Avatar als Ausschnitt, der sich am erkannten Gesicht ausrichtet.
///
/// Rein darstellend: Bytes und Befund kommen vom Aufrufer, in der Regel von
/// `AvatarGalleryImage`. Die Bytes gehen unveraendert an `Image.memory`, damit
/// der globale `ImageCache` greift. Der Ausschnitt entsteht, indem das ganze
/// Bild so gross gezeichnet und verschoben wird, dass genau der berechnete
/// Bereich die Flaeche fuellt; verzerrt wird dabei nichts, weil der Ausschnitt
/// dasselbe Seitenverhaeltnis hat wie die Flaeche.
class AvatarAusschnittBild extends StatelessWidget {
  const AvatarAusschnittBild({
    super.key,
    required this.bytes,
    required this.befund,
    required this.rahmung,
    this.imageKey,
    this.fehlerErsatz,
  });

  final Uint8List bytes;

  /// Gesichtsbefund; ohne ihn gilt der Rueckfall-Ausschnitt.
  final AvatarGesichtsbefund? befund;

  final AvatarRahmung rahmung;

  /// Key fuer das innere `Image`, fuer Tests und bestehende Finder.
  final Key? imageKey;

  /// Ersatz, falls das Bild selbst nicht dekodierbar ist.
  final Widget? fehlerErsatz;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final flaeche = constraints.biggest;
        final befund = this.befund;
        if (befund == null ||
            !flaeche.width.isFinite ||
            !flaeche.height.isFinite ||
            flaeche.isEmpty) {
          return _bild(
            fit: BoxFit.cover,
            alignment: kAvatarRueckfallAusrichtung,
          );
        }

        final ausschnitt = berechneAvatarAusschnitt(
          bildBreite: befund.bildBreite,
          bildHoehe: befund.bildHoehe,
          seitenverhaeltnis: flaeche.width / flaeche.height,
          rahmung: rahmung,
          gesicht: befund.gesicht,
        );
        final bildBreite = flaeche.width / ausschnitt.breite;
        final bildHoehe = flaeche.height / ausschnitt.hoehe;
        return ClipRect(
          child: SizedBox.fromSize(
            size: flaeche,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: -ausschnitt.links * bildBreite,
                  top: -ausschnitt.oben * bildHoehe,
                  width: bildBreite,
                  height: bildHoehe,
                  child: _bild(fit: BoxFit.fill, alignment: Alignment.center),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bild({required BoxFit fit, required Alignment alignment}) {
    return Image.memory(
      bytes,
      key: imageKey,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          fehlerErsatz ?? const SizedBox.shrink(),
    );
  }
}
