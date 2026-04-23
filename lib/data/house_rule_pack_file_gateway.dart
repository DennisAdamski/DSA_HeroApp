import 'house_rule_pack_file_gateway_stub.dart'
    if (dart.library.html) 'house_rule_pack_file_gateway_web.dart'
    if (dart.library.io) 'house_rule_pack_file_gateway_io.dart';

/// Ergebnis eines Hausregel-Exports in eine Datei oder einen Share-Flow.
enum HouseRulePackExportResult { canceled, savedToFile, downloaded, shared }

/// Beschreibt das Ergebnis eines Exportvorgangs fuer Hausregel-Pakete.
class HouseRulePackExportOutcome {
  /// Erstellt ein serialisierbares Exportergebnis.
  const HouseRulePackExportOutcome({required this.result, this.location});

  /// Technisches Exportergebnis.
  final HouseRulePackExportResult result;

  /// Optionaler Zielpfad oder Dateiname.
  final String? location;
}

/// Plattformabhaengiger Dateizugriff fuer Import und Export von Hausregel-Paketen.
abstract class HouseRulePackFileGateway {
  /// Oeffnet eine JSON-Datei und liefert deren Inhalt oder `null` bei Abbruch.
  Future<String?> pickImportJson();

  /// Exportiert ein Paket-Manifest als JSON-Datei.
  Future<HouseRulePackExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  });
}

/// Erstellt den zur Plattform passenden Dateigateway fuer Hausregel-Pakete.
HouseRulePackFileGateway createHouseRulePackFileGateway() {
  return createHouseRulePackFileGatewayImpl();
}
