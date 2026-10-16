import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
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
    Provider.family<List<GefechtsTeilnehmer>, String>(
      (ref, heroId) => gefechtsEigeneSeiteLesen(ref, {
        heroId,
        ...ref.watch(gefechtInitiativeProvider).helden,
      }, beobachten: true),
    );

/// Bildet die eigene Seite für ausdrücklich genannte Helden.
///
/// Der Initiativ-Controller ruft dies mit seinem eigenen Gruppenstand auf
/// ([beobachten] `false`), damit er nicht von sich selbst abhängt.
List<GefechtsTeilnehmer> gefechtsEigeneSeiteLesen(
  Ref ref,
  Set<String> heldenIds, {
  required bool beobachten,
}) {
  T lies<T>(ProviderListenable<T> p) => beobachten ? ref.watch(p) : ref.read(p);
  final helden = <GefechtsHeldEintrag>[
    for (final id in heldenIds)
      (
        id: id,
        name: lies(heroByIdProvider(id))?.name ?? id,
        zielId: lies(gefechtProvider(id))?.kontext.gegnerId,
      ),
  ];
  final gesehen = <String>{};
  final externe = <GefechtsExternEintrag>[];
  for (final id in heldenIds) {
    final held = lies(heroByIdProvider(id));
    for (final m in held?.gruppen ?? const []) {
      final mitglieder = lies(
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
    lies(gefechtBegegnungProvider),
    helden: helden,
    externe: externe,
  );
}
