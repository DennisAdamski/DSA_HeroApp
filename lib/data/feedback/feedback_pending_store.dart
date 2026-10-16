import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';

/// Minimale, textfreie Wiederherstellungsreferenz für unklare Sendungen.
class FeedbackPendingReference {
  /// Erstellt eine Referenz, die sicher erneut abgefragt werden kann.
  const FeedbackPendingReference({
    required this.requestId,
    required this.status,
    this.issueNumber,
    this.issueUrl,
  });

  final String requestId;
  final FeedbackResultStatus status;
  final int? issueNumber;
  final Uri? issueUrl;

  @override
  bool operator ==(Object other) =>
      other is FeedbackPendingReference &&
      requestId == other.requestId &&
      status == other.status &&
      issueNumber == other.issueNumber &&
      issueUrl == other.issueUrl;

  @override
  int get hashCode => Object.hash(requestId, status, issueNumber, issueUrl);
}

/// Austauschbare Schlüssel-Wert-Ablage für lokale Feedbackreferenzen.
abstract interface class FeedbackPendingStorage {
  /// Liest einen gespeicherten JSON-Wert.
  Future<String?> read(String key);

  /// Schreibt einen gespeicherten JSON-Wert.
  Future<void> write(String key, String value);

  /// Entfernt einen gespeicherten JSON-Wert.
  Future<void> delete(String key);
}

/// Persistiert offene Referenzen strikt unter dem aktuellen Konto.
class FeedbackPendingStore {
  /// Erstellt den Store über eine testbare Ablagegrenze.
  const FeedbackPendingStore(this.storage);

  final FeedbackPendingStorage storage;

  /// Lädt ausschließlich die Referenz des angegebenen Kontos.
  Future<FeedbackPendingReference?> load(String accountId) async {
    final raw = await storage.read(_key(accountId));
    if (raw == null) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final status = FeedbackResultStatus.values
          .where((value) => value.name == json['status'])
          .firstOrNull;
      final requestId = json['requestId'];
      if (status == null || requestId is! String) return null;
      final rawUrl = json['issueUrl'];
      return FeedbackPendingReference(
        requestId: requestId,
        status: status,
        issueNumber: json['issueNumber'] as int?,
        issueUrl: rawUrl is String ? Uri.tryParse(rawUrl) : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Speichert nur Status und Referenz, niemals die Formulartexte.
  Future<void> save(String accountId, FeedbackPendingReference reference) {
    final value = jsonEncode(<String, dynamic>{
      'requestId': reference.requestId,
      'status': reference.status.name,
      if (reference.issueNumber != null) 'issueNumber': reference.issueNumber,
      if (reference.issueUrl != null) 'issueUrl': reference.issueUrl.toString(),
    });
    return storage.write(_key(accountId), value);
  }

  /// Entfernt die offene Referenz eines einzelnen Kontos.
  Future<void> clear(String accountId) => storage.delete(_key(accountId));

  String _key(String accountId) {
    final encoded = base64Url
        .encode(utf8.encode(accountId))
        .replaceAll('=', '');
    return 'feedback_pending_v1_$encoded';
  }
}

/// Produktive Ablage über den vorhandenen Betriebssystem-Schlüsselspeicher.
class SecureFeedbackPendingStorage implements FeedbackPendingStorage {
  /// Erstellt die Ablage mit optional injizierbarem Pluginzugang.
  const SecureFeedbackPendingStorage({
    this.secureStorage = const FlutterSecureStorage(),
  });

  /// Betriebssystem- bzw. browsergestützte Schlüsselablage.
  final FlutterSecureStorage secureStorage;

  @override
  Future<void> delete(String key) => secureStorage.delete(key: key);

  @override
  Future<String?> read(String key) => secureStorage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      secureStorage.write(key: key, value: value);
}
