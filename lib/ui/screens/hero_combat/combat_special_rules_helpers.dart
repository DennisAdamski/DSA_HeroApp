part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Gemeinsame UI-Helfer fuer die Sonderfertigkeiten im Kampfregeln-Tab.
extension _CombatSpecialRulesHelpers on _HeroCombatTabState {
  /// Liefert den Aktivzustand einer SF anhand ihrer Katalog-ID.
  /// Liest sowohl dedizierte boolean-Felder als auch [activeCombatSpecialAbilityIds].
  bool _isCatalogSfActive(String id) =>
      isCombatSpecialAbilityActive(_draftCombatConfig, id);

  /// Baut den Pruefkontext fuer Erwerbsvoraussetzungen aus dem Draft-Zustand.
  ///
  /// Bewusst aus dem Draft: Wer gerade `Ausweichen I` eingeschaltet hat, soll
  /// `Ausweichen II` sofort freigegeben sehen, ohne erst zu speichern.
  ///
  /// In die Basiswerte fliessen nur die dauerhaften Modifikatoren ein —
  /// temporaere Zaubereffekte (Attributo, Axxeleratus) duerfen keinen
  /// dauerhaften Erwerb rechtfertigen.
  HeroRequirementContext? _buildCombatRequirementContext(RulesCatalog catalog) {
    final hero = _latestHero;
    if (hero == null) {
      return null;
    }
    return buildHeroRequirementContext(
      hero.copyWith(combatConfig: _draftCombatConfig),
      catalog: catalog,
      mods:
          hero.persistentMods + aggregateNamedStatModifiers(hero.statModifiers),
    );
  }

  /// Prueft die Voraussetzungen einer Kampf-SF; leer, wenn nichts pruefbar ist.
  List<RequirementCheckResult> _pruefeCombatSf(
    CombatSpecialAbilityDef ability,
    HeroRequirementContext? requirementContext,
  ) {
    if (requirementContext == null || ability.voraussetzungenStruktur.isEmpty) {
      return const <RequirementCheckResult>[];
    }
    return evaluateRequirements(
      ability.voraussetzungenStruktur,
      requirementContext,
    );
  }

  /// Fragt bei Aktivierung einer Kampf-SF/eines Manoevers die AP-Kosten ab
  /// und erhoeht bei Bestaetigung `_latestHero.apSpent`.
  /// Liefert `false`, wenn der Nutzer abgebrochen hat (Toggle bleibt aus).
  ///
  /// [voraussetzungen] blendet die Checkliste im Dialog ein. Offene Punkte
  /// sperren nicht, verlangen aber den Meisterentscheid.
  Future<bool> _confirmErwerbKosten({
    required String bezeichnung,
    required String kostenHinweis,
    bool epischerInhalt = false,
    List<RequirementCheckResult> voraussetzungen =
        const <RequirementCheckResult>[],
  }) async {
    final hero = _latestHero;
    if (hero == null) {
      return false;
    }
    final result = await showErwerbDialog(
      context: context,
      bezeichnung: bezeichnung,
      kostenHinweis: kostenHinweis.trim().isEmpty ? null : kostenHinweis.trim(),
      vorgeschlageneApKosten: parseLeadingApAmount(kostenHinweis),
      verfuegbareAp: hero.apAvailable,
      episch: hero.isEpisch,
      epischerInhalt: epischerInhalt,
      voraussetzungen: voraussetzungen,
    );
    if (result == null) {
      return false;
    }
    _latestHero = hero.copyWith(apSpent: hero.apSpent + result.apKosten);
    return true;
  }

