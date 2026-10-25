import 'package:dsa_heldenverwaltung/domain/hero_proben_favorit.dart';

/// Höchstzahl häufiger Proben je Held.
///
/// Die Liste bleibt am Spieltisch überschaubar; eine längere Liste wäre
/// wieder die Probensuche.
const int kProbenFavoritenMax = 20;

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
  if (von < 0 || schritte == 0) return liste;
  final nach = (von + schritte).clamp(0, liste.length - 1);
  if (nach == von) return liste;
  final kopie = List<HeroProbenFavorit>.of(liste);
  final eintrag = kopie.removeAt(von);
  kopie.insert(nach, eintrag);
  return List<HeroProbenFavorit>.unmodifiable(kopie);
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
