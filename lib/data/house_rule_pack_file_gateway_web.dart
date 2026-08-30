import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'package:dsa_heldenverwaltung/data/house_rule_pack_file_gateway.dart';
import 'package:dsa_heldenverwaltung/data/web_download.dart';

/// Dateigateway fuer Web-Import und -Export von Hausregel-Paketen.
class WebHouseRulePackFileGateway implements HouseRulePackFileGateway {
  /// Erstellt den Web-Dateigateway fuer Hausregel-Pakete.
  const WebHouseRulePackFileGateway();

  @override
  Future<String?> pickImportJson() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (file == null) {
      return null;
    }
    return utf8.decode(await file.readAsBytes());
  }

  @override
  Future<HouseRulePackExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    final safeName = sanitizeDownloadFileName(
      fileNameBase,
      fallback: 'hausregelpaket',
    );
    final fileName = '$safeName.dsa-house-rule.json';
    triggerJsonDownload(fileName: fileName, jsonPayload: jsonPayload);

    return HouseRulePackExportOutcome(
      result: HouseRulePackExportResult.downloaded,
      location: fileName,
    );
  }
}

/// Erstellt den Web-Dateigateway fuer Hausregel-Pakete.
HouseRulePackFileGateway createHouseRulePackFileGatewayImpl() {
  return const WebHouseRulePackFileGateway();
}
