part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsInfoCard on _HeroTalentTableTabState {
  Widget _buildTopActionBar({
    required String heroId,
    required int combatBaseBe,
    required int activeTalentBe,
  }) {
    final visibilityMode = _readVisibilityMode();
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
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey<String>('talents-visibility-mode-toggle'),
                onPressed: () => _setVisibilityMode(!visibilityMode),
                icon: Icon(
                  visibilityMode
                      ? Icons.visibility_off_outlined
                      : Icons.visibility,
                ),
                label: Text(
                  visibilityMode
                      ? 'Sichtbarkeit beenden'
                      : 'Sichtbarkeit bearbeiten',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombatVisibilityActionBar() {
    final visibilityMode = _readVisibilityMode();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          key: const ValueKey<String>('talents-visibility-mode-toggle'),
          onPressed: () => _setVisibilityMode(!visibilityMode),
          icon: Icon(
            visibilityMode ? Icons.visibility_off_outlined : Icons.visibility,
          ),
          label: Text(
            visibilityMode
                ? 'Sichtbarkeit beenden'
                : 'Sichtbarkeit bearbeiten',
          ),
        ),
      ),
    );
  }

  Future<void> _openTalentBeScreen({
    required String heroId,
    required int combatBaseBe,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TalentBeConfigScreen(
          heroId: heroId,
          combatBaseBe: combatBaseBe,
        ),
      ),
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

class TalentBeConfigScreen extends ConsumerStatefulWidget {
  const TalentBeConfigScreen({
    super.key,
    required this.heroId,
    required this.combatBaseBe,
  });

  final String heroId;
  final int combatBaseBe;

  @override
  ConsumerState<TalentBeConfigScreen> createState() =>
      _TalentBeConfigScreenState();
}

class _TalentBeConfigScreenState extends ConsumerState<TalentBeConfigScreen> {
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
    ref.read(talentBeOverrideProvider(widget.heroId).notifier).state = nextValue;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Talent-BE')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey<String>('talents-be-override-clear'),
                  onPressed: _clearOverride,
                  icon: const Icon(Icons.clear),
                  label: const Text('Override loeschen'),
                ),
                const SizedBox(width: 12),
                Text(
                  'Aktive BE: $activeTalentBe',
                  key: const ValueKey<String>('talents-be-active-value'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
