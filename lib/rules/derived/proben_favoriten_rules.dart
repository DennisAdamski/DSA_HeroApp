import 'package:dsa_heldenverwaltung/domain/hero_proben_favorit.dart';
import 'package:dsa_heldenverwaltung/rules/derived/liste_verschieben.dart';

/// Höchstzahl häufiger Proben je Held.
///
/// Die Liste bleibt am Spieltisch überschaubar; eine längere Liste wäre
/// wieder die Probensuche.
const int kProbenFavoritenMax = 20;

/// Stabiler Verweis auf eine Probe, etwa `talent:tal_klettern`.
///
/// Dasselbe Format wie die ID der häufigen Proben; Probenanfragen tragen ihn
/// ins Würfelprotokoll (`ResolvedProbeRequest.verweis`).
String probenVerweis(ProbenFavoritArt art, String ref) =>
    HeroProbenFavorit.von(art, ref).id;

/// Ob [favorit] in [liste] steht (Vergleich über die ID).
bool istProbenFavorit(
  Iterable<HeroProbenFavorit> liste,
  HeroProbenFavorit favorit,
) => liste.any((eintrag) => eintrag.id == favorit.id);

/// Ob [favorit] noch aufgenommen werden kann: schon enthalten oder Platz frei.
bool kannProbenFavoritAufnehmen(
  List<HeroProbenFavorit> liste,
  HeroProbenFavorit favorit,
) => istProbenFavorit(liste, favorit) || liste.length < kProbenFavoritenMax;

/// Nimmt [favorit] hinten auf oder entfernt ihn, wenn er schon in [liste] steht.
///
/// Ist die Liste voll, bleibt sie beim Aufnehmen unverändert; die Oberfläche
/// fragt vorher [kannProbenFavoritAufnehmen] ab und nennt den Grund. Einträge
/// mit unbekannter Art oder unbekannten Feldern bleiben unangetastet.
List<HeroProbenFavorit> schalteProbenFavorit(
  List<HeroProbenFavorit> liste,
  HeroProbenFavorit favorit,
) {
  if (istProbenFavorit(liste, favorit)) {
    return List<HeroProbenFavorit>.unmodifiable(
      liste.where((eintrag) => eintrag.id != favorit.id),
    );
  }
  if (liste.length >= kProbenFavoritenMax) return liste;
  return List<HeroProbenFavorit>.unmodifiable(<HeroProbenFavorit>[
    ...liste,
    favorit,
  ]);
}

/// Verschiebt den Favoriten mit der [id] um [schritte] Plätze (negativ nach
/// vorn). Unbekannte IDs und Verschiebungen über den Rand hinaus lassen die
/// Liste unverändert bzw. setzen den Eintrag an den Rand.
List<HeroProbenFavorit> verschiebeProbenFavorit(
  List<HeroProbenFavorit> liste,
  String id,
  int schritte,
) {
  final von = liste.indexWhere((eintrag) => eintrag.id == id);
  return verschiebeListenEintrag(liste, von, von + schritte);
}

/// Entfernt alle Favoriten mit den [ids].
List<HeroProbenFavorit> entferneProbenFavoriten(
  List<HeroProbenFavorit> liste,
  Set<String> ids,
) {
  if (ids.isEmpty) return liste;
  return List<HeroProbenFavorit>.unmodifiable(
    liste.where((eintrag) => !ids.contains(eintrag.id)),
  );
}
