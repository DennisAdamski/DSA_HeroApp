import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';

/// Darstellung einer Katalog-Gruppe in Sprungleiste und Abschnittskopf. Talente
/// und Sonderfertigkeiten teilen sich dieselben Bausteine.
abstract interface class GruppenAnzeige {
  /// Stabiler Name für Widget-Keys.
  String get schluessel;

  /// Kurzname für Leiste und Abschnittskopf.
  String get label;

  /// Symbol, das die Gruppe unabhängig von der Farbe kenntlich macht.
  IconData get icon;

  /// Akzentfarbe, die auf hellem wie dunklem Grund lesbar bleibt.
  Color akzent(Brightness helligkeit);
}

/// Gruppen des Talentkatalogs. Reihenfolge, Farbe und Symbol sind fest, damit
/// jede Gruppe auf den ersten Blick wiedererkannt wird.
enum TalentGruppe implements GruppenAnzeige {
  kampf('Kampf', Icons.shield, Color(0xFFB3261E), Color(0xFFFFB4AB)),
  koerper('Körper', Icons.directions_run, Color(0xFF00796B), Color(0xFF6FD6C6)),
  gesellschaft(
    'Gesellschaft',
    Icons.groups,
    Color(0xFFB02A6B),
    Color(0xFFFFB0D2),
  ),
  natur('Natur', Icons.forest, Color(0xFF4C7A1F), Color(0xFF9ACD6A)),
  wissen('Wissen', Icons.menu_book, Color(0xFF1F5FA8), Color(0xFF9CC4F5)),
  handwerk('Handwerk', Icons.handyman, Color(0xFF9A6100), Color(0xFFF0B84A)),
  gaben('Gaben', Icons.auto_awesome, Color(0xFF5B4BC4), Color(0xFFC0B8FF)),
  sprachen('Sprachen', Icons.translate, Color(0xFF546E7A), Color(0xFFB0BEC5)),
  schriften(
    'Schriften',
    Icons.history_edu,
    Color(0xFF6D4C41),
    Color(0xFFD7B8A8),
  ),
  sonstige('Weitere', Icons.more_horiz, Color(0xFF616161), Color(0xFFBDBDBD));

  const TalentGruppe(this.label, this.icon, this._hell, this._dunkel);

  @override
  String get schluessel => name;
  @override
  final String label;
  @override
  final IconData icon;
  final Color _hell;
  final Color _dunkel;

  @override
  Color akzent(Brightness helligkeit) =>
      helligkeit == Brightness.dark ? _dunkel : _hell;
}

String _normalisiert(String text) => text
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss');

/// Ordnet einen Katalogeintrag seiner Talentgruppe zu.
///
/// Sprachen und Schriften haben eigene Arten; Talente folgen der Gruppe ihrer
/// Katalogdefinition. Kampftalente erkennt auch die Waffenkategorie, falls die
/// Gruppe fehlt.
TalentGruppe talentGruppeFuer(AdvancementOption option, RulesCatalog catalog) {
  switch (option.kind) {
    case AdvancementKind.language:
      return TalentGruppe.sprachen;
    case AdvancementKind.script:
      return TalentGruppe.schriften;
    default:
      break;
  }
  final def = catalog.talents
      .where((def) => def.id == option.targetId)
      .firstOrNull;
  if (def == null) return TalentGruppe.sonstige;
  return talentGruppeFuerDefinition(def);
}

/// Ordnet eine Talentdefinition ihrer Gruppe zu.
TalentGruppe talentGruppeFuerDefinition(TalentDef def) {
  final gruppe = _normalisiert(def.group);
  if (gruppe.contains('kampf') ||
      def.weaponCategory.isNotEmpty ||
      def.type == 'nahkampf' ||
      def.type == 'fernkampf') {
    return TalentGruppe.kampf;
  }
  if (gruppe.contains('koerper')) return TalentGruppe.koerper;
  if (gruppe.contains('gesellschaft')) return TalentGruppe.gesellschaft;
  if (gruppe.contains('natur')) return TalentGruppe.natur;
  if (gruppe.contains('wissen')) return TalentGruppe.wissen;
  if (gruppe.contains('handwerk')) return TalentGruppe.handwerk;
  if (gruppe.contains('gabe')) return TalentGruppe.gaben;
  return TalentGruppe.sonstige;
}

