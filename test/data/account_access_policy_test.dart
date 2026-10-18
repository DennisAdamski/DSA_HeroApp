import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/account_access_policy.dart';
import 'package:dsa_heldenverwaltung/data/auth_service.dart';

void main() {
  test(
    'gibt die UID nur für verifizierte Konten mit verfügbarem Sync frei',
    () {
      const unverified = AuthUser(
        uid: 'unverified-user',
        email: 'unverified@example.de',
      );
      const verified = AuthUser(
        uid: 'verified-user',
        email: 'verified@example.de',
        emailVerified: true,
      );

      expect(
        verifiedSyncUid(accountSyncAvailable: true, user: unverified),
        isNull,
      );
      expect(
        verifiedSyncUid(accountSyncAvailable: false, user: verified),
        isNull,
      );
      expect(
        verifiedSyncUid(accountSyncAvailable: true, user: verified),
        'verified-user',
      );
    },
  );
}
