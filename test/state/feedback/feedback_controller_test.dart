import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/feedback/feedback_client.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_pending_store.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';
import 'package:dsa_heldenverwaltung/state/feedback/feedback_controller.dart';

void main() {
  const submission = FeatureFeedbackSubmission(
    requestId: '123e4567-e89b-42d3-a456-426614174001',
    title: 'Gegnervorlagen speichern',
    surface: FeedbackSurface.combat,
    metadata: FeedbackBaseMetadata(
      appVersion: '1.0.1',
      buildNumber: '1',
      commit: 'abcdef0',
      builtAt: '2026-10-15T19:00:00Z',
      platform: 'windows',
    ),
    problem: 'Wiederkehrende Gegner müssen jedes Mal neu erfasst werden.',
    desiredBehavior: 'Gegner sollen als Vorlage gespeichert werden können.',
  );

  test(
    'speichert nur unklare Referenzen und löscht sie nach bestätigtem Erfolg',
    () async {
      final storage = _MemoryStorage();
      final pending = FeedbackPendingStore(storage);
      final gateway = _SequenceGateway(<FeedbackResult>[
        const FeedbackResult(
          requestId: '123e4567-e89b-42d3-a456-426614174001',
          status: FeedbackResultStatus.uncertain,
        ),
        FeedbackResult(
          requestId: '123e4567-e89b-42d3-a456-426614174001',
          status: FeedbackResultStatus.created,
          issueNumber: 23,
          issueUrl: Uri.parse('https://github.test/issues/23'),
        ),
      ]);
      final controller = FeedbackController(
        gateway: gateway,
        pendingStore: pending,
      );

      await controller.submit('account-a', submission);
      expect(await pending.load('account-a'), isNotNull);

      final created = await controller.refresh(
        'account-a',
        submission.requestId,
      );
      expect(created.status, FeedbackResultStatus.created);
      expect(await pending.load('account-a'), isNull);
      expect(gateway.submitCalls, 1);
      expect(gateway.statusCalls, 1);
    },
  );
}

class _SequenceGateway implements FeedbackGateway {
  _SequenceGateway(this.results);

  final List<FeedbackResult> results;
  int submitCalls = 0;
  int statusCalls = 0;

  @override
  Future<FeedbackResult> submit(FeedbackSubmission submission) async {
    submitCalls += 1;
    return results.removeAt(0);
  }

  @override
  Future<FeedbackResult> status(String requestId) async {
    statusCalls += 1;
    return results.removeAt(0);
  }
}

class _MemoryStorage implements FeedbackPendingStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
