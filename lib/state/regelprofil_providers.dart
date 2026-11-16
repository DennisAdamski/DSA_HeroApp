import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:dsa_heldenverwaltung/catalog/regelprofil_aufloesung.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_regelprofil.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

/// Aufgelöstes Regelprofil (ARCH-04), geteilt von allen Helden mit gleichem
/// Profil.
///
/// Schlüssel ist das Profil selbst; seine Gleichheit sind Format, Katalogversion
/// und die Prüfsummen der Paketkopien. Katalogaufbau und Entschlüsselung laufen
/// deshalb einmal je Profil, nicht einmal je Held. Basisdaten und eigene
/// Katalogeinträge sind dieselben wie beim globalen Stand.
final regelProfilAufloesungProvider =
    FutureProvider.family<RegelProfilAufloesung, HeroRegelProfil>((
      ref,
      profil,
    ) async {
      final basisDaten = await ref.watch(
        decryptedCatalogSourceDataProvider.future,
      );
      final repository = ref.watch(customCatalogRepositoryProvider);
      final eigene = await repository.load(catalogVersion: basisDaten.version);
      // Der Paketkatalog hängt nicht von den Einstellungen ab; ein globales
      // Umschalten löst die Auflösung der Profile also nicht neu aus.
      final paketKatalog = await ref.watch(houseRulePackCatalogProvider.future);
      return loeseRegelProfilAuf(
        basisDaten: basisDaten,
        profil: profil,
        eigeneEintraege: eigene,
        bekanntePaketIds: <String>{for (final p in paketKatalog.packs) p.id},
        loader: ref.watch(catalogLoaderProvider),
      );
    });

/// Quelle des Regelkatalogs zu einem verstandenen Regelprofil (ARCH-04).
///
/// Ohne Profil (`null`) ist das der globale `rulesCatalogProvider`, sonst der
/// aus den Paketkopien aufgelöste Katalog. Gemeinsame Auflösung für
/// [heroRulesCatalogProvider] und für Schreibwege, die das Profil eines noch
/// nicht gespeicherten Helden prüfen.
ProviderListenable<AsyncValue<RulesCatalog>> regelkatalogFuer(
  HeroRegelProfil? profil,
) => profil == null
    ? rulesCatalogProvider
    : regelProfilAufloesungProvider(profil)
          .select((aufloesung) => aufloesung.whenData((r) => r.katalog));

/// Das Profil, nach dem [hero] rechnet; `null`, wenn er keines hat oder
/// diese App-Version es nicht versteht.
HeroRegelProfil? verstandenesRegelProfil(HeroSheet hero) {
  final profil = hero.regelProfil;
  return profil != null && profil.istVerstanden ? profil : null;
}
