// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';

import 'package:dsa_heldenverwaltung/data/house_rule_pack_file_gateway.dart';

/// Dateigateway fuer Web-Import und -Export von Hausregel-Paketen.
class WebHouseRulePackFileGateway implements HouseRulePackFileGateway {
  /// Erstellt den Web-Dateigateway fuer Hausregel-Pakete.
  const WebHouseRulePackFileGateway();

  @override
  Future<String?> pickImportJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      return null;
    }
    return utf8.decode(bytes);
  }

  @override
  Future<HouseRulePackExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    final safeName = _sanitizeFileName(fileNameBase);
    final fileName = '$safeName.dsa-house-rule.json';
    final bytes = utf8.encode(jsonPayload);
    final blob = html.Blob(<dynamic>[bytes], 'application/json;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);

    return HouseRulePackExportOutcome(
      result: HouseRulePackExportResult.downloaded,
      location: fileName,
    );
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim().isEmpty ? 'hausregelpaket' : value.trim();
    return trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }
}

/// Erstellt den Web-Dateigateway fuer Hausregel-Pakete.
HouseRulePackFileGateway createHouseRulePackFileGatewayImpl() {
  return const WebHouseRulePackFileGateway();
}
