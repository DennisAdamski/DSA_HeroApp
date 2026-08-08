part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Sonderfertigkeiten
// ---------------------------------------------------------------------------

class _SonderfertigkeitenSection extends StatelessWidget {
  const _SonderfertigkeitenSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    final sfs = companion.sonderfertigkeiten;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Sonderfertigkeiten'),
        if (sfs.isEmpty && !isEditing)
          Text(
            'Keine Sonderfertigkeiten eingetragen.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (int i = 0; i < sfs.length; i++)
            _SonderfertigkeitTile(
              sf: sfs[i],
              isEditing: isEditing,
              onEdit: () async {
                final ctx = context;
                if (!ctx.mounted) return;
                final result =
                    await showAdaptiveInputDialog<HeroCompanionSonderfertigkeit>(
                  context: ctx,
                  builder: (_) => _SonderfertigkeitDialog(initial: sfs[i]),
                );
                if (result != null) {
                  final next =
                      List<HeroCompanionSonderfertigkeit>.from(sfs);
                  next[i] = result;
                  onChanged(companion.copyWith(sonderfertigkeiten: next));
                }
              },
              onDelete: () {
                final next =
                    List<HeroCompanionSonderfertigkeit>.from(sfs)
                      ..removeAt(i);
                onChanged(companion.copyWith(sonderfertigkeiten: next));
              },
            ),
        if (isEditing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final result = await showAdaptiveInputDialog<_SonderfertigkeitErwerb>(
                context: context,
                builder: (_) => _SonderfertigkeitDialog(
                  verfuegbareAp: companionApVerfuegbar(companion),
                ),
              );
              if (result != null) {
                onChanged(
                  companion.copyWith(
                    sonderfertigkeiten: [
                      ...companion.sonderfertigkeiten,
                      result.sf,
                    ],
                    apAusgegeben: result.apKosten > 0
                        ? (companion.apAusgegeben ?? 0) + result.apKosten
                        : companion.apAusgegeben,
                  ),
                );
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Sonderfertigkeit hinzufügen'),
          ),
        ],
      ],
    );
  }
}

class _SonderfertigkeitTile extends StatelessWidget {
  const _SonderfertigkeitTile({
    required this.sf,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
  });

  final HeroCompanionSonderfertigkeit sf;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sf.name.isEmpty ? '–' : sf.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (sf.beschreibung.isNotEmpty)
                Text(
                  sf.beschreibung,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        if (isEditing) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            tooltip: 'Bearbeiten',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            tooltip: 'Löschen',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }
}

/// Ergebnis des Sonderfertigkeiten-Dialogs: die Eingabe plus AP-Kosten,
/// falls beim Neuanlegen ein Erwerbs-Dialog bestaetigt wurde (sonst `0`).
class _SonderfertigkeitErwerb {
  const _SonderfertigkeitErwerb({required this.sf, this.apKosten = 0});

  final HeroCompanionSonderfertigkeit sf;
  final int apKosten;
}

class _SonderfertigkeitDialog extends StatefulWidget {
  const _SonderfertigkeitDialog({this.initial, this.verfuegbareAp = 0});
  final HeroCompanionSonderfertigkeit? initial;
  final int verfuegbareAp;

  @override
  State<_SonderfertigkeitDialog> createState() =>
      _SonderfertigkeitDialogState();
}

class _SonderfertigkeitDialogState extends State<_SonderfertigkeitDialog> {
  late final TextEditingController _name;
  late final TextEditingController _beschreibung;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial?.name ?? '');
    _beschreibung = TextEditingController(
      text: widget.initial?.beschreibung ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _beschreibung.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    var apKosten = 0;
    if (_isNew) {
      final erwerb = await showErwerbDialog(
        context: context,
        bezeichnung: name.isEmpty ? 'Sonderfertigkeit' : name,
        verfuegbareAp: widget.verfuegbareAp,
      );
      if (erwerb == null) {
        return;
      }
      apKosten = erwerb.apKosten;
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      _SonderfertigkeitErwerb(
        sf: HeroCompanionSonderfertigkeit(
          name: name,
          beschreibung: _beschreibung.text.trim(),
        ),
        apKosten: apKosten,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _isNew;
    return AdaptiveInputDialog(
      title: isNew
          ? 'Sonderfertigkeit hinzufügen'
          : 'Sonderfertigkeit bearbeiten',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          const SizedBox(height: _fieldSpacing),
          TextField(
            controller: _beschreibung,
            decoration: const InputDecoration(
              labelText: 'Beschreibung',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isNew ? 'Hinzufügen' : 'Speichern'),
        ),
      ],
    );
  }
}
