import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/feedback/feedback_client.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_diagnostics_collector.dart';
import 'package:dsa_heldenverwaltung/data/feedback/feedback_pending_store.dart';
import 'package:dsa_heldenverwaltung/state/feedback/feedback_controller.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';

/// Build-konfigurierte URL genau eines Feedbackendpunkts.
final feedbackEndpointProvider = Provider<Uri?>((ref) {
  const raw = String.fromEnvironment('FEEDBACK_API_URL');
  final uri = Uri.tryParse(raw);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty ? uri : null;
});

/// Lädt die nicht personenbezogenen Paket- und Betriebssystemangaben einmalig.
final feedbackDiagnosticsCollectorProvider =
    FutureProvider<FeedbackDiagnosticsCollector>((ref) async {
      final runtime = await FeedbackRuntimeInfo.load();
      return FeedbackDiagnosticsCollector(runtime: runtime);
    });

/// Kontogebundene, textfreie Wiederherstellungsablage.
final feedbackPendingStoreProvider = Provider<FeedbackPendingStore>((ref) {
  return const FeedbackPendingStore(SecureFeedbackPendingStorage());
});

/// Authentifizierter Transport oder `null`, wenn Firebase/URL fehlen.
final feedbackGatewayProvider = Provider<FeedbackGateway?>((ref) {
  final firebase = ref.watch(firebaseBootstrapProvider);
  final endpoint = ref.watch(feedbackEndpointProvider);
  if (!firebase.isAvailable || endpoint == null) return null;
  return FeedbackClient(
    endpoint: endpoint,
    idTokenProvider: () async {
      final user = FirebaseAuth.instance.currentUser;
      return user?.getIdToken();
    },
  );
});

/// Gemeinsamer Controller für Formular und Statuswiederherstellung.
final feedbackControllerProvider = Provider<FeedbackController?>((ref) {
  final gateway = ref.watch(feedbackGatewayProvider);
  if (gateway == null) return null;
  return FeedbackController(
    gateway: gateway,
    pendingStore: ref.watch(feedbackPendingStoreProvider),
  );
});
