import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_decrypt_runner.dart';
import 'package:dsa_heldenverwaltung/catalog/house_rule_pack.dart';

/// Entschlüsselt geschützte Langtexte (`enc:3:`) in den Paketen von [quelle].
///
/// Die eingebauten Hausregel-Pakete tragen Regeltexte (etwa
/// `erklarung_lang`) verschlüsselt (Harte Regel 13, KAT-01). Pakete werden
/// erst nach dem Bulk-Decrypt des Basiskatalogs angewendet, deshalb
/// entschlüsselt dieser Schritt sie vorab. Ohne [schluessel] bleibt alles
/// unverändert; die Oberfläche zeigt dann wie beim Basiskatalog den
/// Sperrhinweis.
HouseRulePackSourceSnapshot entschluesseleHausregelPakete(
  HouseRulePackSourceSnapshot quelle, {
  required CatalogKey? schluessel,
}) {
  if (schluessel == null) return quelle;
  return HouseRulePackSourceSnapshot(
    issues: quelle.issues,
    packs: <HouseRulePackManifest>[
      for (final paket in quelle.packs) _paket(paket, schluessel),
    ],
  );
}

HouseRulePackManifest _paket(
  HouseRulePackManifest paket,
  CatalogKey schluessel,
) {
  final betroffen = paket.patches.any(
    (patch) =>
        enthaeltVerschluesselteWerte(patch.setFields) ||
        enthaeltVerschluesselteWerte(patch.addEntries),
  );
  if (!betroffen) return paket;
  return HouseRulePackManifest(
    id: paket.id,
    title: paket.title,
    description: paket.description,
    parentPackId: paket.parentPackId,
    priority: paket.priority,
    filePath: paket.filePath,
    isBuiltIn: paket.isBuiltIn,
    patches: <HouseRulePatch>[
      for (final patch in paket.patches)
        HouseRulePatch(
          section: patch.section,
          selector: patch.selector,
          priority: patch.priority,
          deactivateEntries: patch.deactivateEntries,
          setFields: entschluesseleKatalogMap(
            patch.setFields,
            v3Key: schluessel,
          ),
          addEntries: <Map<String, dynamic>>[
            for (final eintrag in patch.addEntries)
              entschluesseleKatalogMap(eintrag, v3Key: schluessel),
          ],
        ),
    ],
  );
}
