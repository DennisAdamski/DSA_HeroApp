part of '../hero_magic_tab.dart';

/// Kopfbereich des Magie-Tabs: Repräsentation und Merkmalskenntnisse.
class _MagicHeaderSection extends StatelessWidget {
  const _MagicHeaderSection({
    required this.representationen,
    required this.merkmalskenntnisse,
    required this.magicLeadAttribute,
    required this.isEditing,
    required this.onRepresentationenChanged,
    required this.onMerkmalskenntnisseChanged,
    required this.onMagicLeadAttributeChanged,
  });

  final List<String> representationen;
  final List<String> merkmalskenntnisse;
  final String magicLeadAttribute;
  final bool isEditing;
  final void Function(List<String>) onRepresentationenChanged;
  final void Function(List<String>) onMerkmalskenntnisseChanged;
  final void Function(String value) onMagicLeadAttributeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CodexSectionCard(
        title: 'Repräsentationen & Fokus',
        subtitle:
            'Repräsentationen, Merkmalskenntnisse und arkane Leiteigenschaft.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repräsentation', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: kRepresentationen
                  .map((rep) {
                    final selected = representationen.contains(rep);
                    return FilterChip(
                      label: Text(rep),
                      selected: selected,
                      onSelected: isEditing
                          ? (value) {
                              final updated = List<String>.from(
                                representationen,
                              );
                              if (value) {
                                updated.add(rep);
                              } else {
                                updated.remove(rep);
                              }
                              onRepresentationenChanged(updated);
                            }
                          : null,
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('magic-lead-attribute-field'),
              initialValue: magicLeadAttribute.isEmpty
                  ? null
                  : magicLeadAttribute,
              decoration: const InputDecoration(
                labelText: 'Leiteigenschaft',
                border: OutlineInputBorder(),
                helperText: 'Wird für Meisterliche Regeneration verwendet.',
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'MU', child: Text('MU')),
                DropdownMenuItem<String>(value: 'KL', child: Text('KL')),
                DropdownMenuItem<String>(value: 'IN', child: Text('IN')),
                DropdownMenuItem<String>(value: 'CH', child: Text('CH')),
                DropdownMenuItem<String>(value: 'FF', child: Text('FF')),
                DropdownMenuItem<String>(value: 'GE', child: Text('GE')),
                DropdownMenuItem<String>(value: 'KO', child: Text('KO')),
                DropdownMenuItem<String>(value: 'KK', child: Text('KK')),
              ],
              onChanged: isEditing
                  ? (value) => onMagicLeadAttributeChanged(value ?? '')
                  : null,
            ),
            if (isEditing && magicLeadAttribute.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey<String>('magic-lead-attribute-clear'),
                  onPressed: () => onMagicLeadAttributeChanged(''),
                  icon: const Icon(Icons.clear),
                  label: const Text('Leiteigenschaft löschen'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Merkmalskenntnisse', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: kMerkmale
                  .map((merkmal) {
                    final selected = merkmalskenntnisse.contains(merkmal);
                    return FilterChip(
                      label: Text(merkmal),
                      selected: selected,
                      onSelected: isEditing
                          ? (value) {
                              final updated = List<String>.from(
                                merkmalskenntnisse,
                              );
                              if (value) {
                                updated.add(merkmal);
                              } else {
                                updated.remove(merkmal);
                              }
                              onMerkmalskenntnisseChanged(updated);
                            }
                          : null,
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
