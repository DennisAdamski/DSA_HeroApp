import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/feedback/feedback_pending_store.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';

void main() {
  test(
    'offene Referenzen sind kontogebunden und enthalten keinen Feedbacktext',
    () async {
      final storage = MemoryFeedbackPendingStorage();
      final store = FeedbackPendingStore(storage);
      const pending = FeedbackPendingReference(
        requestId: '123e4567-e89b-42d3-a456-426614174001',
        status: FeedbackResultStatus.uncertain,
      );

      await store.save('account-a', pending);

      expect(await store.load('account-a'), pending);
      expect(await store.load('account-b'), isNull);
      expect(storage.values.values.single, isNot(contains('Gegnervorlagen')));
      await store.clear('account-a');
      expect(await store.load('account-a'), isNull);
    },
  );
}

class MemoryFeedbackPendingStorage implements FeedbackPendingStorage {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
