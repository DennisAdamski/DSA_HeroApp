import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_file_gateway.dart';

class IoHeroTransferFileGateway implements HeroTransferFileGateway {
  const IoHeroTransferFileGateway();

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
  Future<HeroTransferExportOutcome> exportJson({
    required String fileNameBase,
    required String jsonPayload,
  }) async {
    final safeName = _sanitizeFileName(fileNameBase);
    final fileName = '$safeName.dsa-hero.json';

    if (_isDesktopPlatform()) {
      final targetPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Held exportieren',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
      if (targetPath == null || targetPath.trim().isEmpty) {
        return const HeroTransferExportOutcome(
          result: HeroTransferExportResult.canceled,
        );
      }
      await File(targetPath).writeAsString(jsonPayload);
      return HeroTransferExportOutcome(
        result: HeroTransferExportResult.savedToFile,
        location: targetPath,
      );
    }

    final tempDir = await getTemporaryDirectory();
    final target = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await target.writeAsString(jsonPayload);
    await Share.shareXFiles(
      <XFile>[XFile(target.path)],
      subject: 'Held exportieren',
      text: 'Exportdatei fuer Heldendaten',
    );
    return HeroTransferExportOutcome(
      result: HeroTransferExportResult.shared,
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
    final trimmed = value.trim().isEmpty ? 'held' : value.trim();
    final normalized = trimmed.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    return normalized;
  }
}

HeroTransferFileGateway createHeroTransferFileGatewayImpl() {
  return const IoHeroTransferFileGateway();
}
