import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ueberzahl_rules.dart';

import 'externe_helden_providers.dart';
import 'gefecht_begegnung_provider.dart';
import 'gefecht_initiative_provider.dart';
import 'gefecht_provider.dart';
import 'hero_providers.dart';

/// Eigene Seite aus Sicht von [heroId]: der Held, die verbundenen Helden der
/// gemeinsamen Initiative und automatisch die externen Gefährten ihrer
/// Heldengruppen (Konzept Gefechtslage, Schritt 5).
///
/// Externe Gefährten, die selbst als Held der App mitkämpfen
/// (`quelleHeroId`), erscheinen nur einmal. Beteiligung und Ziele externer
/// Gefährten liegen in der Begegnung; die Ziele der Helden in ihren Sitzungen.
final gefechtsEigeneSeiteProvider =
    Provider.family<List<GefechtsTeilnehmer>, String>((ref, heroId) {
      final gruppe = ref.watch(gefechtInitiativeProvider);
      final heldenIds = {heroId, ...gruppe.helden};
      final helden = <GefechtsHeldEintrag>[
        for (final id in heldenIds)
          (
            id: id,
            name: ref.watch(heroByIdProvider(id))?.name ?? id,
            zielId: ref.watch(gefechtProvider(id))?.kontext.gegnerId,
          ),
      ];
      final gesehen = <String>{};
      final externe = <GefechtsExternEintrag>[];
      for (final id in heldenIds) {
        final held = ref.watch(heroByIdProvider(id));
        for (final m in held?.gruppen ?? const []) {
          final mitglieder = ref.watch(
            gruppenMitgliederProvider((heroId: id, gruppenCode: m.gruppenCode)),
          );
          for (final e in mitglieder) {
            if (heldenIds.contains(e.quelleHeroId) || !gesehen.add(e.id)) {
              continue;
            }
            externe.add((id: e.id, name: e.name, ini: e.iniBase));
          }
        }
      }
      return gefechtsEigeneSeite(
        ref.watch(gefechtBegegnungProvider),
        helden: helden,
        externe: externe,
      );
    });