  /// Schaltet eine SF anhand ihrer Katalog-ID — dispatcht auf das richtige Feld.
  /// Fragt beim Aktivieren vorher die AP-Kosten ab.
  Future<void> _toggleCombatSfById(
    CombatSpecialAbilityDef ability,
    bool value, {
    List<RequirementCheckResult> voraussetzungen =
        const <RequirementCheckResult>[],
  }) async {
    final id = ability.id;
    if (value) {
      final bestaetigt = await _confirmErwerbKosten(
        bezeichnung: ability.name,
        kostenHinweis: ability.kosten,
        epischerInhalt: ability.nurEpisch,
        voraussetzungen: voraussetzungen,
      );
      if (!bestaetigt) {
        return;
      }
    }
    final rules = _draftCombatConfig.specialRules;
    final armor = _draftCombatConfig.armor;
    switch (id) {
      case 'ksf_kampfreflexe':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(kampfreflexe: value));
      case 'ksf_kampfgespuer':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(kampfgespuer: value));
      case 'ksf_schnellziehen':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(schnellziehen: value));
      case 'ksf_ausweichen_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(ausweichenI: value));
      case 'ksf_ausweichen_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(ausweichenII: value));
      case 'ksf_ausweichen_iii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(ausweichenIII: value));
      case 'ksf_linkhand':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(linkhandActive: value));
      case 'ksf_schildkampf_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(schildkampfI: value));
      case 'ksf_schildkampf_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(schildkampfII: value));
      case 'ksf_parierwaffen_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(parierwaffenI: value));
      case 'ksf_parierwaffen_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(parierwaffenII: value));
      case 'ksf_klingentaenzer':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(klingentaenzer: value));
      case 'ksf_aufmerksamkeit':
        _draftCombatConfig = _draftCombatConfig.copyWith(
            specialRules: rules.copyWith(aufmerksamkeit: value));
      case 'ksf_ruestungsgewoehnung_i':
        _draftCombatConfig = _draftCombatConfig.copyWith(
          armor: armor.copyWith(
            globalArmorTrainingLevel: value
                ? (armor.globalArmorTrainingLevel < 1
                    ? 1
                    : armor.globalArmorTrainingLevel)
                : 0,
          ),
        );
      case 'ksf_ruestungsgewoehnung_ii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
          armor: armor.copyWith(
            globalArmorTrainingLevel: value
                ? (armor.globalArmorTrainingLevel < 2
                    ? 2
                    : armor.globalArmorTrainingLevel)
                : (armor.globalArmorTrainingLevel > 1 ? 1 : armor.globalArmorTrainingLevel),
          ),
        );
      case 'ksf_ruestungsgewoehnung_iii':
        _draftCombatConfig = _draftCombatConfig.copyWith(
          armor: armor.copyWith(
            globalArmorTrainingLevel: value
                ? 3
                : (armor.globalArmorTrainingLevel > 2
                    ? 2
                    : armor.globalArmorTrainingLevel),
          ),
        );
      default:
        _toggleCatalogCombatSpecialAbility(
            rules: rules, abilityId: id, isActive: value);
        return; // _toggleCatalogCombatSpecialAbility already calls _markFieldChanged
    }
    _markFieldChanged();
  }

  /// Rendert alle SF einer Gruppe.
  ///
  /// Stufenketten (`Ausweichen I-III`, `Ruestungsgewoehnung I-IV`) werden zu je
  /// einer Karte zusammengefasst, alles Uebrige bleibt ein Chip — dieselbe
  /// Aufteilung wie im Sonderfertigkeiten-Picker. [abilities] sind bereits
  /// gefiltert (z. B. nur waffenlose Stile).
  Widget _buildSfChipWrap({
    required List<CombatSpecialAbilityDef> abilities,
    required RulesCatalog catalog,
    required CombatSpecialRules rules,
    required bool isEditing,
  }) {
    if (abilities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Keine Einträge vorhanden.'),
      );
    }
    final requirementContext = _buildCombatRequirementContext(catalog);
    final ketten = buildSpecialAbilityChains(abilities);
    final einzeln = kettenloseEintraege(abilities);

    Widget chipFuer(CombatSpecialAbilityDef ability) {
      final isActive = _isCatalogSfActive(ability.id);
      final String beschreibung;
      if (ability.isUnarmedCombatStyle) {
        beschreibung = '${ability.aktiviertManoeverIds.length} Manöver';
      } else if (ability.beschreibung.trim().isNotEmpty) {
        beschreibung = ability.beschreibung.trim();
      } else {
        beschreibung = 'Kampf-Sonderfertigkeit';
      }
      final ergebnisse = _pruefeCombatSf(ability, requirementContext);
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
        child: _CombatRuleChip(
          name: ability.name,
          beschreibung: beschreibung,
          isActive: isActive,
          isEditing: isEditing,
          isEpic: ability.nurEpisch,
          offeneVoraussetzungen: isActive
              ? 0
              : offeneVoraussetzungen(ergebnisse).length,
          onToggle: (value) =>
              _toggleCombatSfById(ability, value, voraussetzungen: ergebnisse),
          onNameTap: () => _showCombatSpecialAbilityDetailsDialog(
            context: context,
            ability: ability,
            catalogManeuvers: catalog.maneuvers,
            voraussetzungen: ergebnisse,
            onGladiatorStyleChanged:
                ability.id == 'ksf_gladiatorenstil' && isEditing
                    ? (String? value) {
                        _draftCombatConfig = _draftCombatConfig.copyWith(
                          specialRules: rules.copyWith(
                            gladiatorStyleTalent: value ?? '',
                          ),
                        );
                        _markFieldChanged();
                      }
                    : null,
            gladiatorStyleTalent: rules.gladiatorStyleTalent,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final kette in ketten) ...[
          _buildCombatChainCard(
            kette: kette,
            catalog: catalog,
            requirementContext: requirementContext,
            isEditing: isEditing,
          ),
          const SizedBox(height: 8),
        ],
        if (einzeln.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: einzeln.map(chipFuer).toList(growable: false),
          ),
      ],
    );
  }

  /// Eine Stufenkette als Karte mit Stufenreihe.
  Widget _buildCombatChainCard({
    required SpecialAbilityChain<CombatSpecialAbilityDef> kette,
    required RulesCatalog catalog,
    required HeroRequirementContext? requirementContext,
    required bool isEditing,
  }) {
    // Der Aktivzustand kommt aus `_isCatalogSfActive`, weil ein Teil der
    // Kampf-SF in eigenen Feldern steht statt unter den aktiven IDs.
    final erworbeneNamen = kette.stufen
        .where((def) => _isCatalogSfActive(def.id))
        .map((def) => def.name)
        .toList(growable: false);
    final erworben = erworbeneKettenstufe(kette, erworbeneNamen);
    final naechste = naechsteKettenstufe(kette, erworbeneNamen);

    return SpecialAbilityChainCard<CombatSpecialAbilityDef>(
      kette: kette,
      erworbeneStufe: erworben,
      offeneVoraussetzungenDerNaechstenStufe: naechste == null
          ? const <RequirementCheckResult>[]
          : offeneVoraussetzungen(
              _pruefeCombatSf(naechste, requirementContext),
            ),
      onErwerben: (stufe) {
        if (!isEditing) {
          return;
        }
        _toggleCombatSfById(
          stufe,
          true,
          voraussetzungen: _pruefeCombatSf(stufe, requirementContext),
        );
      },
      onDetails: (stufe) => _showCombatSpecialAbilityDetailsDialog(
        context: context,
        ability: stufe,
        catalogManeuvers: catalog.maneuvers,
        voraussetzungen: _pruefeCombatSf(stufe, requirementContext),
      ),
    );
  }

  /// Aktualisiert den Aktivzustand einer katalogbasierten Kampf-SF.
  void _toggleCatalogCombatSpecialAbility({
    required CombatSpecialRules rules,
    required String abilityId,
    required bool isActive,
  }) {
    final active = List<String>.from(rules.activeCombatSpecialAbilityIds);
    if (isActive) {
      if (!active.contains(abilityId)) {
        active.add(abilityId);
      }
    } else {
      active.removeWhere((entry) => entry == abilityId);
    }
    _draftCombatConfig = _draftCombatConfig.copyWith(
      specialRules: rules.copyWith(activeCombatSpecialAbilityIds: active),
    );
    _markFieldChanged();
  }
}

