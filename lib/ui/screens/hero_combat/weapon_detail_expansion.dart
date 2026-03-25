part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Aufklappbare Berechnungsschritte fuer die aktive Waffe.
/// Zeigt AT-, PA-, TP- und INI-Berechnung mit allen Einzelwerten.
extension _WeaponDetailExpansion on _HeroCombatTabState {
  Widget buildWeaponCalculationDetails({
    required CombatPreviewStats preview,
    required bool isEditing,
  }) {
    final weapon = _draftCombatConfig.selectedWeapon;
    final manual = _draftCombatConfig.manualMods;
    final theme = Theme.of(context);

    return ExpansionTile(
      key: const ValueKey<String>('combat-weapon-calculation-details'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text('Berechnungsschritte', style: theme.textTheme.titleSmall),
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: preview.isRangedWeapon
              ? _buildRangedDetails(
                  preview: preview,
                  weapon: weapon,
                  manual: manual,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _calcSection(
                      title: 'Attacke (AT)',
                      result: preview.at,
                      steps: [
                        _calcStep(
                          'Talent AT-Anteil',
                          _talentAtValue(weapon.talentId),
                        ),
                        _calcStep(
                          'AT-Basis',
                          preview.at -
                              _talentAtValue(weapon.talentId) -
                              weapon.wmAt -
                              preview.waffenmeisterAtBonus -
                              (preview.specBonus) -
                              preview.offhandAtMod -
                              manual.atMod -
                              _atEbePart(preview.ebe),
                        ),
                        _calcStep('WM AT (Waffe)', weapon.wmAt),
                        if (preview.waffenmeisterAtBonus != 0)
                          _calcStep(
                            'Waffenmeister AT',
                            preview.waffenmeisterAtBonus,
                          ),
                        _calcStep('eBE AT-Anteil', _atEbePart(preview.ebe)),
                        if (preview.specBonus > 0)
                          _calcStep('Spezialisierung', preview.specBonus),
                        if (preview.offhandAtMod != 0)
                          _calcStep('Nebenhand AT', preview.offhandAtMod),
                        if (manual.atMod != 0)
                          _calcStep('Manueller Mod', manual.atMod),
                      ],
                    ),
                    const Divider(),
                    _calcSection(
                      title: 'Parade (PA)',
                      result: preview.paMitIniParadeMod,
                      steps: [
                        _calcStep(
                          'Talent PA-Anteil',
                          _talentPaValue(weapon.talentId),
                        ),
                        _calcStep('PA-Basis', preview.paBase),
                        if (preview.axxPaBaseBonus != 0)
                          _calcStep('Axxeleratus PA', preview.axxPaBaseBonus),
                        _calcStep('WM PA (Waffe)', weapon.wmPa),
                        if (preview.waffenmeisterPaBonus != 0)
                          _calcStep(
                            'Waffenmeister PA',
                            preview.waffenmeisterPaBonus,
                          ),
                        _calcStep('eBE PA-Anteil', _paEbePart(preview.ebe)),
                        if (preview.offhandPaBonus != 0)
                          _calcStep('Nebenhand PA', preview.offhandPaBonus),
                        if (manual.paMod != 0)
                          _calcStep('Manueller Mod', manual.paMod),
                        if (preview.iniParadeMod != 0)
                          _calcStep('INI-Parade-Bonus', preview.iniParadeMod),
                      ],
                    ),
                    const Divider(),
                    _calcSection(
                      title: 'Trefferpunkte (TP)',
                      resultLabel: preview.tpExpression,
                      steps: [
                        _calcStep(
                          'Wuerfel',
                          null,
                          label: '${weapon.tpDiceCount}W${weapon.tpDiceSides}',
                        ),
                        _calcStep('TP Grundwert', weapon.tpFlat),
                        _calcStep('TP/KK', preview.tpKk),
                        _calcStep(
                          'KK-Basis',
                          weapon.kkBase +
                              preview.waffenmeisterTpKkBaseReduction,
                          label:
                              'Schwelle ${weapon.kkThreshold + preview.waffenmeisterTpKkThresholdReduction}',
                        ),
                        if (preview.waffenmeisterTpKkBaseReduction != 0 ||
                            preview.waffenmeisterTpKkThresholdReduction != 0)
                          _calcStep(
                            'Waffenmeister TP/KK',
                            null,
                            label:
                                'Basis ${preview.waffenmeisterTpKkBaseReduction}, Schwelle ${preview.waffenmeisterTpKkThresholdReduction}',
                          ),
                      ],
                    ),
                    const Divider(),
                    _calcSection(
                      title: 'Initiative (INI)',
                      result: preview.initiative,
                      steps: [
                        _calcStep('Eigenschafts-INI', preview.eigenschaftsIni),
                        if (preview.iniBasis != preview.eigenschaftsIni)
                          _calcStep(
                            'INI-Basis-Mod',
                            preview.iniBasis - preview.eigenschaftsIni,
                          ),
                        _calcStep('= INI-Basis', preview.iniBasis),
                        _calcStep('eBE', preview.ebe),
                        if (preview.sfIniBonus != 0)
                          _calcStep('SF-Bonus', preview.sfIniBonus),
                        _calcStep(
                          'INI-Wurf',
                          preview.iniWurfEffective,
                          label: '${preview.iniDiceCount}W6',
                        ),
                        if (preview.axxIniBonus != 0)
                          _calcStep('Axxeleratus', preview.axxIniBonus),
                        if (manual.iniMod != 0)
                          _calcStep('Manueller Mod', manual.iniMod),
                        _calcStep('= Helden-INI', preview.heldenInitiative),
                        _calcStep('Waffen-INI Mod', weapon.iniMod),
                        _calcStep('INI/GE', preview.iniGe),
                        if (preview.waffenmeisterIniBonus != 0)
                          _calcStep(
                            'Waffenmeister INI',
                            preview.waffenmeisterIniBonus,
                          ),
                        _calcStep(
                          '= Helden+Waffen-INI',
                          preview.kombinierteHeldenWaffenIni,
                        ),
                        if (preview.offhandWeaponInitiative != null)
                          _calcStep(
                            'Nebenhand-Waffen-INI',
                            preview.offhandWeaponInitiative,
                          ),
                        if (preview.offhandIniMod != 0)
                          _calcStep('Nebenhand INI', preview.offhandIniMod),
                        _calcStep('= Kampf-INI', preview.kampfInitiative),
                      ],
                    ),
                    const Divider(),
                    _calcSection(
                      title: 'Ausweichen',
                      result: preview.ausweichen,
                      steps: [
                        _calcStep(
                          'PA-Basis',
                          preview.paBase - preview.axxPaBaseBonus,
                        ),
                        if (preview.sfAusweichenBonus != 0)
                          _calcStep('SF Ausweichen', preview.sfAusweichenBonus),
                        if (preview.akrobatikBonus != 0)
                          _calcStep('Akrobatik', preview.akrobatikBonus),
                        if (preview.axxAusweichenBonus != 0)
                          _calcStep('Axxeleratus', preview.axxAusweichenBonus),
                        if (preview.iniAusweichenBonus != 0)
                          _calcStep('INI-Bonus', preview.iniAusweichenBonus),
                        if (preview.ausweichenMod != 0)
                          _calcStep('Modifikator', preview.ausweichenMod),
                        _calcStep('BE Kampf', -preview.beKampf),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRangedDetails({
    required CombatPreviewStats preview,
    required MainWeaponSlot weapon,
    required CombatManualMods manual,
  }) {
    final talentEntry =
        _draftTalents[weapon.talentId.trim()] ?? const HeroTalentEntry();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _calcSection(
          title: 'Fernkampf (AT)',
          result: preview.at,
          steps: [
            _calcStep('AT-Basis (Fernkampf)', preview.rangedAtBase),
            _calcStep('Talent AT-Anteil', talentEntry.atValue),
            _calcStep('WM AT (Waffe)', weapon.wmAt),
            if (preview.waffenmeisterAtBonus != 0)
              _calcStep('Waffenmeister AT', preview.waffenmeisterAtBonus),
            _calcStep('eBE', preview.ebe),
            if (preview.specBonus != 0)
              _calcStep('Spezialisierung', preview.specBonus),
            if (preview.projectileAtMod != 0)
              _calcStep('Geschoss AT', preview.projectileAtMod),
            if (manual.atMod != 0) _calcStep('Manueller Mod', manual.atMod),
          ],
        ),
        const Divider(),
        _calcSection(
          title: 'Trefferpunkte (TP)',
          resultLabel: preview.tpExpression,
          steps: [
            _calcStep(
              'Wuerfel',
              null,
              label: '${weapon.tpDiceCount}W${weapon.tpDiceSides}',
            ),
            _calcStep('TP Grundwert', weapon.tpFlat),
            _calcStep('TP/KK', preview.tpKk),
            if (preview.waffenmeisterTpKkBaseReduction != 0 ||
                preview.waffenmeisterTpKkThresholdReduction != 0)
              _calcStep(
                'Waffenmeister TP/KK',
                null,
                label:
                    'Basis ${preview.waffenmeisterTpKkBaseReduction}, Schwelle ${preview.waffenmeisterTpKkThresholdReduction}',
              ),
            if (preview.distanceTpMod != 0)
              _calcStep(
                'Entfernung',
                preview.distanceTpMod,
                label: preview.activeDistanceLabel,
              ),
            if (preview.projectileTpMod != 0)
              _calcStep(
                'Geschoss',
                preview.projectileTpMod,
                label: preview.activeProjectileName,
              ),
          ],
        ),
        const Divider(),
        _calcSection(
          title: 'Initiative (INI)',
          result: preview.initiative,
          steps: [
            _calcStep('Eigenschafts-INI', preview.eigenschaftsIni),
            if (preview.iniBasis != preview.eigenschaftsIni)
              _calcStep(
                'INI-Basis-Mod',
                preview.iniBasis - preview.eigenschaftsIni,
              ),
            _calcStep('= INI-Basis', preview.iniBasis),
            _calcStep('eBE', preview.ebe),
            if (preview.sfIniBonus != 0)
              _calcStep('SF-Bonus', preview.sfIniBonus),
            if (manual.iniMod != 0) _calcStep('Manueller Mod', manual.iniMod),
            _calcStep('= Helden-INI', preview.heldenInitiative),
            _calcStep('Waffen-INI Mod', weapon.iniMod),
            _calcStep('INI/GE', preview.iniGe),
            if (preview.projectileIniMod != 0)
              _calcStep('Geschoss INI', preview.projectileIniMod),
            if (preview.waffenmeisterIniBonus != 0)
              _calcStep('Waffenmeister INI', preview.waffenmeisterIniBonus),
            _calcStep(
              '= Helden+Waffen-INI',
              preview.kombinierteHeldenWaffenIni,
            ),
            if (preview.offhandWeaponInitiative != null)
              _calcStep(
                'Nebenhand-Waffen-INI',
                preview.offhandWeaponInitiative,
              ),
            _calcStep('= Kampf-INI', preview.kampfInitiative),
          ],
        ),
        const Divider(),
        _calcSection(
          title: 'Ladezeit',
          resultLabel: preview.reloadTimeDisplay,
          steps: [
            _calcStep('Basis', preview.baseReloadTime),
            if (preview.schnellladenBogenActive)
              _calcStep(
                preview.schnellladenBogenTemporary
                    ? 'Schnellladen (Bogen) via Axxeleratus'
                    : 'Schnellladen (Bogen)',
                null,
                label: 'aktiv',
              ),
            if (preview.schnellladenArmbrustActive)
              _calcStep(
                preview.schnellladenArmbrustTemporary
                    ? 'Schnellladen (Armbrust) via Axxeleratus'
                    : 'Schnellladen (Armbrust)',
                null,
                label: 'aktiv',
              ),
            if (preview.waffenmeisterReloadTimeHalved)
              _calcStep('Waffenmeister', null, label: 'Ladezeit halbiert'),
          ],
        ),
      ],
    );
  }

  Widget _calcSection({
    required String title,
    int? result,
    String? resultLabel,
    required List<Widget> steps,
  }) {
    final theme = Theme.of(context);
    final displayResult = resultLabel ?? (result?.toString() ?? '?');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '= $displayResult',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...steps,
      ],
    );
  }

  Widget _calcStep(String title, int? value, {String? label}) {
    final theme = Theme.of(context);
    final valueStr = value == null
        ? (label ?? '')
        : (value >= 0 ? '+$value' : '$value');
    final displayLabel = label != null && value != null
        ? '$title ($label)'
        : title;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 200,
            child: Text(displayLabel, style: theme.textTheme.bodySmall),
          ),
          Text(
            valueStr,
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  int _talentAtValue(String talentId) {
    final entry = _draftTalents[talentId.trim()];
    return entry?.atValue ?? 0;
  }

  int _talentPaValue(String talentId) {
    final entry = _draftTalents[talentId.trim()];
    return entry?.paValue ?? 0;
  }

  int _atEbePart(int ebe) => computeAtEbePart(ebe);

  int _paEbePart(int ebe) => computePaEbePart(ebe);
}
