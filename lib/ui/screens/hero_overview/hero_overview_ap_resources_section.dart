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

    final epicLevel = computeEpicLevel(
      hero.isEpisch,
      apSpent,
      hero.epicStartAp,
    );

    final rowItems = <Widget>[
      _buildApValueField(
        label: 'AP Gesamt',
        keyName: 'ap_total',
        currentValue: apTotal,
        onAddPressed: () =>
            _showApIncrementDialog(targetKey: 'ap_total', label: 'AP Gesamt'),
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
      _buildLevelField(
        level: level,
        epicLevel: hero.isEpisch ? epicLevel : null,
      ),
    ];

    return _SectionCard(
      title: 'AP und Level',
      titleAction: hero.isEpisch
          ? IconButton(
              key: const ValueKey<String>('overview-action-epic-edit'),
              tooltip: 'Epischen Status bearbeiten',
              icon: const Icon(Icons.auto_awesome),
              onPressed: () => _editEpicStatus(hero),
            )
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
            children: [Text('$currentValue'), addButton],
          ),
        ],
      );
    }

    return TextField(
      key: ValueKey<String>('overview-field-$keyName'),
      controller: _field(keyName),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration(label).copyWith(suffixIcon: addButton),
      onChanged: _onFieldChanged,
    );
  }

  Future<void> _showApIncrementDialog({
    required String targetKey,
    required String label,
  }) async {
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    );
    if (!darfBearbeiten || !mounted) {
      return;
    }
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _ApBetragDialog(label: label),
    );
    if (result == null || !mounted) return;
    await _applyApIncrement(
      targetKey: targetKey,
      label: label,
      increment: result,
    );
  }

  Widget _buildLevelField({required int level, required int? epicLevel}) {
    if (epicLevel == null) {
      return _buildReadOnlyValueField(
        key: const ValueKey<String>('overview-readonly-level'),
        label: 'Level',
        value: level.toString(),
      );
    }
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey<String>('overview-readonly-level'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Level',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              tooltip: 'Links: Normales Level | Rechts: Epische Stufe',
              icon: Icon(
                Icons.info_outline,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              onPressed: null,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('$level / $epicLevel'),
      ],
    );
  }

  Widget _buildSingleLineFieldsRow({
    required List<Widget> children,
    double targetItemWidth = 200,
  }) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // Anzahl Spalten anhand der verfuegbaren Breite bestimmen: auf schmalen
        // Screens eine Spalte, auf breiten bis zu so vielen, wie Felder da sind.
        final columns = available.isFinite
            ? (available / targetItemWidth).floor().clamp(1, children.length)
            : children.length;
        final itemWidth = available.isFinite
            ? (available - _gridSpacing * (columns - 1)) / columns
            : targetItemWidth;
        return Wrap(
          spacing: _gridSpacing,
          runSpacing: _gridSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Fragt den AP-Betrag ab, der addiert werden soll.
///
/// Eigenes Widget, damit der Controller erst mit dem Dialog selbst entsorgt
/// wird: Die Schließanimation baut das Textfeld nach dem `pop` noch einmal
/// auf, ein vorher entsorgter Controller wirft dann.
class _ApBetragDialog extends StatefulWidget {
  const _ApBetragDialog({required this.label});

  final String label;

  @override
  State<_ApBetragDialog> createState() => _ApBetragDialogState();
}

class _ApBetragDialogState extends State<_ApBetragDialog> {
  final TextEditingController _betrag = TextEditingController();

  @override
  void dispose() {
    _betrag.dispose();
    super.dispose();
  }

  // Schließt mit dem Betrag, wenn er eine positive ganze Zahl ist.
  void _uebernehmen(String text) {
    final betrag = int.tryParse(text.trim());
    if (betrag != null && betrag > 0) {
      Navigator.of(context).pop(betrag);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.label} addieren'),
      content: TextField(
        controller: _betrag,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'Betrag',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onSubmitted: _uebernehmen,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: () => _uebernehmen(_betrag.text),
          child: const Text('Addieren'),
        ),
      ],
    );
  }
}
