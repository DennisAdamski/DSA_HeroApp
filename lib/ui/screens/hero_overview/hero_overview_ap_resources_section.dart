part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewApResourcesSection on _HeroOverviewTabState {
  Widget _buildApSection(HeroSheet hero) {
    final isEditing = _editController.isEditing;
    final apTotal = isEditing ? _readInt('ap_total', min: 0) : hero.apTotal;
    final apSpent = isEditing ? _readInt('ap_spent', min: 0) : hero.apSpent;
    final apAvailable = isEditing
        ? computeAvailableAp(apTotal, apSpent)
        : hero.apAvailable;
    final level = isEditing ? computeLevelFromSpentAp(apSpent) : hero.level;

    final epicLevel =
        computeEpicLevel(hero.isEpisch, apSpent, hero.epicStartAp);
    final apUntilNext =
        computeApUntilNextEpicLevel(hero.isEpisch, apSpent, hero.epicStartAp);

    final rowItems = <Widget>[
      _buildApValueField(
        label: 'AP Gesamt',
        keyName: 'ap_total',
        currentValue: apTotal,
        onAddPressed: () => _showApIncrementDialog(
          targetKey: 'ap_total',
          label: 'AP Gesamt',
        ),
      ),
      _buildApValueField(
        label: 'AP Ausgegeben',
        keyName: 'ap_spent',
        currentValue: apSpent,
        onAddPressed: () => _showApIncrementDialog(
          targetKey: 'ap_spent',
          label: 'AP Ausgegeben',
        ),
      ),
      _buildReadOnlyValueField(
        key: const ValueKey<String>('overview-readonly-ap_available'),
        label: 'AP Verfügbar',
        value: apAvailable.toString(),
      ),
      _buildReadOnlyValueField(
        key: const ValueKey<String>('overview-readonly-level'),
        label: 'Level',
        value: level.toString(),
      ),
      if (hero.isEpisch) ...[
        _buildReadOnlyValueField(
          key: const ValueKey<String>('overview-readonly-epic-level-ap'),
          label: 'Epische Stufe',
          value: epicLevel.toString(),
        ),
        _buildReadOnlyValueField(
          key: const ValueKey<String>('overview-readonly-epic-ap-until'),
          label: 'AP bis nächste Epische Stufe',
          value: apUntilNext.toString(),
        ),
      ],
    ];

    return _SectionCard(
      title: 'AP und Level',
      titleAction: hero.isEpisch
          ? null
          : IconButton(
              key: const ValueKey<String>('overview-action-epic-activate'),
              tooltip: 'Epischen Status aktivieren',
              icon: const Icon(Icons.auto_awesome_outlined),
              onPressed: () => _activateEpicStatus(hero),
            ),
      child: _buildSingleLineFieldsRow(children: rowItems),
    );
  }

  Widget _buildApValueField({
    required String label,
    required String keyName,
    required int currentValue,
    required VoidCallback onAddPressed,
  }) {
    final isEditing = _editController.isEditing;
    final addButton = IconButton(
      key: ValueKey<String>('overview-action-add-$keyName'),
      tooltip: '$label addieren',
      onPressed: onAddPressed,
      icon: const Icon(Icons.add),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );

    if (!isEditing) {
      final theme = Theme.of(context);
      return Column(
        key: ValueKey<String>('overview-field-$keyName-view'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$currentValue'),
              addButton,
            ],
          ),
        ],
      );
    }

    return TextField(
      key: ValueKey<String>('overview-field-$keyName'),
      controller: _field(keyName),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration(label).copyWith(
        suffixIcon: addButton,
      ),
      onChanged: _onFieldChanged,
    );
  }

  Future<void> _showApIncrementDialog({
    required String targetKey,
    required String label,
  }) async {
    final dialogController = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('$label addieren'),
          content: TextField(
            controller: dialogController,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Betrag',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (v) {
              final n = int.tryParse(v.trim());
              if (n != null && n > 0) Navigator.of(ctx).pop(n);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () {
                final n = int.tryParse(dialogController.text.trim());
                if (n != null && n > 0) Navigator.of(ctx).pop(n);
              },
              child: const Text('Addieren'),
            ),
          ],
        );
      },
    );
    dialogController.dispose();
    if (result == null || !mounted) return;
    await _applyApIncrement(targetKey: targetKey, label: label, increment: result);
  }

  Widget _buildSingleLineFieldsRow({
    required List<Widget> children,
    double itemWidth = 200,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            SizedBox(width: itemWidth, child: children[i]),
            if (i < children.length - 1) const SizedBox(width: _gridSpacing),
          ],
        ],
      ),
    );
  }
}