/// Oeffnet einen adaptiven Detaildialog fuer eine Kampf-Sonderfertigkeit.
/// [onGladiatorStyleChanged] und [gladiatorStyleTalent] werden nur fuer
/// ksf_gladiatorenstil im Edit-Modus benoetigt.
Future<void> _showCombatSpecialAbilityDetailsDialog({
  required BuildContext context,
  required CombatSpecialAbilityDef ability,
  List<ManeuverDef> catalogManeuvers = const <ManeuverDef>[],
  List<RequirementCheckResult> voraussetzungen =
      const <RequirementCheckResult>[],
  void Function(String?)? onGladiatorStyleChanged,
  String gladiatorStyleTalent = '',
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (_) => _CombatSpecialAbilityDetailsDialog(
      ability: ability,
      catalogManeuvers: catalogManeuvers,
      voraussetzungen: voraussetzungen,
      onGladiatorStyleChanged: onGladiatorStyleChanged,
      gladiatorStyleTalent: gladiatorStyleTalent,
    ),
  );
}

/// Detaildialog fuer katalogbasierte Kampf-Sonderfertigkeiten.
class _CombatSpecialAbilityDetailsDialog extends StatelessWidget {
  const _CombatSpecialAbilityDetailsDialog({
    required this.ability,
    this.catalogManeuvers = const <ManeuverDef>[],
    this.voraussetzungen = const <RequirementCheckResult>[],
    this.onGladiatorStyleChanged,
    this.gladiatorStyleTalent = '',
  });

