import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_access_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_gunzip.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_proof.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';

/// Erste 15 ASCII-Zeichen der SQLite-Dateisignatur (16. Byte ist ein
/// Null-Terminator, siehe
/// https://www.sqlite.org/fileformat.html#the_database_header).
const _sqliteHeaderMagicPrefix = 'SQLite format 3';

/// Orchestriert den Remote-Bezug der Regel-Index-DB: Download vom
/// konfigurierten Server, ein defensiver Formatcheck und Übergabe an den
/// plattformspezifischen Importpfad (`importRulesIndexDatabase`), der auf
/// Web bereits fürs manuelle Hochladen existiert und auf Desktop denselben
/// Weg nun auch für den Server-Download nutzt.
class RulesIndexSyncService {
  RulesIndexSyncService({
    RulesIndexRemoteClient? remoteClient,
    this.accessGateway,
    this.dataDirectory,
  }) : _remoteClient = remoteClient ?? RulesIndexRemoteClient();

  final RulesIndexRemoteClient _remoteClient;

  /// Zugang zur Cloud Function; `null`, wenn der Build keinen Server hat.
  final RulesIndexAccessGateway? accessGateway;

  /// Optionales isoliertes Datenverzeichnis, insbesondere für Tests.
  final String? dataDirectory;

  /// Lädt die Index-Datenbank vom Server und importiert sie.
  ///
  /// Wirft [RulesIndexDownloadException] bei Netzwerk-/Serverfehlern und
  /// [FormatException], wenn die Antwort keine gültige Regel-Index-Datenbank
  /// enthält (z. B. eine HTML-Fehlerseite statt der erwarteten Datei).
  Future<RulesIndexSearch> syncFromServer(RulesIndexRemoteConfig config) async {
    final bytes = await _remoteClient.download(
      serverUrl: config.effectiveServerUrl,
      username: config.effectiveUsername,
      password: config.effectivePassword,
    );
    _checkSqliteHeader(bytes);
    return importRulesIndexDatabase(bytes, dataDirectory: dataDirectory);
  }

  /// Holt die Wissensbasis ueber die Cloud Function und installiert sie.
  ///
  /// Ablauf: Zugang mit dem Passwortnachweis ([proof]) erfragen, die gepackte
  /// Datei von der signierten URL laden, bei Bedarf entpacken, gegen die
  /// SHA-256 der Veroeffentlichung pruefen und erst dann importieren — eine
  /// beschaedigte oder falsche Datei ersetzt nie eine funktionierende.
  ///
  /// Ist [installedVersion] bereits die aktuelle Fassung und
  /// [skipIfCurrent] gesetzt, entfaellt der Download und das Ergebnis hat
  /// `search == null`. [onProgress] meldet `received` von `total` Bytes.
  ///
  /// Wirft [RulesIndexDownloadException] bei Zugangs- und Netzfehlern und
  /// [FormatException], wenn die Datei nicht zur Veroeffentlichung passt.
  Future<RulesIndexInstall> syncFromCloud({
    required String proof,
    String? installedVersion,
    bool skipIfCurrent = false,
    void Function(int received, int total)? onProgress,
  }) async {
    final gateway = accessGateway;
    if (gateway == null) {
      throw const RulesIndexDownloadException(
        RulesIndexDownloadErrorKind.other,
        'Für diesen Build ist kein Server für die Wissensbasis eingerichtet.',
      );
    }
    final release = await gateway.requestAccess(proof: proof);
    if (skipIfCurrent && release.version == installedVersion) {
      return RulesIndexInstall(version: release.version, search: null);
    }
    final loaded = await _remoteClient.downloadSigned(
      release.url,
      onProgress: (received) => onProgress?.call(received, release.sizeBytes),
    );
    final bytes = gunzipIfNeeded(loaded);
    if (bytes.length != release.sizeBytes ||
        sha256Hex(bytes) != release.sha256) {
      throw const FormatException(
        'Die geladene Datei passt nicht zur veröffentlichten Fassung.',
      );
    }
    _checkSqliteHeader(bytes);
    return RulesIndexInstall(
      version: release.version,
      search: await importRulesIndexDatabase(
        bytes,
        dataDirectory: dataDirectory,
      ),
    );
  }

  void _checkSqliteHeader(Uint8List bytes) {
    final prefixLength = _sqliteHeaderMagicPrefix.length;
    if (bytes.length <= prefixLength ||
        String.fromCharCodes(bytes.sublist(0, prefixLength)) !=
            _sqliteHeaderMagicPrefix) {
      throw const FormatException(
        'Antwort ist keine gültige SQLite-Datenbank.',
      );
    }
  }
}

/// Ergebnis von [RulesIndexSyncService.syncFromCloud].
class RulesIndexInstall {
  /// Erstellt das Ergebnis.
  const RulesIndexInstall({required this.version, required this.search});

  /// Version der Veroeffentlichung, die jetzt gilt.
  final String version;

  /// Die geoeffnete Datenbank; `null`, wenn nichts geladen werden musste.
  final RulesIndexSearch? search;
}
