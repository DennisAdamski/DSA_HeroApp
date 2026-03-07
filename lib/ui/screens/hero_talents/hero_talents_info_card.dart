part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsInfoCard on _HeroTalentTableTabState {
  Widget _buildTopActionBar({
    required String heroId,
    required int combatBaseBe,
    required int activeTalentBe,
    required List<TalentDef> allTalents,
    required List<TalentDef> allCatalogTalents,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FilledButton.icon(
                key: const ValueKey<String>('talents-local-start-edit'),
                onPressed: _editController.isEditing
                    ? null
                    : () {
                        _startEdit();
                      },
                icon: const Icon(Icons.edit),
                label: const Text('Bearbeiten'),
              ),
              if (_editController.isEditing) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey<String>('talents-catalog-open'),
                  onPressed: () => _showTalentKatalog(context, allTalents),
                  icon: const Icon(Icons.library_add),
                  label: const Text('Talente verwalten'),
                ),
              ],
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey<String>('talents-be-screen-open'),
                onPressed: () => _openTalentBeScreen(
                  heroId: heroId,
                  combatBaseBe: combatBaseBe,
                ),
                icon: const Icon(Icons.shield_outlined),
                label: Text('BE konfigurieren ($activeTalentBe)'),
              ),
              if (_editController.isEditing) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey<String>('meta-talents-manage-open'),
                  onPressed: () => _openMetaTalentManager(allCatalogTalents),
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Meta-Talente verwalten'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombatActionBar({required List<TalentDef> allTalents}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: _editController.isEditing
            ? FilledButton.icon(
                key: const ValueKey<String>('combat-talents-catalog-open'),
                onPressed: () => _showTalentKatalog(context, allTalents),
                icon: const Icon(Icons.library_add),
                label: const Text('Kampftalente verwalten'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _openTalentBeScreen({
    required String heroId,
    required int combatBaseBe,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          TalentBeConfigDialog(heroId: heroId, combatBaseBe: combatBaseBe),
    );
  }

  Widget _buildSpecialAbilitiesTab() {
    final isEditing = _editController.isEditing;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        key: const ValueKey<String>('talents-special-abilities-global'),
        controller: _talentSpecialAbilitiesController,
        readOnly: !isEditing,
        maxLines: 8,
        decoration: const InputDecoration(
          labelText: 'Sonderfertigkeiten',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
        onChanged: isEditing
            ? (value) {
                _draftTalentSpecialAbilities = value;
                _markFieldChanged();
              }
            : null,
      ),
    );
  }
}

class TalentBeConfigDialog extends ConsumerStatefulWidget {
  const TalentBeConfigDialog({
    super.key,
    required this.heroId,
    required this.combatBaseBe,
  });

  final String heroId;
  final int combatBaseBe;

  @override
  ConsumerState<TalentBeConfigDialog> createState() =>
      _TalentBeConfigDialogState();
}

class _TalentBeConfigDialogState extends ConsumerState<TalentBeConfigDialog> {
  late final TextEditingController _overrideController;

  @override
  void initState() {
    super.initState();
    final value = ref.read(talentBeOverrideProvider(widget.heroId));
    _overrideController = TextEditingController(
      text: value == null ? '' : value.toString(),
    );
  }

  @override
  void dispose() {
    _overrideController.dispose();
    super.dispose();
  }

  void _updateOverride(String raw) {
    final trimmed = raw.trim();
    final nextValue = trimmed.isEmpty ? null : int.tryParse(trimmed);
    ref.read(talentBeOverrideProvider(widget.heroId).notifier).state =
        nextValue;
    setState(() {});
  }

  void _clearOverride() {
    _overrideController.clear();
    ref.read(talentBeOverrideProvider(widget.heroId).notifier).state = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final overrideValue = ref.watch(talentBeOverrideProvider(widget.heroId));
    final activeTalentBe = overrideValue ?? widget.combatBaseBe;
    return AlertDialog(
      title: const Text('Talent-BE'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BE (Kampf): ${widget.combatBaseBe}',
              key: const ValueKey<String>('talents-be-combat-default'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('talents-be-override-field'),
              controller: _overrideController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]*')),
              ],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'BE Override',
              ),
              onChanged: _updateOverride,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey<String>('talents-be-override-clear'),
                  onPressed: _clearOverride,
                  icon: const Icon(Icons.clear),
                  label: const Text('Override loeschen'),
                ),
                Text(
                  'Aktive BE: $activeTalentBe',
                  key: const ValueKey<String>('talents-be-active-value'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schliessen'),
        ),
      ],
    );
  }
}