  final CombatSpecialAbilityDef ability;
  final List<ManeuverDef> catalogManeuvers;
  final List<RequirementCheckResult> voraussetzungen;
  final void Function(String?)? onGladiatorStyleChanged;
  final String gladiatorStyleTalent;

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
                  if (ability.stilTyp.trim().isNotEmpty)
                    Chip(label: Text('Stil: ${ability.stilTyp.trim()}')),
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
              // Die geprüfte Checkliste ersetzt den Freitext, sobald es
              // strukturierte Voraussetzungen gibt: Sie sagt dasselbe, nennt
              // aber zusätzlich den Stand des Helden.
              if (voraussetzungen.isNotEmpty) ...[
                const SizedBox(height: 16),
                RequirementChecklist(ergebnisse: voraussetzungen),
              ] else if (ability.voraussetzungen.trim().isNotEmpty) ...[
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
              if (ability.kampfwertBoni.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Direkte Boni', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                ...ability.kampfwertBoni.map((bonus) {
                  final bonusParts = <String>[];
                  if (bonus.atBonus != 0) {
                    bonusParts.add(
                      'AT ${bonus.atBonus >= 0 ? '+' : ''}${bonus.atBonus}',
                    );
                  }
                  if (bonus.paBonus != 0) {
                    bonusParts.add(
                      'PA ${bonus.paBonus >= 0 ? '+' : ''}${bonus.paBonus}',
                    );
                  }
                  if (bonus.iniMod != 0) {
                    bonusParts.add(
                      'INI ${bonus.iniMod >= 0 ? '+' : ''}${bonus.iniMod}',
                    );
                  }
                  final target = bonus.giltFuerTalent.trim().isEmpty
                      ? 'allgemein'
                      : bonus.giltFuerTalent.trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('$target: ${bonusParts.join(', ')}'),
                  );
                }),
              ],
              if (ability.aktiviertManoeverIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Aktivierte Manöver', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  ability.aktiviertManoeverIds
                      .map(
                        (entry) => displayNameForManeuverId(
                          entry,
                          catalogManeuvers: catalogManeuvers,
                        ),
                      )
                      .join(', '),
                ),
              ],
              // Gladiatorenstil: Bonus-Talent-Auswahl im Edit-Modus
              if (ability.id == 'ksf_gladiatorenstil' &&
                  onGladiatorStyleChanged != null) ...[
                const SizedBox(height: 16),
                Text('Bonus-Talent', style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: gladiatorStyleTalent.trim().isEmpty
                      ? null
                      : gladiatorStyleTalent,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'raufen', child: Text('Raufen')),
                    DropdownMenuItem(value: 'ringen', child: Text('Ringen')),
                  ],
                  onChanged: onGladiatorStyleChanged,
                ),
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

/// Kompaktes Chip-Widget fuer eine Kampf-SF oder ein Manoever.
/// Name ist tappbar und oeffnet einen Detail-Dialog.
/// Toggle-Switch rechts schaltet aktiv/inaktiv (nur im Edit-Modus).
class _CombatRuleChip extends StatelessWidget {
  const _CombatRuleChip({
    required this.name,
    required this.beschreibung,
    required this.isActive,
    required this.isEditing,
    required this.onToggle,
    required this.onNameTap,
    this.isEpic = false,
    this.offeneVoraussetzungen = 0,
  });

  final String name;
  final String beschreibung;
  final bool isActive;
  final bool isEditing;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onNameTap;
  final bool isEpic;

  /// Anzahl der nicht erfuellten Voraussetzungen.
  final int offeneVoraussetzungen;

  static const _epicColor = Color(0xFFB8860B); // goldenrod

  bool get _istGesperrt => !isActive && offeneVoraussetzungen > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = isEpic
        ? _epicColor
        : (isActive ? colorScheme.primary : theme.dividerColor);
    final bgColor = isActive
        ? (isEpic
            ? Color.alphaBlend(
                const Color(0x22B8860B), colorScheme.primaryContainer)
            : colorScheme.primaryContainer)
        : colorScheme.surfaceContainerHighest;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: borderColor,
          width: isActive || isEpic ? 2.0 : 1.0,
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
                            color: isActive ? colorScheme.primary : null,
                            decoration: TextDecoration.underline,
                            decorationColor: isActive
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
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.error),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (beschreibung.trim().isNotEmpty)
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
          Switch(
            value: isActive,
            onChanged: isEditing ? onToggle : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
