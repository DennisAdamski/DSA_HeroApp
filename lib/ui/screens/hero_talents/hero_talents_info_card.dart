part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsInfoCard on _HeroTalentTableTabState {
  Widget _buildTalentBeInfoCard({
    required int combatBaseBe,
    required int activeTalentBe,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              'BE (Kampf): ${_formatWholeNumber(combatBaseBe)}',
              key: const ValueKey<String>('talents-be-combat-default'),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: TextField(
                key: const ValueKey<String>('talents-be-override-field'),
                controller: _talentBeOverrideController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  labelText: 'BE Override',
                ),
                onChanged: _updateTalentBeOverride,
              ),
            ),
            IconButton(
              key: const ValueKey<String>('talents-be-override-clear'),
              tooltip: 'Temporaere BE zuruecksetzen',
              onPressed: _talentBeOverride == null
                  ? null
                  : _clearTalentBeOverride,
              icon: const Icon(Icons.clear),
            ),
            const SizedBox(width: 6),
            Text(
              'Aktive BE: ${_formatWholeNumber(activeTalentBe)}',
              key: const ValueKey<String>('talents-be-active-value'),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}
