import 'package:dsa_heldenverwaltung/data/feedback/feedback_client.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_pending_store.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';

/// Verbindet Transport und textfreie, kontogebundene Wiederherstellung.
class FeedbackController {
  /// Erstellt den Controller über injizierbare, unabhängig testbare Grenzen.
  const FeedbackController({required this.gateway, required this.pendingStore});

  final FeedbackGateway gateway;
  final FeedbackPendingStore pendingStore;

  /// Sendet einmal und merkt nur noch nicht abschließend geklärte Referenzen.
  Future<FeedbackResult> submit(
    String accountId,
    FeedbackSubmission submission,
  ) async {
    final result = await gateway.submit(submission);
    await _persistResult(accountId, result);
    return result;
  }

  /// Prüft eine vorhandene Referenz ohne erneute Issue-Erstellung.
  Future<FeedbackResult> refresh(String accountId, String requestId) async {
    final result = await gateway.status(requestId);
    await _persistResult(accountId, result);
    return result;
  }

  /// Lädt ausschließlich die offene Referenz des aktiven Kontos.
  Future<FeedbackPendingReference?> pending(String accountId) {
    return pendingStore.load(accountId);
  }

  Future<void> _persistResult(String accountId, FeedbackResult result) {
    if (result.status == FeedbackResultStatus.processing ||
        result.status == FeedbackResultStatus.uncertain) {
      return pendingStore.save(
        accountId,
        FeedbackPendingReference(
          requestId: result.requestId,
          status: result.status,
          issueNumber: result.issueNumber,
          issueUrl: result.issueUrl,
        ),
      );
    }
    return pendingStore.clear(accountId);
  }
}
