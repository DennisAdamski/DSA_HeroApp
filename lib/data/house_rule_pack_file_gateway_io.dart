import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dsa_heldenverwaltung/data/house_rule_pack_file_gateway.dart';

/// Dateigateway fuer Desktop- und Mobile-Plattformen.
class IoHouseRulePackFileGateway implements HouseRulePackFileGateway {
  /// Erstellt den nativen Dateigateway fuer Hausregel-Pakete.
  const IoHouseRulePackFileGateway();

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
    final safeName = _sanitizeFileName(fileNameBase);
    final fileName = '$safeName.dsa-house-rule.json';

    if (_isDesktopPlatform()) {
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Hausregelpaket exportieren',
        fileName: fileName,
        bytes: utf8.encode(jsonPayload),
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
      if (savedUri == null) {
        return const HouseRulePackExportOutcome(
          result: HouseRulePackExportResult.canceled,
        );
      }
      return HouseRulePackExportOutcome(
        result: HouseRulePackExportResult.savedToFile,
        location: _describeSaveLocation(savedUri),
      );
    }

    final tempDir = await getTemporaryDirectory();
    final target = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await target.writeAsString(jsonPayload);
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(target.path)],
        subject: 'Hausregelpaket exportieren',
        text: 'Exportdatei für ein Hausregelpaket',
      ),
    );
    return HouseRulePackExportOutcome(
      result: HouseRulePackExportResult.shared,
      location: target.path,
    );
  }

  /// Wandelt den von `FilePicker.saveFile` gelieferten Uri in einen
  /// anzeigbaren Pfad.
  ///
  /// Dieser Zweig laeuft nur auf Desktop, wo das Schema immer `file:` ist.
  /// Die uebrigen von file_picker dokumentierten Schemata (`content`, `blob`,
  /// ...) werden defensiv als Uri-Text durchgereicht, statt den bereits
  /// erfolgreichen Export an der Pfadumwandlung scheitern zu lassen.
  String _describeSaveLocation(Uri uri) {
    return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  }

  bool _isDesktopPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  String _sanitizeFileName(String value) {
    final trimmed = value.trim().isEmpty ? 'hausregelpaket' : value.trim();
    return trimmed.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }
}

/// Erstellt den nativen Dateigateway fuer Hausregel-Pakete.
HouseRulePackFileGateway createHouseRulePackFileGatewayImpl() {
  return const IoHouseRulePackFileGateway();
}
