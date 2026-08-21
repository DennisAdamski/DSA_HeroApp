import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/avatar_load_failure.dart';
import 'package:dsa_heldenverwaltung/state/avatar_providers.dart';

/// Zeigt ein Avatarbild anhand seines Galerie-Dateinamens.
///
/// Die Bytes kommen aus [avatarBytesProvider] und werden bewusst unveraendert
/// an `Image.memory` gereicht, damit der globale `ImageCache` greift.
///
/// Unterscheidet drei Zustaende: Laden, fehlendes Bild und Fehlschlag. Im Web
/// braucht ein Bild drei sequentielle Netzwerkaufrufe — ohne eigenen
/// Ladezustand sieht das sekundenlang nach Fehler aus. Und ein Fehlschlag
/// nennt seinen Grund, statt still wie ein fehlendes Bild auszusehen.
class AvatarGalleryImage extends ConsumerWidget {
  const AvatarGalleryImage({
    super.key,
    required this.heroId,
    required this.fileName,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.scale,
    this.placeholder,
  });

  /// Held, zu dem das Bild gehoert.
  final String heroId;

  /// Dateiname des Galerie-Eintrags.
  final String fileName;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Bildausschnitt, genutzt vom kompakten Workspace-Header.
  final Alignment alignment;

  /// Zoomfaktor des Ausschnitts; `null` laesst das Bild unskaliert.
  final double? scale;

  /// Ersatzdarstellung bei fehlendem oder nicht ladbarem Bild.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytesAsync = ref.watch(
      avatarBytesProvider((heroId: heroId, fileName: fileName)),
    );

    return bytesAsync.when(
      loading: _buildLoading,
      error: (error, _) => _buildError(context, error),
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) {
          return _buildPlaceholder();
        }
        Widget image = Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          alignment: alignment,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
        final zoom = scale;
        if (zoom != null && zoom != 1.0) {
          image = Transform.scale(
            scale: zoom,
            alignment: alignment,
            child: image,
          );
        }
        return image;
      },
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return placeholder ?? const SizedBox.shrink();
  }

  /// Zeigt den Platzhalter, nennt den Grund aber im Tooltip.
  ///
  /// Die technischen [AvatarLoadException.details] gehoeren mit in den Tooltip:
  /// Ohne sie bleibt ausgerechnet der Sammelfall `unbekannt` unerklaert.
  Widget _buildError(BuildContext context, Object error) {
    final String message;
    if (error is AvatarLoadException) {
      final details = error.details;
      message = details == null || details.isEmpty
          ? error.meldung
          : '${error.meldung}\n$details';
    } else {
      message = 'Unerwarteter Fehler.\n$error';
    }
    return Tooltip(
      message: message,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          _buildPlaceholder(),
          Positioned(
            right: 4,
            bottom: 4,
            child: Icon(
              Icons.error_outline,
              size: 16,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
