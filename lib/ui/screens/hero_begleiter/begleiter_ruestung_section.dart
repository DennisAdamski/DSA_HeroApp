part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Rüstung
// ---------------------------------------------------------------------------

class _RuestungSection extends StatelessWidget {
  const _RuestungSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  List<ArmorPiece> get _aktiv =>
      companion.ruestungsTeile.where((p) => p.isActive).toList();

  @override
  Widget build(BuildContext context) {
    final aktiv = _aktiv;
    final rsGesamt = computeRsTotal(aktiv);
    final beRoh = computeBeTotalRaw(aktiv);
    final rgReduk = computeRgReduction(
      globalArmorTrainingLevel: companion.ruestungsgewoehnung,
      activePieces: aktiv,
    );
    final beKampf = computeBeKampf(beRoh, rgReduk);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Rüstung'),
        if (isEditing) ...[
          Row(
            children: [
              Text(
                'Rüstungsgewöhnung:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: companion.ruestungsgewoehnung.clamp(0, 3),
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('–')),
                  DropdownMenuItem(value: 1, child: Text('RG I')),
                  DropdownMenuItem(value: 2, child: Text('RG II')),
                  DropdownMenuItem(value: 3, child: Text('RG III')),
                ],
                onChanged: (v) => onChanged(
                  companion.copyWith(ruestungsgewoehnung: v ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: _innerFieldSpacing),
        ],
        if (companion.ruestungsTeile.isEmpty && !isEditing)
          Text(
            'Keine Rüstung.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          _RuestungsTabelle(
            teile: companion.ruestungsTeile,
            isEditing: isEditing,
            onChanged: (teile) =>
                onChanged(companion.copyWith(ruestungsTeile: teile)),
          ),
          const SizedBox(height: 8),
          // Vorschau-Zeile
          Wrap(
            spacing: 16,
            children: [
              _StatChip(label: 'RS gesamt', wert: rsGesamt),
              _StatChip(label: 'BE (roh)', wert: beRoh),
              if (rgReduk > 0)
                _StatChip(label: 'RG-Reduktion', wert: -rgReduk),
              _StatChip(label: 'BE (Kampf)', wert: beKampf, highlight: true),
            ],
          ),
        ],
        if (isEditing) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              final result = await showAdaptiveDetailSheet<ArmorPiece>(
                context: context,
                builder: (_) => const _RuestungsPieceDialog(),
              );
              if (result != null) {
                onChanged(
                  companion.copyWith(
                    ruestungsTeile: [...companion.ruestungsTeile, result],
                  ),
                );
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Rüstungsstück hinzufügen'),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.wert,
    this.highlight = false,
  });

  final String label;
  final int wert;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '$wert',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
            color: highlight ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _RuestungsTabelle extends StatelessWidget {
  const _RuestungsTabelle({
    required this.teile,
    required this.isEditing,
    required this.onChanged,
  });

  final List<ArmorPiece> teile;
  final bool isEditing;
  final ValueChanged<List<ArmorPiece>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Kopfzeile
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const SizedBox(width: 40), // Aktiv-Checkbox
              Expanded(
                flex: 3,
                child: Text(
                  'Name',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'RS',
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  'BE',
                  style: Theme.of(context).textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              if (isEditing) const SizedBox(width: 64),
            ],
          ),
        ),
        const Divider(height: 1),
        for (int i = 0; i < teile.length; i++) ...[
          _RuestungsRow(
            piece: teile[i],
            isEditing: isEditing,
            onToggleActive: (active) {
              final next = List<ArmorPiece>.from(teile);
              next[i] = teile[i].copyWith(isActive: active);
              onChanged(next);
            },
            onEdit: () async {
              final context2 = context;
              if (!context2.mounted) return;
              final result = await showAdaptiveDetailSheet<ArmorPiece>(
                context: context2,
                builder: (_) => _RuestungsPieceDialog(initial: teile[i]),
              );
              if (result != null) {
                final next = List<ArmorPiece>.from(teile);
                next[i] = result;
                onChanged(next);
              }
            },
            onDelete: () {
              final next = List<ArmorPiece>.from(teile)..removeAt(i);
              onChanged(next);
            },
          ),
          if (i < teile.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _RuestungsRow extends StatelessWidget {
  const _RuestungsRow({
    required this.piece,
    required this.isEditing,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final ArmorPiece piece;
  final bool isEditing;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              value: piece.isActive,
              visualDensity: VisualDensity.compact,
              onChanged: isEditing ? (v) => onToggleActive(v ?? false) : null,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              piece.name.isEmpty ? '(kein Name)' : piece.name,
              style: piece.name.isEmpty
                  ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )
                  : null,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text('${piece.rs}', textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 36,
            child: Text('${piece.be}', textAlign: TextAlign.center),
          ),
          if (isEditing) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

/// Dialog zum Anlegen / Bearbeiten eines einzelnen Ruestungsstuecks.
class _RuestungsPieceDialog extends StatefulWidget {
  const _RuestungsPieceDialog({this.initial});

  final ArmorPiece? initial;

  @override
  State<_RuestungsPieceDialog> createState() => _RuestungsPieceDialogState();
}

class _RuestungsPieceDialogState extends State<_RuestungsPieceDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _rsCtrl;
  late TextEditingController _beCtrl;
  late bool _isActive;
  late bool _rg1Active;

  @override
  void initState() {
    super.initState();
    final p = widget.initial ?? const ArmorPiece();
    _nameCtrl = TextEditingController(text: p.name);
    _rsCtrl = TextEditingController(text: p.rs == 0 ? '' : '${p.rs}');
    _beCtrl = TextEditingController(text: p.be == 0 ? '' : '${p.be}');
    _isActive = p.isActive;
    _rg1Active = p.rg1Active;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rsCtrl.dispose();
    _beCtrl.dispose();
    super.dispose();
  }

  ArmorPiece _buildPiece() => ArmorPiece(
        name: _nameCtrl.text.trim(),
        rs: int.tryParse(_rsCtrl.text) ?? 0,
        be: int.tryParse(_beCtrl.text) ?? 0,
        isActive: _isActive,
        rg1Active: _rg1Active,
      );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null;
    return AlertDialog(
      title: Text(isNew ? 'Rüstungsstück hinzufügen' : 'Rüstungsstück bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'RS',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _beCtrl,
                    decoration: const InputDecoration(
                      labelText: 'BE',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _isActive,
              dense: true,
              title: const Text('Aktuell angelegt'),
              onChanged: (v) => setState(() => _isActive = v ?? false),
            ),
            CheckboxListTile(
              value: _rg1Active,
              dense: true,
              title: const Text('Rüstungsgewöhnung I aktiv'),
              onChanged: (v) => setState(() => _rg1Active = v ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildPiece()),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
