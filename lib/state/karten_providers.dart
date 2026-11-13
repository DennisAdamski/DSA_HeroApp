import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';

/// Adresse der Kartenkacheln, oder `null`, wenn keine konfiguriert sind.
final kartenKachelBasisProvider = Provider<Uri?>((ref) {
  if (kKartenKachelBasis.isEmpty) return null;
  final basis = Uri.tryParse(kKartenKachelBasis);
  if (basis == null || basis.scheme != 'https') return null;
  return basis;
});

/// Das Manifest der Kartenkacheln, einmal je Sitzung geladen; `null` ohne
/// Kacheln oder bei einem Fehler (die Karte zeichnet dann ohne Kartenbild).
final kartenKachelManifestProvider = FutureProvider<KartenKachelManifest?>((
  ref,
) async {
  final basis = ref.watch(kartenKachelBasisProvider);
  if (basis == null) return null;
  return ladeKartenKachelManifest(basis);
});
