part of 'package:dsa_heldenverwaltung/ui/screens/hero_reisebericht_tab.dart';

/// Generische Kategorieansicht mit Entry-Liste.
class _ReiseberichtCategoryView extends StatelessWidget {
  const _ReiseberichtCategoryView({
    required this.entries,
    required this.allDefs,
    required this.draft,
    required this.isEditing,
    required this.onToggleChecked,
    required this.onUpdateDraft,
  });

  final List<ReiseberichtDef> entries;
  final List<ReiseberichtDef> allDefs;
  final HeroReisebericht draft;
  final bool isEditing;
  final void Function(String id) onToggleChecked;
  final void Function(HeroReisebericht) onUpdateDraft;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(child: Text('Keine Einträge in dieser Kategorie.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final def = entries[index];
        return _ReiseberichtEntryTile(
          def: def,
          allDefs: allDefs,
          draft: draft,
          isEditing: isEditing,
          onToggleChecked: onToggleChecked,
          onUpdateDraft: onUpdateDraft,
        );
      },
    );
  }
}
