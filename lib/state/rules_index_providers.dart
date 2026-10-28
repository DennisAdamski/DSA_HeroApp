import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_access_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_proof.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_remote_client.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_search.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/rules_search/rules_index_types.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/auth_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Build-konfigurierte URL der Cloud Function `rulesIndexApi`
/// (`--dart-define=RULES_INDEX_API_URL=...`), oder `null`.
final rulesIndexApiEndpointProvider = Provider<Uri?>((ref) {
  const raw = String.fromEnvironment('RULES_INDEX_API_URL');
  final uri = Uri.tryParse(raw);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty ? uri : null;
});

/// Ob dieser Build die Wissensbasis über die Cloud beziehen kann: Server-URL
/// gesetzt und Firebase verfügbar. Ohne beides bleibt nur der manuelle Weg.
final rulesIndexCloudAvailableProvider = Provider<bool>((ref) {
  final firebase = ref.watch(firebaseBootstrapProvider);
  return firebase.isAvailable &&
      ref.watch(rulesIndexApiEndpointProvider) != null;
});

/// Zugang zur Cloud Function oder `null`, wenn der Build keinen hat.
final rulesIndexAccessGatewayProvider = Provider<RulesIndexAccessGateway?>((
  ref,
) {
  final endpoint = ref.watch(rulesIndexApiEndpointProvider);
  if (endpoint == null || !ref.watch(rulesIndexCloudAvailableProvider)) {
    return null;
  }
  return RulesIndexAccessClient(
    endpoint: endpoint,
    idTokenProvider: () async =>
        FirebaseAuth.instance.currentUser?.getIdToken(),
    appCheckTokenProvider: () => FirebaseAppCheck.instance.getToken(),
  );
});

/// Sync-Dienst mit dem Cloud-Zugang des Builds.
final rulesIndexSyncServiceProvider = Provider<RulesIndexSyncService>((ref) {
  return RulesIndexSyncService(
    accessGateway: ref.watch(rulesIndexAccessGatewayProvider),
  );
});

/// Ob jemand angemeldet ist; die Cloud-Funktion verlangt ein Konto.
final rulesIndexSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authUserProvider).valueOrNull != null,
);

/// Globaler Salt des Katalogs (`catalog_salt_v3`) für den Passwortnachweis;
/// `null`, solange der Katalog nicht geladen ist.
final rulesIndexCatalogSaltProvider = Provider<Uint8List?>(
  (ref) => ref.watch(baseCatalogSourceDataProvider).valueOrNull?.catalogSaltV3,
);

/// Rechnet den Passwortnachweis.
///
/// PBKDF2 mit 100000 Runden dauert einige Sekunden: abseits des UI-Threads,
/// wo es Isolates gibt (im Web läuft `compute` im Hauptthread). In Tests
/// ersetzbar, damit sie nicht jedes Mal rechnen.
final rulesIndexProofBuilderProvider =
    Provider<Future<String> Function(String password, Uint8List salt)>(
      (ref) =>
          (password, salt) =>
              compute(_berechneNachweis, <Object>[password, salt]),
    );

/// Öffnet die lokale Wissensbasis; in Tests ersetzbar.
final rulesIndexOpenerProvider = Provider<Future<RulesIndexSearch?> Function()>(
  (ref) => openRulesIndexSearch,
);

/// Wie alt die letzte Aktualisierung höchstens sein darf, bevor die App im
/// Hintergrund nach einer neueren Fassung fragt.
const Duration rulesIndexRefreshInterval = Duration(days: 14);

/// Phasen des Hintergrundladens der Wissensbasis.
enum RulesIndexSyncPhase {
  /// Nichts zu tun oder noch nicht gestartet.
  idle,

  /// Passwortnachweis wird berechnet und der Zugang erfragt.
  preparing,

  /// Die Datei wird geladen.
  downloading,

  /// Die Datei wird geprüft und eingerichtet.
  installing,

  /// Die Wissensbasis ist aktuell.
  done,

  /// Das Laden ist gescheitert; [RulesIndexSyncState.message] nennt den Grund.
  failed,
}

/// Zustand des Hintergrundladens, fürs Anzeigen im Regel-Dialog.
@immutable
class RulesIndexSyncState {
  /// Erstellt einen Zustand.
  const RulesIndexSyncState({
    this.phase = RulesIndexSyncPhase.idle,
    this.received = 0,
    this.total = 0,
    this.message,
    this.needsLogin = false,
    this.revision = 0,
  });

  /// Aktuelle Phase.
  final RulesIndexSyncPhase phase;

  /// Bisher geladene Bytes (entpackt gezählt).
  final int received;

  /// Gesamtgröße in Bytes, 0 solange unbekannt.
  final int total;

  /// Fehlermeldung bei [RulesIndexSyncPhase.failed].
  final String? message;

  /// Ob der Fehler nur fehlt, weil niemand angemeldet ist.
  final bool needsLogin;

  /// Zählt erfolgreiche Installationen hoch, damit offene Ansichten die
  /// Datenbank neu öffnen.
  final int revision;

  /// Ob gerade geladen wird.
  bool get running =>
      phase == RulesIndexSyncPhase.preparing ||
      phase == RulesIndexSyncPhase.downloading ||
      phase == RulesIndexSyncPhase.installing;

  /// Fortschritt von 0 bis 1 oder `null`, wenn er unbestimmt ist.
  double? get fraction => phase == RulesIndexSyncPhase.downloading && total > 0
      ? (received / total).clamp(0.0, 1.0)
      : null;

