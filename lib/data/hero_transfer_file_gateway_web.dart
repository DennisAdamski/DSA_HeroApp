import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';
import 'package:dsa_heldenverwaltung/data/web_download.dart';

class WebHeroTransferFileGateway implements HeroTransferFileGateway {
  const WebHeroTransferFileGateway();

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
  Future<HeroTransferExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    final safeName = sanitizeDownloadFileName(fileNameBase, fallback: 'held');
    final fileName = '$safeName.dsa-hero.json';
    triggerJsonDownload(fileName: fileName, jsonPayload: jsonPayload);

    return HeroTransferExportOutcome(
      result: HeroTransferExportResult.downloaded,
      location: fileName,
    );
  }
}

HeroTransferFileGateway createHeroTransferFileGatewayImpl() {
  return const WebHeroTransferFileGateway();
}
