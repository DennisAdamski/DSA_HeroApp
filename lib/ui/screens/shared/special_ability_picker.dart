import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/special_ability_chain_card.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/special_ability_details_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/special_ability_variant_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/erwerb_dialog.dart';

/// Oeffnet einen durchsuchbaren Katalog-Browser fuer allgemeine, karmale
/// oder magische Sonderfertigkeiten (analog zum Chip-Raster im Kampf-Tab).
///
/// [ownedNamesLower] enthaelt die bereits eingetragenen Namen des Helden
/// (klein geschrieben, getrimmt) fuer den "bereits vorhanden"-Abgleich.
/// [onAdd] wird nach bestaetigtem Erwerbsdialog aufgerufen und erhaelt den
/// zu speichernden Anzeigenamen — bei mehrfach waehlbaren Sonderfertigkeiten
/// inklusive Auswahlvariante (`Kulturkunde (Novadi)`). Der Aufrufer
/// entscheidet, in welche Liste (`talentSpecialAbilities`/
/// `magicSpecialAbilities`) der Eintrag geschrieben wird. [onRemove] wird
/// beim Abschalten eines bereits vorhandenen Eintrags aufgerufen.
///
/// [eigeneKultur] ist die Kultur des Helden; sie steuert den AP-Vorschlag
/// fuer die kostenlose Kulturkunde der eigenen Kultur.
///
/// [requirementContext] schaltet die Voraussetzungspruefung frei: Ohne ihn
/// verhaelt sich der Picker wie zuvor, mit ihm zeigt er Checklisten, sperrt
/// Eintraege sichtbar und verlangt bei offenen Punkten einen Meisterentscheid.
Future<void> showSpecialAbilityPicker({
  required BuildContext context,
  required String title,
  required List<SpecialAbilityDef> catalog,
  required Set<String> ownedNamesLower,
  required int verfuegbareAp,
  required bool episch,
  required void Function(
    SpecialAbilityDef ability,
    String anzeigeName,
    int apKosten,
  )
  onAdd,
  required void Function(SpecialAbilityDef ability) onRemove,
  String eigeneKultur = '',
  HeroRequirementContext? requirementContext,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _SpecialAbilityPickerScreen(
      title: title,
      catalog: catalog,
      ownedNamesLower: ownedNamesLower,
      verfuegbareAp: verfuegbareAp,
      episch: episch,
      onAdd: onAdd,
      onRemove: onRemove,
      eigeneKultur: eigeneKultur,
      requirementContext: requirementContext,
    ),
  );
}

class _SpecialAbilityPickerScreen extends StatefulWidget {
  const _SpecialAbilityPickerScreen({
    required this.title,
    required this.catalog,
    required this.ownedNamesLower,
    required this.verfuegbareAp,
    required this.episch,
    required this.onAdd,
    required this.onRemove,
    required this.eigeneKultur,
    required this.requirementContext,
  });

  final String title;
  final List<SpecialAbilityDef> catalog;
  final Set<String> ownedNamesLower;
  final int verfuegbareAp;
  final bool episch;
  final void Function(
    SpecialAbilityDef ability,
    String anzeigeName,
    int apKosten,
  )
  onAdd;
  final void Function(SpecialAbilityDef ability) onRemove;
  final String eigeneKultur;
  final HeroRequirementContext? requirementContext;

  @override
  State<_SpecialAbilityPickerScreen> createState() =>
      _SpecialAbilityPickerScreenState();
}

