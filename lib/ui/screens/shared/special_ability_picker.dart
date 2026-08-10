import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/protected_content_helpers.dart';
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
    return _ownedNamesLower.contains(ability.name.trim().toLowerCase());
  }

  /// Anzahl bereits eingetragener Instanzen einer mehrfach waehlbaren SF.
  int _ownedCount(SpecialAbilityDef ability) =>
      countOwnedVariants(_ownedNamesLower, ability.name);

  Future<void> _toggle(SpecialAbilityDef ability, bool value) async {
    if (value) {
      await _acquire(ability);
    } else {
      widget.onRemove(ability);
      if (!mounted) {
        return;
      }
      setState(() {
        _ownedNamesLower.remove(ability.name.trim().toLowerCase());
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
        builder: (_) => _VariantSelectionDialog(
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
      builder: (_) => _SpecialAbilityDetailsDialog(ability: ability),
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
      grouped[key]!
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
    return ExpansionTile(
      title: Text('$title (${abilities.length})'),
      initiallyExpanded: abilities.length <= 8,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: abilities.map((ability) {
              return ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
                child: _SpecialAbilityChip(
                  name: ability.name,
                  beschreibung: ability.beschreibung,
                  isOwned: _isOwned(ability),
                  isEpic: ability.nurEpisch,
                  variantCount: ability.mehrfachwaehlbar
                      ? _ownedCount(ability)
                      : null,
                  onToggle: (value) => _toggle(ability, value),
                  onAddVariant: () => _acquire(ability),
                  onNameTap: () => _showDetails(ability),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Detaildialog fuer eine katalogbasierte allgemeine/karmale/magische SF.
class _SpecialAbilityDetailsDialog extends StatelessWidget {
  const _SpecialAbilityDetailsDialog({required this.ability});

  final SpecialAbilityDef ability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(ability.name),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (ability.gruppe.trim().isNotEmpty)
                    Chip(label: Text('Gruppe: ${ability.gruppe.trim()}')),
                  if (ability.kategorie.trim().isNotEmpty)
                    Chip(label: Text('Kategorie: ${ability.kategorie.trim()}')),
                  if (ability.seite.trim().isNotEmpty)
                    Chip(label: Text('S. ${ability.seite.trim()}')),
                ],
              ),
              if (ability.beschreibung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Beschreibung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.beschreibung.trim()),
              ],
              if (ability.erklarungLang.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Lange Erklärung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Consumer(
                  builder: (context, ref, _) {
                    final visible = ref.watch(catalogContentVisibleProvider);
                    final password = ref
                        .watch(appSettingsProvider)
                        .valueOrNull
                        ?.catalogContentPassword;
                    final resolved = resolveProtectedValue(
                      raw: ability.erklarungLang.trim(),
                      unlocked: visible,
                      password: password,
                    );
                    if (resolved == null) {
                      return Text(
                        lockedContentHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                    return Text(resolved);
                  },
                ),
              ],
              if (ability.voraussetzungen.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Voraussetzungen', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.voraussetzungen.trim()),
              ],
              if (ability.verbreitung.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Verbreitung', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.verbreitung.trim()),
              ],
              if (ability.kosten.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Kosten', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(ability.kosten.trim()),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
      ],
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
class _SpecialAbilityChip extends StatelessWidget {
  const _SpecialAbilityChip({
    required this.name,
    required this.beschreibung,
    required this.isOwned,
    required this.isEpic,
    required this.onToggle,
    required this.onNameTap,
    this.variantCount,
    this.onAddVariant,
  });

  final String name;
  final String beschreibung;
  final bool isOwned;
  final bool isEpic;
  final ValueChanged<bool> onToggle;
  final VoidCallback onNameTap;

  /// Anzahl bereits erworbener Varianten, oder `null` bei einfachen SF.
  final int? variantCount;

  /// Wird bei mehrfach waehlbaren SF fuer einen weiteren Erwerb aufgerufen.
  final VoidCallback? onAddVariant;

  static const _epicColor = Color(0xFFB8860B); // goldenrod

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = isEpic
        ? _epicColor
        : (isOwned ? colorScheme.primary : theme.dividerColor);
    final bgColor = isOwned
        ? (isEpic
            ? Color.alphaBlend(
                const Color(0x22B8860B), colorScheme.primaryContainer)
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
                if (beschreibung.trim().isNotEmpty)
                  Text(
                    beschreibung.trim(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (variantCount == null)
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

/// Dialog zur Auswahl der Variante einer mehrfach waehlbaren Sonderfertigkeit
/// (Kultur, Gelaende, Ort, Klima, Geheimwissen).
///
/// Zeigt die katalogisierten Vorschlaege als Dropdown und — sofern der Katalog
/// es erlaubt — zusaetzlich ein Freitextfeld. Bereits belegte Varianten werden
/// ausgeblendet.
class _VariantSelectionDialog extends StatefulWidget {
  const _VariantSelectionDialog({
    required this.ability,
    required this.bereitsBelegt,
  });

  final SpecialAbilityDef ability;
  final Set<String> bereitsBelegt;

  @override
  State<_VariantSelectionDialog> createState() =>
      _VariantSelectionDialogState();
}

class _VariantSelectionDialogState extends State<_VariantSelectionDialog> {
  static const _freeTextValue = '__freitext__';

  late final List<String> _options;
  late final TextEditingController _freeTextController;
  String? _selected;

  @override
  void initState() {
    super.initState();
    final belegt = widget.bereitsBelegt
        .map((entry) => entry.trim().toLowerCase())
        .toSet();
    _options = widget.ability.varianten
        .where((option) => !belegt.contains(option.trim().toLowerCase()))
        .toList(growable: false);
    _freeTextController = TextEditingController();
    _selected = _options.isEmpty && widget.ability.variantenFreitext
        ? _freeTextValue
        : null;
  }

  /// Alle Katalogoptionen sind belegt und Freitext ist nicht erlaubt —
  /// es gibt nichts mehr zu erwerben.
  bool get _isExhausted =>
      _options.isEmpty && !widget.ability.variantenFreitext;

  @override
  void dispose() {
    _freeTextController.dispose();
    super.dispose();
  }

  bool get _isFreeText => _selected == _freeTextValue;

  String get _resolvedVariant =>
      _isFreeText ? _freeTextController.text.trim() : (_selected ?? '').trim();

  String get _label => widget.ability.variantenLabel.trim().isEmpty
      ? 'Auswahl'
      : widget.ability.variantenLabel.trim();

  @override
  Widget build(BuildContext context) {
    final allowsFreeText = widget.ability.variantenFreitext;
    return AdaptiveInputDialog(
      title: '${widget.ability.name}: $_label wählen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isExhausted)
            Text(
              'Alle Auswahlmöglichkeiten sind bereits erworben.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (_options.isNotEmpty)
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('sf-variant-dropdown'),
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final option in _options)
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  ),
                if (allowsFreeText)
                  const DropdownMenuItem<String>(
                    value: _freeTextValue,
                    child: Text('Eigene Eingabe…'),
                  ),
              ],
              onChanged: (value) => setState(() => _selected = value),
            ),
          if (_options.isNotEmpty && _isFreeText) const SizedBox(height: 12),
          if (_isFreeText)
            TextField(
              key: const ValueKey<String>('sf-variant-freetext'),
              controller: _freeTextController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _resolvedVariant.isEmpty
              ? null
              : () => Navigator.of(context).pop(_resolvedVariant),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}
