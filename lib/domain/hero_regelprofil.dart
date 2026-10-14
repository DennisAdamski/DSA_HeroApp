import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Ein Hausregel-Paket im Regelprofil eines Helden (ARCH-04).
///
/// Das Profil trägt das Paket als **Kopie** des Manifests samt Prüfsumme. So
/// rechnet der Held nach einem App-Update mit dem alten Stand weiter, bis ein
/// Update bewusst übernommen wird, und ein fehlendes Paket verschwindet nicht.
class HeroRegelProfilPaket {
  /// Paket [paketId] mit der Kopie [manifest] und deren [pruefsumme].
  HeroRegelProfilPaket({
    required this.paketId,
    required this.pruefsumme,
    required Map<String, Object?> manifest,
    this.unbekannteFelder = const <String, Object?>{},
  }) : manifest = Map<String, Object?>.unmodifiable(
         kopiereJsonRohwert(manifest)! as Map<String, Object?>,
       );

  /// Stabile Paket-ID (`epic_rules_v1`, `regelwerk_ueberarbeitung_v1_combat` …).
  ///
  /// Der Schlüssel heißt bewusst nicht `id`: Der Sync-Merge spaltet Listen mit
  /// `id`-Einträgen elementweise auf; ein Profil muss aber atomar bleiben.
  final String paketId;

  /// Prüfsumme des Manifests zum Zeitpunkt der Übernahme (siehe
  /// `stempelRegelprofilPaket`).
  final String pruefsumme;

  /// Kopie des Manifests (Patches, Priorität, Eltern-Paket).
  final Map<String, Object?> manifest;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'paketId',
    'pruefsumme',
    'manifest',
  };

  HeroRegelProfilPaket copyWith({
    String? paketId,
    String? pruefsumme,
    Map<String, Object?>? manifest,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroRegelProfilPaket(
      paketId: paketId ?? this.paketId,
      pruefsumme: pruefsumme ?? this.pruefsumme,
      manifest: manifest ?? this.manifest,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'paketId': paketId,
      'pruefsumme': pruefsumme,
      'manifest': kopiereJsonRohwert(manifest),
    }, unbekannteFelder);
  }

  /// Liest ein Paket; `null`, wenn kein Manifest-Objekt vorliegt.
  static HeroRegelProfilPaket? fromJson(Map<String, dynamic> json) {
    final rohManifest = json['manifest'];
    if (rohManifest is! Map) return null;
    final manifest = Map<String, Object?>.from(rohManifest);
    final id = json['paketId'] as String? ?? (manifest['id'] as String?) ?? '';
    return HeroRegelProfilPaket(
      paketId: id,
      pruefsumme: json['pruefsumme'] as String? ?? '',
      manifest: manifest,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

/// Explizites Regelprofil eines Helden: die Hausregel-Pakete, nach denen er
/// rechnet (ARCH-04).
///
/// Fehlt das Profil (`HeroSheet.regelProfil == null`), folgt der Held dem
/// globalen Stand der Einstellungen. Ein Profil nennt die **aktiven** Pakete;
/// jedes andere – auch ein neu ausgeliefertes – ist für diesen Helden aus, bis
/// er ein Update übernimmt. Der Basiskatalog selbst wird nicht eingefroren.
class HeroRegelProfil {
  /// Profil für [catalogVersion] mit den aktiven [pakete].
  HeroRegelProfil({
    required this.catalogVersion,
    required List<HeroRegelProfilPaket> pakete,
    this.formatVersion = aktuelleFormatVersion,
    this.unbekannteFelder = const <String, Object?>{},
  }) : pakete = List<HeroRegelProfilPaket>.unmodifiable(pakete);

  /// Format, das diese App-Version versteht.
  static const int aktuelleFormatVersion = 1;

  /// Formatversion; größere Werte stammen von einer neueren App.
  final int formatVersion;

  /// Katalogversion der Paketkopien, etwa `house_rules_v1`.
  final String catalogVersion;

  /// Aktive Pakete mit ihren Kopien. Die Liste ist atomar (siehe
  /// [HeroRegelProfilPaket.paketId]).
  final List<HeroRegelProfilPaket> pakete;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Ob diese App-Version das Profil auswerten darf.
  bool get istVerstanden => formatVersion <= aktuelleFormatVersion;

  /// IDs der aktiven Pakete.
  Set<String> get paketIds => <String>{for (final p in pakete) p.paketId};

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'formatVersion',
    'catalogVersion',
    'pakete',
  };

  HeroRegelProfil copyWith({
    int? formatVersion,
    String? catalogVersion,
    List<HeroRegelProfilPaket>? pakete,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroRegelProfil(
      formatVersion: formatVersion ?? this.formatVersion,
      catalogVersion: catalogVersion ?? this.catalogVersion,
      pakete: pakete ?? this.pakete,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'formatVersion': formatVersion,
      'catalogVersion': catalogVersion,
      'pakete': pakete.map((p) => p.toJson()).toList(growable: false),
    }, unbekannteFelder);
  }

  /// Liest ein Profil tolerant; nicht verstandene Paketeinträge entfallen.
  static HeroRegelProfil fromJson(Map<String, dynamic> json) {
    final rohPakete = json['pakete'] as List? ?? const [];
    final pakete = <HeroRegelProfilPaket>[];
    for (final roh in rohPakete) {
      if (roh is! Map) continue;
      final paket = HeroRegelProfilPaket.fromJson(
        Map<String, dynamic>.from(roh),
      );
      if (paket != null) pakete.add(paket);
    }
    return HeroRegelProfil(
      formatVersion:
          (json['formatVersion'] as num?)?.toInt() ?? aktuelleFormatVersion,
      catalogVersion: json['catalogVersion'] as String? ?? '',
      pakete: pakete,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  /// Gleich, wenn Format, Katalogversion und die Paketstempel gleich sind;
  /// dient als Schlüssel für gemeinsam genutzte Kataloge.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HeroRegelProfil) return false;
    if (formatVersion != other.formatVersion ||
        catalogVersion != other.catalogVersion ||
        pakete.length != other.pakete.length) {
      return false;
    }
    for (var i = 0; i < pakete.length; i++) {
      if (pakete[i].paketId != other.pakete[i].paketId ||
          pakete[i].pruefsumme != other.pakete[i].pruefsumme) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    formatVersion,
    catalogVersion,
    Object.hashAll(pakete.map((p) => Object.hash(p.paketId, p.pruefsumme))),
  );
}
