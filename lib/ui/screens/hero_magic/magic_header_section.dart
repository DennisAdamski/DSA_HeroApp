part of '../hero_magic_tab.dart';

/// Kopfbereich des Magie-Tabs: Repraesentation und Merkmalskenntnisse.
class _MagicHeaderSection extends StatelessWidget {
  const _MagicHeaderSection({
    required this.representationen,
    required this.merkmalskenntnisse,
    required this.isEditing,
    required this.onRepresentationenChanged,
    required this.onMerkmalskenntnisseChanged,
  });

  final List<String> representationen;
  final List<String> merkmalskenntnisse;
  final bool isEditing;
  final void Function(List<String>) onRepresentationenChanged;
  final void Function(List<String>) onMerkmalskenntnisseChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Repräsentation', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: kRepresentationen.map((rep) {
                final selected = representationen.contains(rep);
                return FilterChip(
                  label: Text(rep),
                  selected: selected,
                  onSelected: isEditing
                      ? (value) {
                          final updated = List<String>.from(representationen);
                          if (value) {
                            updated.add(rep);
                          } else {
                            updated.remove(rep);
                          }
                          onRepresentationenChanged(updated);
                        }
                      : null,
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 16),
            Text('Merkmalskenntnisse', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: kMerkmale.map((merkmal) {
                final selected = merkmalskenntnisse.contains(merkmal);
                return FilterChip(
                  label: Text(merkmal),
                  selected: selected,
                  onSelected: isEditing
                      ? (value) {
                          final updated =
                              List<String>.from(merkmalskenntnisse);
                          if (value) {
                            updated.add(merkmal);
                          } else {
                            updated.remove(merkmal);
                          }
                          onMerkmalskenntnisseChanged(updated);
                        }
                      : null,
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
