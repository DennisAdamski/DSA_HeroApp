/// Serverseitig nachweisbare Zustände einer Feedbackmeldung.
enum FeedbackResultStatus { created, processing, uncertain, failed }

/// Ergebnis einer Erstellung oder Statusabfrage.
class FeedbackResult {
  /// Erstellt ein typisiertes Feedbackergebnis.
  const FeedbackResult({
    required this.requestId,
    required this.status,
    this.issueNumber,
    this.issueUrl,
    this.code,
  });

  final String requestId;
  final FeedbackResultStatus status;
  final int? issueNumber;
  final Uri? issueUrl;
  final String? code;

  /// Dekodiert ausschließlich bekannte Ergebniszustände und Feldtypen.
  factory FeedbackResult.fromJson(Map<String, dynamic> json) {
    final requestId = json['requestId'];
    final rawStatus = json['status'];
    if (requestId is! String || rawStatus is! String) {
      throw const FormatException('Feedbackantwort ist unvollständig.');
    }
    final status = FeedbackResultStatus.values
        .where((value) => value.name == rawStatus)
        .firstOrNull;
    if (status == null) {
      throw FormatException('Unbekannter Feedbackstatus: $rawStatus');
    }
    final rawUrl = json['issueUrl'];
    return FeedbackResult(
      requestId: requestId,
      status: status,
      issueNumber: json['issueNumber'] as int?,
      issueUrl: rawUrl is String ? Uri.tryParse(rawUrl) : null,
      code: json['code'] as String?,
    );
  }
}
