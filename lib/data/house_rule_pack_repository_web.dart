import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';

/// Web-Stub fuer [HouseRulePackRepository].
///
/// Im Web v1 sind importierte Hausregel-Pakete nicht verfuegbar (kein
/// lokales Dateisystem). Eingebaute Pakete bleiben ueber das Asset-Bundle
/// erreichbar; nur die Userimport-Funktion ist deaktiviert.
class HouseRulePackRepository {
  const HouseRulePackRepository({required this.heroStoragePath});

  static const String houseRulePackRootDirectory = 'house_rule_packs';

  final String heroStoragePath;

  Future<HouseRulePackSourceSnapshot> load({
    required String catalogVersion,
  }) async {
    return const HouseRulePackSourceSnapshot();
  }

  Future<HouseRulePackManifest?> loadSinglePack({
    required String catalogVersion,
    required String packId,
  }) async {
    return null;
  }

  Future<void> saveManifest({
    required String catalogVersion,
    required Map<String, dynamic> manifestJson,
    String previousPackId = '',
  }) async {
    throw UnsupportedError(
      'Hausregel-Pakete koennen im Web v1 nicht gespeichert werden.',
    );
  }

  Future<void> deletePack({
    required String catalogVersion,
    required String packId,
  }) async {
    // No-Op: Es gibt keine importierten Pakete im Web.
  }
}
