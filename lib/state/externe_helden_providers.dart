import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/data/gruppen_sync_service.dart';
import 'package:dsa_heldenverwaltung/data/hive_externe_helden_repository.dart';
import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/firebase_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Firebase-Sync-Service fuer Heldengruppen.
final gruppenSyncServiceProvider = Provider<GruppenSyncService>((ref) {
  return GruppenSyncService();
});

/// Repository fuer externe Helden (wird beim App-Start uebersteuert).
final externeHeldenRepositoryProvider = Provider<HiveExterneHeldenRepository>((
  ref,
) {
  throw UnimplementedError(
    'ExterneHeldenRepository muss beim App-Start übersteuert werden.',
  );
});

/// Reaktiver Stream aller externen Helden.
final externeHeldenProvider = StreamProvider<Map<String, ExternerHeld>>((ref) {
  final repo = ref.watch(externeHeldenRepositoryProvider);
  return repo.watchAll();
});

/// Externer Held per ID.
final externerHeldByIdProvider = Provider.family<ExternerHeld?, String>((
  ref,
  id,
) {
  final all =
      ref.watch(externeHeldenProvider).valueOrNull ??
      const <String, ExternerHeld>{};
  return all[id];
});

/// Alle externen Helden einer bestimmten Gruppe eines Helden.
final gruppenMitgliederProvider =
    Provider.family<List<ExternerHeld>, ({String heroId, String gruppenCode})>((
      ref,
      params,
    ) {
      final hero = ref.watch(heroByIdProvider(params.heroId));
      if (hero == null) return const <ExternerHeld>[];

      final mitgliedschaft = hero.gruppen
          .where((g) => g.gruppenCode == params.gruppenCode)
          .firstOrNull;
      if (mitgliedschaft == null) return const <ExternerHeld>[];

      final allExterne =
          ref.watch(externeHeldenProvider).valueOrNull ??
          const <String, ExternerHeld>{};
      return mitgliedschaft.externeHeldIds
          .map((id) => allExterne[id])
          .whereType<ExternerHeld>()
          .toList(growable: false);
    });

/// Gruppeninfo samt Besitzerstatus des angemeldeten Kontos.
typedef GruppenAnsicht = ({GruppenInfo info, bool istBesitzer});

/// Laedt Name, Besitzer und Beitrittsgeheimnis einer Konto-Gruppe.
///
/// `null`, wenn Firestore nicht verfuegbar ist. Fehler (etwa verlorener
/// Zugriff) erscheinen als `AsyncError`.
final gruppenAnsichtProvider = FutureProvider.autoDispose
    .family<GruppenAnsicht?, String>((ref, groupId) async {
      final firebase = ref.watch(firebaseBootstrapProvider);
      if (!firebase.isFirestoreAvailable) {
        return null;
      }
      final service = ref.watch(gruppenSyncServiceProvider);
      final info = await service.ladeGruppe(groupId);
      return (info: info, istBesitzer: info.ownerUid == service.eigeneUid);
    });

/// Gemeinsame Gruppennotizen einer Konto-Gruppe (`shared_info/notizen`).
final gruppenNotizenProvider = FutureProvider.autoDispose
    .family<String, String>((ref, groupId) {
      return ref.watch(gruppenSyncServiceProvider).ladeNotizen(groupId);
    });