class _SpecialAbilityPickerScreenState
    extends State<_SpecialAbilityPickerScreen> {
  late final Set<String> _ownedNamesLower;
  late int _verfuegbareAp;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownedNamesLower = Set<String>.from(widget.ownedNamesLower);
    _verfuegbareAp = widget.verfuegbareAp;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isOwned(SpecialAbilityDef ability) {
    if (ability.mehrfachwaehlbar) {
      return _ownedCount(ability) > 0;
    }
    return istEintragErworben(ability, _ownedNamesLower);
  }

  /// Anzahl bereits eingetragener Instanzen einer mehrfach waehlbaren SF.
  int _ownedCount(SpecialAbilityDef ability) =>
      countOwnedVariants(_ownedNamesLower, ability.name);

  /// Prueft die Voraussetzungen eines Eintrags gegen den Helden.
  ///
  /// Der Kontext wird bewusst nicht nach jedem Erwerb neu gebaut: Er stammt aus
  /// dem gespeicherten Helden, und der Aufrufer schreibt die Aenderungen erst
  /// beim Schliessen zurueck. Frisch erworbene Stufen fliessen ueber
  /// [_ownedNamesLower] trotzdem sofort ein.
  List<RequirementCheckResult> _pruefe(SpecialAbilityDef ability) {
    final basis = widget.requirementContext;
    if (basis == null || ability.voraussetzungenStruktur.isEmpty) {
      return const <RequirementCheckResult>[];
    }
    return evaluateRequirements(
      ability.voraussetzungenStruktur,
      HeroRequirementContext(
        eigenschaften: basis.eigenschaften,
        sonderfertigkeiten: <String>[
          ...basis.sonderfertigkeiten,
          ..._ownedNamesLower,
        ],
        zauberwerte: basis.zauberwerte,
        talentwerte: basis.talentwerte,
        ritualkenntnisse: basis.ritualkenntnisse,
        traditionen: basis.traditionen,
        merkmalskenntnisse: basis.merkmalskenntnisse,
        vorteile: basis.vorteile,
        nachteile: basis.nachteile,
        rasse: basis.rasse,
        leiteigenschaftOverride: basis.leiteigenschaftOverride,
      ),
    );
  }

  Future<void> _toggle(SpecialAbilityDef ability, bool value) async {
    if (value) {
      await _acquire(ability);
    } else {
      widget.onRemove(ability);
      if (!mounted) {
        return;
      }
      setState(() {
        for (final name in ability.alleNamen) {
          _ownedNamesLower.remove(name.trim().toLowerCase());
        }
      });
    }
  }

  /// Fuehrt Variantenauswahl (falls noetig) und Erwerbsdialog aus und meldet
  /// das Ergebnis an den Aufrufer.
  Future<void> _acquire(SpecialAbilityDef ability) async {
    var variante = '';
    if (ability.mehrfachwaehlbar) {
      final selection = await showAdaptiveInputDialog<String>(
        context: context,
        builder: (_) => SpecialAbilityVariantDialog(
          ability: ability,
          bereitsBelegt: ownedVariantsFor(_ownedNamesLower, ability.name),
        ),
      );
      if (selection == null || selection.trim().isEmpty || !mounted) {
        return;
      }
      variante = selection.trim();
    }

    final anzeigeName = buildVariantAbilityName(ability.name, variante);
    final result = await showErwerbDialog(
      context: context,
      bezeichnung: anzeigeName,
      kostenHinweis: ability.kosten,
      vorgeschlageneApKosten: suggestVariantApCost(
        def: ability,
        bereitsErworben: _ownedCount(ability),
        variante: variante,
        eigeneKultur: widget.eigeneKultur,
      ),
      verfuegbareAp: _verfuegbareAp,
      episch: widget.episch,
      epischerInhalt: ability.nurEpisch,
      voraussetzungen: _pruefe(ability),
    );
    if (result == null) {
      return;
    }
    widget.onAdd(ability, anzeigeName, result.apKosten);
    if (!mounted) {
      return;
    }
    setState(() {
      _ownedNamesLower.add(anzeigeName.trim().toLowerCase());
      _verfuegbareAp -= result.apKosten;
    });
  }

  void _showDetails(SpecialAbilityDef ability) {
    showAdaptiveDetailSheet<void>(
      context: context,
      builder: (_) => SpecialAbilityDetailsDialog(
        ability: ability,
        voraussetzungen: _pruefe(ability),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.catalog
        : widget.catalog
              .where((a) => a.name.toLowerCase().contains(query))
              .toList();
    final grouped = <String, List<SpecialAbilityDef>>{};
    for (final ability in filtered) {
      final key = ability.kategorie.trim().isEmpty
          ? 'Sonstige'
          : ability.kategorie.trim();
      grouped.putIfAbsent(key, () => <SpecialAbilityDef>[]).add(ability);
    }
    final groupKeys = grouped.keys.toList()..sort();
    for (final key in groupKeys) {
      grouped[key]!.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: kDialogWidthLarge,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Suchen…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Verfügbare AP: $_verfuegbareAp',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Keine Treffer.'))
                  : ListView(
                      children: [
                        for (final key in groupKeys)
                          _buildGroup(key, grouped[key]!),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fertig'),
        ),
      ],
    );
  }

  Widget _buildGroup(String title, List<SpecialAbilityDef> abilities) {
    // Ketten werden zu einer Karte zusammengefasst, alles Uebrige bleibt ein
    // Chip. Beides zusammen ergibt wieder den vollstaendigen Katalog.
    final ketten = buildSpecialAbilityChains(abilities);
    final einzeln = kettenloseEintraege(abilities);
    final anzahl = abilities.length;

    return ExpansionTile(
      title: Text('$title ($anzahl)'),
      initiallyExpanded: anzahl <= 8,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final kette in ketten) ...[
                _buildChainCard(kette),
                const SizedBox(height: 8),
              ],
              if (einzeln.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: einzeln.map(_buildChip).toList(growable: false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChainCard(SpecialAbilityChain<SpecialAbilityDef> kette) {
    final erworben = erworbeneKettenstufe(kette, _ownedNamesLower);
    final naechste = naechsteKettenstufe(kette, _ownedNamesLower);
    return SpecialAbilityChainCard<SpecialAbilityDef>(
      kette: kette,
      erworbeneStufe: erworben,
      offeneVoraussetzungenDerNaechstenStufe: naechste == null
          ? const <RequirementCheckResult>[]
          : offeneVoraussetzungen(_pruefe(naechste)),
      onErwerben: _acquire,
      onDetails: _showDetails,
    );
  }

  Widget _buildChip(SpecialAbilityDef ability) {
    final ergebnisse = _pruefe(ability);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
      child: _SpecialAbilityChip(
        name: ability.name,
        beschreibung: ability.beschreibung,
        isOwned: _isOwned(ability),
        isEpic: ability.nurEpisch,
        nurInformation: ability.nurInformation,
        offeneVoraussetzungen: offeneVoraussetzungen(ergebnisse).length,
        variantCount: ability.mehrfachwaehlbar
            ? _ownedCount(ability)
            : null,
        onToggle: (value) => _toggle(ability, value),
        onAddVariant: () => _acquire(ability),
        onNameTap: () => _showDetails(ability),
      ),
    );
  }
}

/// Kompaktes Chip-Widget fuer eine allgemeine/karmale/magische SF im Picker.
/// Name ist tappbar und oeffnet einen Detail-Dialog; der Switch schaltet die
/// Zugehoerigkeit zum Helden an/aus (loest bei Aktivierung den Erwerbsdialog aus).
///
/// Ist [variantCount] gesetzt, handelt es sich um eine mehrfach waehlbare SF:
/// Statt des Switches erscheint ein Hinzufuegen-Button mit Zaehler, weil ein
/// An/Aus-Schalter bei mehreren Instanzen mehrdeutig waere. Entfernt werden
/// einzelne Instanzen in der Sonderfertigkeiten-Liste des jeweiligen Tabs.
///
/// [nurInformation] kennzeichnet Eintraege, die anderswo gepflegt werden
/// (Repraesentation, Ritualkenntnis, Merkmalskenntnis, Zauberspezialisierung).
/// Sie bleiben nachschlagbar, haben aber keinen Schalter.
class _SpecialAbilityChip extends StatelessWidget {
  const _SpecialAbilityChip({
    required this.name,
    required this.beschreibung,
    required this.isOwned,
    required this.isEpic,
    required this.onToggle,
    required this.onNameTap,
    this.nurInformation = false,
    this.offeneVoraussetzungen = 0,
    this.variantCount,
    this.onAddVariant,
  });

  final String name;
  final String beschreibung;
  final bool isOwned;
  final bool isEpic;
  final ValueChanged<bool> onToggle;
  final VoidCallback onNameTap;

  /// Der Eintrag wird an anderer Stelle im Heldenbogen gepflegt.
  final bool nurInformation;

  /// Anzahl der nicht erfuellten Voraussetzungen.
  final int offeneVoraussetzungen;

  /// Anzahl bereits erworbener Varianten, oder `null` bei einfachen SF.
  final int? variantCount;

  /// Wird bei mehrfach waehlbaren SF fuer einen weiteren Erwerb aufgerufen.
  final VoidCallback? onAddVariant;

  static const _epicColor = Color(0xFFB8860B); // goldenrod

  bool get _istGesperrt => !isOwned && offeneVoraussetzungen > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = isEpic
        ? _epicColor
        : (isOwned
              ? colorScheme.primary
              : (_istGesperrt ? colorScheme.error : theme.dividerColor));
    final bgColor = isOwned
        ? (isEpic
              ? Color.alphaBlend(
                  const Color(0x22B8860B),
                  colorScheme.primaryContainer,
                )
              : colorScheme.primaryContainer)
        : colorScheme.surfaceContainerHighest;
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: isOwned || isEpic ? 2.0 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: onNameTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isEpic) ...[
                        const Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: _epicColor,
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (_istGesperrt) ...[
                        Icon(
                          Icons.lock_outline,
                          size: 13,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          name,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isOwned ? colorScheme.primary : null,
                            decoration: TextDecoration.underline,
                            decorationColor: isOwned
                                ? colorScheme.primary
                                : theme.hintColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_istGesperrt)
                  Text(
                    offeneVoraussetzungen == 1
                        ? '1 Voraussetzung offen'
                        : '$offeneVoraussetzungen Voraussetzungen offen',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (beschreibung.trim().isNotEmpty)
                  Text(
                    beschreibung.trim(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (nurInformation)
            Padding(
              padding: const EdgeInsets.only(right: 8, left: 4),
              child: Tooltip(
                message: 'Wird an anderer Stelle im Heldenbogen gepflegt',
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (variantCount == null)
            Switch(
              value: isOwned,
              onChanged: onToggle,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          else ...[
            if (variantCount! > 0)
              Text(
                '$variantCount×',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            IconButton(
              key: ValueKey<String>('sf-add-variant-$name'),
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'Weitere Auswahl erwerben',
              visualDensity: VisualDensity.compact,
              onPressed: onAddVariant,
            ),
          ],
        ],
      ),
    );
  }
}
