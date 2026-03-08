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
      if (isEditing)
        _buildApIncrementField(
          label: 'AP Gesamt addieren',
          incrementKey: 'ap_total_add',
          onPressed: () => _applyApIncrement(
            targetKey: 'ap_total',
            incrementKey: 'ap_total_add',
            label: 'AP Gesamt',
          ),
        ),
      _buildInputField(
        label: 'AP Ausgegeben',
        keyName: 'ap_spent',
        keyboardType: TextInputType.number,
      ),
      if (isEditing)
        _buildApIncrementField(
          label: 'AP Ausgegeben addieren',
          incrementKey: 'ap_spent_add',
          onPressed: () => _applyApIncrement(
            targetKey: 'ap_spent',
            incrementKey: 'ap_spent_add',
            label: 'AP Ausgegeben',
          ),
        ),
      _buildReadOnlyValueField(
        key: const ValueKey<String>('overview-readonly-ap_available'),
        label: 'AP Verfuegbar',
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
    );
  }

  Widget _buildCurrentResourcesSection() {
    return _SectionCard(
      title: 'Aktuelle Ressourcen',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSingleLineFieldsRow(
            children: [
              _buildInputField(
                label: 'LeP aktuell',
                keyName: 'cur_lep',
                keyboardType: TextInputType.number,
              ),
              _buildInputField(
                label: 'AsP aktuell',
                keyName: 'cur_asp',
                keyboardType: TextInputType.number,
              ),
              _buildInputField(
                label: 'Au aktuell',
                keyName: 'cur_au',
                keyboardType: TextInputType.number,
              ),
              _buildInputField(
                label: 'KaP aktuell',
                keyName: 'cur_kap',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          const SizedBox(height: _gridSpacing),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey<String>('status-active-spells-open'),
              onPressed: () {
                showActiveSpellEffectsDialog(
                  context: context,
                  heroId: widget.heroId,
                );
              },
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Zauber aktivieren'),
            ),
          ),
        ],
      ),
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