/// Sortiert Einträge in ihre Gruppen und lässt leere Gruppen weg.
Map<TalentGruppe, List<AdvancementOption>> gruppiereTalente(
  Iterable<AdvancementOption> options,
  RulesCatalog catalog,
) {
  final result = <TalentGruppe, List<AdvancementOption>>{
    for (final gruppe in TalentGruppe.values) gruppe: [],
  };
  for (final option in options) {
    result[talentGruppeFuer(option, catalog)]!.add(option);
  }
  result.removeWhere((_, value) => value.isEmpty);
  return result;
}

/// Sprungleiste: bleibt über der Liste stehen und führt mit einem Tippen zur
/// gewünschten Gruppe.
class TalentGruppenLeiste<T extends GruppenAnzeige> extends StatelessWidget {
  /// Zeigt je Gruppe eine eigene Marke mit Symbol, Name und Anzahl.
  const TalentGruppenLeiste({
    super.key,
    required this.gruppen,
    required this.eingeklappt,
    required this.onSpringen,
  });

  /// Gruppen mit der Zahl ihrer Einträge, in Anzeigereihenfolge.
  final Map<T, int> gruppen;

  /// Eingeklappte Gruppen werden gedämpft dargestellt.
  final Set<T> eingeklappt;

  /// Wird mit der gewählten Gruppe aufgerufen.
  final ValueChanged<T> onSpringen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: gruppen.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final gruppe = gruppen.keys.elementAt(index);
          final akzent = gruppe.akzent(theme.brightness);
          final gedaempft = eingeklappt.contains(gruppe);
          return Semantics(
            button: true,
            label: '${gruppe.label}, ${gruppen[gruppe]} Einträge',
            excludeSemantics: true,
            child: Material(
              color: akzent.withValues(alpha: gedaempft ? 0.05 : 0.14),
              shape: StadiumBorder(
                side: BorderSide(
                  color: akzent.withValues(alpha: gedaempft ? 0.35 : 0.9),
                ),
              ),
              child: InkWell(
                key: ValueKey('advancement-group-jump-${gruppe.schluessel}'),
                customBorder: const StadiumBorder(),
                onTap: () => onSpringen(gruppe),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(gruppe.icon, size: 18, color: akzent),
                      const SizedBox(width: 6),
                      Text(
                        gruppe.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${gruppen[gruppe]}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: akzent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Abschnittskopf einer Gruppe: farbiges Band mit Symbol, Name, Zahl und
/// Ein-/Ausklappen.
class TalentGruppenKopf extends StatelessWidget {
  /// Der Kopf trägt die Farbe der Gruppe, damit Abschnitte beim Scrollen
  /// unterscheidbar bleiben.
  const TalentGruppenKopf({
    super.key,
    required this.gruppe,
    required this.anzahl,
    required this.eingeklappt,
    required this.onUmschalten,
    this.untertitel,
  });

  final GruppenAnzeige gruppe;
  final int anzahl;

  /// Optionale Zusatzzeile unter dem Namen, etwa der Erwerbsstand.
  final String? untertitel;
  final bool eingeklappt;
  final VoidCallback onUmschalten;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final akzent = gruppe.akzent(theme.brightness);
    return Semantics(
      button: true,
      expanded: !eingeklappt,
      label: '${gruppe.label}, $anzahl Einträge',
      excludeSemantics: true,
      child: Material(
        color: akzent.withValues(alpha: 0.12),
        shape: Border(
          left: BorderSide(color: akzent, width: 6),
          bottom: BorderSide(color: akzent.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          key: ValueKey('advancement-group-header-${gruppe.schluessel}'),
          onTap: onUmschalten,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: akzent,
                  foregroundColor: theme.brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                  child: Icon(gruppe.icon, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gruppe.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (untertitel != null)
                        Text(
                          untertitel!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '$anzahl',
                  style: theme.textTheme.titleSmall?.copyWith(color: akzent),
                ),
                Icon(
                  eingeklappt ? Icons.expand_more : Icons.expand_less,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
