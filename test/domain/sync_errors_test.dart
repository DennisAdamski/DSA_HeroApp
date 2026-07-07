import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';

void main() {
  group('SyncFailure.fromError', () {
    test('maps auth exceptions', () {
      final failure = SyncFailure.fromError(
        const SyncAuthException('Token abgelaufen'),
      );

      expect(failure.kind, SyncErrorKind.auth);
      expect(failure.message, 'Token abgelaufen');
    });

    test('maps network exceptions', () {
      final failure = SyncFailure.fromError(
        const SyncNetworkException('Offline'),
      );

      expect(failure.kind, SyncErrorKind.network);
      expect(failure.message, 'Offline');
    });

    test('maps precondition exceptions to conflict', () {
      final failure = SyncFailure.fromError(
        const SyncPreconditionException(
          'Revision passt nicht',
          expectedRevision: 'r-1',
          actualRevision: 'r-2',
        ),
      );

      expect(failure.kind, SyncErrorKind.conflict);
      expect(failure.message, 'Revision passt nicht');
    });

    test('maps decode exceptions', () {
      final failure = SyncFailure.fromError(
        const SyncDecodeException('Kaputtes Dokument'),
      );

      expect(failure.kind, SyncErrorKind.decode);
    });

    test('maps arbitrary errors to unknown with toString message', () {
      final failure = SyncFailure.fromError(StateError('boom'));

      expect(failure.kind, SyncErrorKind.unknown);
      expect(failure.message, contains('boom'));
    });

    test('keeps the occurredAt timestamp', () {
      final at = DateTime.utc(2026, 7, 5);
      final failure = SyncFailure.fromError(
        const SyncNetworkException('Offline'),
        occurredAt: at,
      );

      expect(failure.occurredAt, at);
    });
  });

  test('SyncException toString includes type and message', () {
    expect(
      const SyncAuthException('Kein Token').toString(),
      'SyncAuthException: Kein Token',
    );
  });
}
