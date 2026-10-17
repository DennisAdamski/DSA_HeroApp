import 'package:dsa_heldenverwaltung/data/auth_service.dart';

/// Liefert die Konto-UID ausschließlich für verifizierten Remote-Zugriff.
///
/// Unbestätigte Konten bleiben lokal nutzbar, erhalten aber weder Sync- noch
/// Geheimniszugriff. So entspricht das Clientverhalten den Firebase-Regeln.
String? verifiedSyncUid({
  required bool accountSyncAvailable,
  required AuthUser? user,
}) {
  if (!accountSyncAvailable || user?.emailVerified != true) {
    return null;
  }
  return user!.uid;
}
