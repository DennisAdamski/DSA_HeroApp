import 'dart:typed_data';

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
  RulesIndexSyncService({RulesIndexRemoteClient? remoteClient})
    : _remoteClient = remoteClient ?? RulesIndexRemoteClient();

  final RulesIndexRemoteClient _remoteClient;

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
    return importRulesIndexDatabase(bytes);
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
