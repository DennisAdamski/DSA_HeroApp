import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Art einer favorisierten Probe.
///
/// Die Arten entsprechen den Kategorien der Probensuche. Gespeichert wird nur
/// die [kennung]; eine Art, die diese App-Version nicht kennt, bleibt als
/// Favorit mit `art == null` erhalten (siehe [HeroProbenFavorit.art]).
enum ProbenFavoritArt {
  /// Eigenschaftsprobe; der Verweis ist das Eigenschaftskürzel (`MU` …).
  eigenschaft('eigenschaft'),

  /// Kampf-Schnellprobe; der Verweis ist `attacke`, `parade` oder `ausweichen`.
  kampf('kampf'),

  /// Talentprobe; der Verweis ist die Katalog-ID des Talents.
  talent('talent'),

  /// Zauberprobe; der Verweis ist die Katalog-ID des Zaubers.
  zauber('zauber');

  const ProbenFavoritArt(this.kennung);

  /// Stabile Kennung im gespeicherten [HeroProbenFavorit.id].
  final String kennung;
}

/// Eine vom Spieler häufig gewürfelte Probe (ARCH-01, persönliche Favoriten).
///
/// Gespeichert wird nur ein Verweis (Art und Katalog-ID bzw. Kürzel), nie ein
/// Anzeigename oder ein berechneter Wert: Probenziel, Wert und Herleitung
/// entstehen beim Würfeln aus dem aktuellen Helden wie in der Probensuche.
///
/// Die [id] setzt sich aus Art und Verweis zusammen (`talent:tal_klettern`).
/// Sie ist deterministisch, damit zwei Geräte, die dieselbe Probe markieren,
/// denselben Eintrag schreiben und der Sync-Merge die Liste je Element
/// zusammenführt (`sync_zusammenfuehrung.dart`) statt einen Konflikt zu
/// melden. Die Reihenfolge der Liste am Helden ist die Anzeigereihenfolge.
class HeroProbenFavorit {
  /// Favorit mit der gespeicherten [id].
  const HeroProbenFavorit({
    required this.id,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Favorit der [art] mit dem Verweis [ref].
  factory HeroProbenFavorit.von(ProbenFavoritArt art, String ref) =>
      HeroProbenFavorit(id: '${art.kennung}$_trenner${ref.trim()}');

  static const String _trenner = ':';

  /// Art und Verweis, durch `:` getrennt.
  final String id;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'id'};

  /// Art der Probe; `null` bei einer Art, die diese Version nicht kennt.
  ProbenFavoritArt? get art {
    final kennung = _kennung;
    for (final art in ProbenFavoritArt.values) {
      if (art.kennung == kennung) return art;
    }
    return null;
  }

  /// Verweis innerhalb der Art (Katalog-ID, Kürzel oder Kampfwert).
  String get ref {
    final stelle = id.indexOf(_trenner);
    return stelle < 0 ? '' : id.substring(stelle + 1);
  }

  String get _kennung {
    final stelle = id.indexOf(_trenner);
    return stelle < 0 ? id : id.substring(0, stelle);
  }

  /// Ob der Favorit eine gültige Art und einen Verweis trägt.
  bool get istBekannt => art != null && ref.isNotEmpty;

  HeroProbenFavorit copyWith({
    String? id,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroProbenFavorit(
      id: id ?? this.id,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{'id': id}, unbekannteFelder);
  }

  /// Liest einen Favoriten; `null` ohne verwertbare [id].
  static HeroProbenFavorit? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) return null;
    return HeroProbenFavorit(
      id: id,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

/// Liest die Favoritenliste; doppelte IDs und unlesbare Einträge entfallen.
///
/// Die erste Fundstelle zählt, die Reihenfolge bleibt erhalten.
List<HeroProbenFavorit> leseProbenFavoriten(Object? roh) {
  if (roh is! List) return const <HeroProbenFavorit>[];
  final gesehen = <String>{};
  final ergebnis = <HeroProbenFavorit>[];
  for (final eintrag in roh) {
    if (eintrag is! Map) continue;
    final favorit = HeroProbenFavorit.fromJson(
      Map<String, dynamic>.from(eintrag),
    );
    if (favorit != null && gesehen.add(favorit.id)) ergebnis.add(favorit);
  }
  return List<HeroProbenFavorit>.unmodifiable(ergebnis);
}