  RulesIndexSyncState copyWith({
    RulesIndexSyncPhase? phase,
    int? received,
    int? total,
    String? message,
    bool? needsLogin,
    int? revision,
  }) {
    return RulesIndexSyncState(
      phase: phase ?? this.phase,
      received: received ?? this.received,
      total: total ?? this.total,
      message: message,
      needsLogin: needsLogin ?? false,
      revision: revision ?? this.revision,
    );
  }
}

/// Lädt die Wissensbasis im Hintergrund über die Cloud.
///
/// Läuft nur, wenn das Katalogpasswort bekannt ist (die Funktion wird erst
/// danach angeboten), jemand angemeldet ist und der Build einen Server hat.
class RulesIndexAutoSync extends Notifier<RulesIndexSyncState> {
  bool _autoVersucht = false;

  @override
  RulesIndexSyncState build() => const RulesIndexSyncState();

  /// Startet das Laden von selbst, höchstens einmal je Sitzung.
  ///
  /// Gelaufen wird nur, wenn die Wissensbasis fehlt oder die letzte
  /// Aktualisierung länger als [rulesIndexRefreshInterval] her ist. Fehlt eine
  /// Voraussetzung (noch nicht angemeldet, Katalog nicht geladen), passiert
  /// nichts und der nächste Anlass versucht es erneut.
  Future<void> autoStart() async {
    if (_autoVersucht || state.running) return;
    if (!rulesIndexSearchSupported()) return;
    if (!ref.read(rulesIndexCloudAvailableProvider)) return;
    if (!_entsperrt() || _salt() == null) return;
    if (!ref.read(rulesIndexSignedInProvider)) return;
    final einstellungen = ref.read(appSettingsProvider);
    if (!einstellungen.hasValue) return;

    _autoVersucht = true;
    final config = ref.read(rulesIndexRemoteConfigProvider);
    final vorhanden = await _indexVorhanden();
    final letzte = config.lastSyncedAt;
    final veraltet =
        letzte == null ||
        DateTime.now().difference(letzte) > rulesIndexRefreshInterval;
    if (vorhanden && !veraltet) return;
    await start(force: !vorhanden);
  }

  /// Lädt die Wissensbasis jetzt; [force] lädt auch bei gleicher Version.
  Future<void> start({bool force = false}) async {
    if (state.running) return;
    final password = ref.read(catalogContentPasswordProvider);
    if (password == null || password.isEmpty) return;
    if (!ref.read(rulesIndexSignedInProvider)) {
      state = state.copyWith(
        phase: RulesIndexSyncPhase.failed,
        message: 'Zum Laden der Wissensbasis bitte anmelden.',
        needsLogin: true,
      );
      return;
    }
    final salt = _salt();
    if (salt == null) {
      state = state.copyWith(
        phase: RulesIndexSyncPhase.failed,
        message: 'Der Katalog ist noch nicht geladen.',
      );
      return;
    }

    state = state.copyWith(phase: RulesIndexSyncPhase.preparing);
    try {
      final proof = await ref.read(rulesIndexProofBuilderProvider)(
        password,
        salt,
      );
      final config = ref.read(rulesIndexRemoteConfigProvider);
      final result = await ref
          .read(rulesIndexSyncServiceProvider)
          .syncFromCloud(
            proof: proof,
            installedVersion: config.installedVersion,
            skipIfCurrent: !force,
            onProgress: (received, total) {
              state = state.copyWith(
                phase: RulesIndexSyncPhase.downloading,
                received: received,
                total: total,
              );
            },
          );
      final installiert = result.search != null;
      result.search?.dispose();
      await ref
          .read(settingsActionsProvider)
          .saveRulesIndexRemoteConfig(
            config.copyWith(
              lastSyncedAt: DateTime.now(),
              installedVersion: result.version,
            ),
          );
      state = RulesIndexSyncState(
        phase: RulesIndexSyncPhase.done,
        revision: state.revision + (installiert ? 1 : 0),
      );
    } on RulesIndexDownloadException catch (error) {
      state = state.copyWith(
        phase: RulesIndexSyncPhase.failed,
        message: error.message,
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        phase: RulesIndexSyncPhase.failed,
        message: error.message,
      );
    }
  }

  Future<bool> _indexVorhanden() async {
    final search = await ref.read(rulesIndexOpenerProvider)();
    search?.dispose();
    return search != null;
  }

  bool _entsperrt() => ref.read(catalogContentVisibleProvider);

  Uint8List? _salt() => ref.read(rulesIndexCatalogSaltProvider);
}

/// Zustand und Steuerung des Hintergrundladens.
final rulesIndexAutoSyncProvider =
    NotifierProvider<RulesIndexAutoSync, RulesIndexSyncState>(
      RulesIndexAutoSync.new,
    );

/// Stößt das Hintergrundladen an, sobald alle Voraussetzungen erfüllt sind.
///
/// Wird einmal an einer dauerhaft gebauten Stelle beobachtet; der Wert ist
/// immer `null`, ein Neubau der Beobachter entsteht dadurch nie.
final rulesIndexAutoStartProvider = Provider<void>((ref) {
  void pruefe() {
    unawaited(ref.read(rulesIndexAutoSyncProvider.notifier).autoStart());
  }

  ref
    ..listen(catalogContentVisibleProvider, (_, _) => pruefe())
    ..listen(rulesIndexSignedInProvider, (_, _) => pruefe())
    ..listen(rulesIndexCatalogSaltProvider, (_, _) => pruefe())
    ..listen(appSettingsProvider, (_, _) => pruefe());
  pruefe();
});

/// Rechnet den Passwortnachweis; Einstieg für [compute].
String _berechneNachweis(List<Object> argumente) => rulesIndexProof(
  password: argumente[0] as String,
  salt: argumente[1] as Uint8List,
);
