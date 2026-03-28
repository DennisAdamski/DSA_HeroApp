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

    final rowItems = <Widget>[
      _buildInputField(
        label: 'AP Gesamt',
        keyName: 'ap_total',
        keyboardType: TextInputType.number,
      ),
      _buildApIncrementField(
        label: 'AP Gesamt addieren',
        incrementKey: 'ap_total_add',
        onPressed: () => _applyApIncrement(
          targetKey: 'ap_total',
          incrementKey: 'ap_total_add',
          label: 'AP Gesamt',
        ),
        isEditing: isEditing,
      ),
      _buildInputField(
        label: 'AP Ausgegeben',
        keyName: 'ap_spent',
        keyboardType: TextInputType.number,
      ),
      _buildApIncrementField(
        label: 'AP Ausgegeben addieren',
        incrementKey: 'ap_spent_add',
        onPressed: () => _applyApIncrement(
          targetKey: 'ap_spent',
          incrementKey: 'ap_spent_add',
          label: 'AP Ausgegeben',
        ),
        isEditing: isEditing,
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
    ];

    return _SectionCard(
      title: 'AP und Level',
      child: _buildSingleLineFieldsRow(children: rowItems),
    );
  }

  Widget _buildApIncrementField({
    required String label,
    required String incrementKey,
    required VoidCallback onPressed,
    required bool isEditing,
  }) {
    return TextField(
      key: ValueKey<String>('overview-field-$incrementKey'),
      controller: _field(incrementKey),
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: _inputDecoration(label).copyWith(
        suffixIcon: IconButton(
          key: ValueKey<String>('overview-action-$incrementKey'),
          tooltip: '$label anwenden',
          onPressed: onPressed,
          icon: const Icon(Icons.add),
        ),
      ),
      onChanged: isEditing ? _onFieldChanged : null,
    );
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
