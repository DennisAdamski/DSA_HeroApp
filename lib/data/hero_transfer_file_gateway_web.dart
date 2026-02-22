// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

import 'package:file_picker/file_picker.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';

class WebHeroTransferFileGateway implements HeroTransferFileGateway {
  const WebHeroTransferFileGateway();

  @override
  Future<String?> pickImportJson() async {
    final result = await FilePicker.platform.pickFiles(
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
  Future<HeroTransferExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    final safeName = _sanitizeFileName(fileNameBase);
    final fileName = '$safeName.dsa-hero.json';
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

    return HeroTransferExportOutcome(
      result: HeroTransferExportResult.downloaded,
      location: fileName,
    );
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim().isEmpty ? 'held' : value.trim();
    return trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }
}

HeroTransferFileGateway createHeroTransferFileGatewayImpl() {
  return const WebHeroTransferFileGateway();
}
