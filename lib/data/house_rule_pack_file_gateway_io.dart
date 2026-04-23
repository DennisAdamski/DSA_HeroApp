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
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes != null) {
      return utf8.decode(bytes);
    }

    final path = file.path;
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    return File(path).readAsString();
  }

  @override
  Future<HouseRulePackExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    final safeName = _sanitizeFileName(fileNameBase);
    final fileName = '$safeName.dsa-house-rule.json';

    if (_isDesktopPlatform()) {
      final targetPath = await FilePicker.saveFile(
        dialogTitle: 'Hausregelpaket exportieren',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
      if (targetPath == null || targetPath.trim().isEmpty) {
        return const HouseRulePackExportOutcome(
          result: HouseRulePackExportResult.canceled,
        );
      }
      await File(targetPath).writeAsString(jsonPayload);
      return HouseRulePackExportOutcome(
        result: HouseRulePackExportResult.savedToFile,
        location: targetPath,
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
