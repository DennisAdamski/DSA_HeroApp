part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Konstanten
// ---------------------------------------------------------------------------
const double _sectionSpacing = 16;
const double _fieldSpacing = 12;
const double _innerFieldSpacing = 8;

// ---------------------------------------------------------------------------
// Hilfs-Widgets
// ---------------------------------------------------------------------------

/// Abschnittsheader mit Trennlinie.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Anzeige-/Eingabefeld fuer einen Textwert.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.value,
    required this.isEditing,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final bool isEditing;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '–' : value),
        ],
      );
    }
    return TextFormField(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Begleiter-Selektor
// ---------------------------------------------------------------------------

class _BegleiterSelector extends StatelessWidget {
  const _BegleiterSelector({
    required this.companions,
    required this.selectedIndex,
    required this.isEditing,
    required this.onSelect,
    required this.onAdd,
    required this.onDelete,
  });

  final List<HeroCompanion> companions;
  final int selectedIndex;
  final bool isEditing;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final Future<void> Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < companions.length; i++)
                ChoiceChip(
                  label: Text(
                    companions[i].name.isEmpty
                        ? 'Unbenannt'
                        : companions[i].name,
                  ),
                  selected: i == selectedIndex,
                  onSelected: (_) => onSelect(i),
                ),
            ],
          ),
        ),
        if (isEditing) ...[
          if (companions.isNotEmpty)
            IconButton(
              tooltip: 'Begleiter löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onDelete(selectedIndex),
            ),
          IconButton(
            tooltip: 'Begleiter hinzufügen',
            icon: const Icon(Icons.add),
            onPressed: onAdd,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Leerzustand
// ---------------------------------------------------------------------------

class _EmptyBegleiterHint extends StatelessWidget {
  const _EmptyBegleiterHint({
    required this.isEditing,
    required this.onAdd,
  });

  final bool isEditing;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.pets_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Begleiter vorhanden.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Begleiter hinzufügen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Begleiter-Detail (Koordinator)
// ---------------------------------------------------------------------------

class _BegleiterDetail extends StatelessWidget {
  const _BegleiterDetail({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GrunddatenSection(
          companion: companion,
          isEditing: isEditing,
          onChanged: onChanged,
        ),
        const SizedBox(height: _sectionSpacing),
        _EigenschaftenSection(
          companion: companion,
          isEditing: isEditing,
          onChanged: onChanged,
        ),
        const SizedBox(height: _sectionSpacing),
        _KampfWerteSection(
          companion: companion,
          isEditing: isEditing,
          onChanged: onChanged,
        ),
        const SizedBox(height: _sectionSpacing),
        _LepSection(
          companion: companion,
          isEditing: isEditing,
          onChanged: onChanged,
        ),
        const SizedBox(height: _sectionSpacing),
        _WeiteresSection(
          companion: companion,
          isEditing: isEditing,
          onChanged: onChanged,
        ),
        const SizedBox(height: _sectionSpacing),
        _VorNachteileSection(
          companion: companion,
          isEditing: isEditing,
          onChanged: onChanged,
        ),
        const SizedBox(height: _sectionSpacing),
        _MerkmaleSection(
          companion: companion,
          isEditing: isEditing,
          onChanged: onChanged,
        ),
        const SizedBox(height: _sectionSpacing),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grunddaten
// ---------------------------------------------------------------------------

class _GrunddatenSection extends StatelessWidget {
  const _GrunddatenSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Grunddaten'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _LabeledField(
                label: 'Name',
                value: companion.name,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(name: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _LabeledField(
                label: 'Gattung',
                value: companion.gattung,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(gattung: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _LabeledField(
                label: 'Familie',
                value: companion.familie,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(familie: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        _LabeledField(
          label: 'Aussehen',
          value: companion.aussehen,
          isEditing: isEditing,
          maxLines: 3,
          onChanged: (v) => onChanged(companion.copyWith(aussehen: v)),
        ),
        const SizedBox(height: _innerFieldSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Gewicht',
                value: companion.gewicht,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(gewicht: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _LabeledField(
                label: 'Größe',
                value: companion.groesse,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(groesse: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _LabeledField(
                label: 'Alter / Geburtsjahr',
                value: companion.alter,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(alter: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Eigenschaften
// ---------------------------------------------------------------------------

class _EigenschaftenSection extends StatelessWidget {
  const _EigenschaftenSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  static const _attrs = <(String, String)>[
    ('MU', 'mu'),
    ('KL', 'kl'),
    ('IN', 'inn'),
    ('CH', 'ch'),
    ('FF', 'ff'),
    ('GE', 'ge'),
    ('KO', 'ko'),
    ('KK', 'kk'),
  ];

  int? _valueFor(String key) {
    return switch (key) {
      'mu' => companion.mu,
      'kl' => companion.kl,
      'inn' => companion.inn,
      'ch' => companion.ch,
      'ff' => companion.ff,
      'ge' => companion.ge,
      'ko' => companion.ko,
      'kk' => companion.kk,
      _ => null,
    };
  }

  HeroCompanion _setAttr(String key, int? value) {
    return switch (key) {
      'mu' => companion.copyWith(mu: value),
      'kl' => companion.copyWith(kl: value),
      'inn' => companion.copyWith(inn: value),
      'ch' => companion.copyWith(ch: value),
      'ff' => companion.copyWith(ff: value),
      'ge' => companion.copyWith(ge: value),
      'ko' => companion.copyWith(ko: value),
      'kk' => companion.copyWith(kk: value),
      _ => companion,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Eigenschaften'),
        if (!isEditing) _buildViewMode(context) else _buildEditMode(context),
      ],
    );
  }

  Widget _buildViewMode(BuildContext context) {
    final defined = _attrs
        .where((a) => _valueFor(a.$2) != null)
        .toList(growable: false);
    if (defined.isEmpty) {
      return Text(
        'Keine Eigenschaften definiert.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (label, key) in defined)
          _AttrChip(label: label, value: _valueFor(key)!),
      ],
    );
  }

  Widget _buildEditMode(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < _attrs.length; i += 4)
          Padding(
            padding: const EdgeInsets.only(bottom: _innerFieldSpacing),
            child: Row(
              children: [
                for (int j = i; j < i + 4 && j < _attrs.length; j++) ...[
                  if (j > i) const SizedBox(width: _innerFieldSpacing),
                  Expanded(
                    child: _AttrEditField(
                      label: _attrs[j].$1,
                      value: _valueFor(_attrs[j].$2),
                      onChanged: (v) =>
                          onChanged(_setAttr(_attrs[j].$2, v)),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AttrChip extends StatelessWidget {
  const _AttrChip({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AttrEditField extends StatefulWidget {
  const _AttrEditField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_AttrEditField> createState() => _AttrEditFieldState();
}

class _AttrEditFieldState extends State<_AttrEditField> {
  late bool _enabled;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _enabled = widget.value != null;
    _controller = TextEditingController(
      text: widget.value?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(_AttrEditField old) {
    super.didUpdateWidget(old);
    final newEnabled = widget.value != null;
    if (newEnabled != _enabled) {
      _enabled = newEnabled;
    }
    final newText = widget.value?.toString() ?? '';
    if (_controller.text != newText && !_enabled) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: _enabled,
              visualDensity: VisualDensity.compact,
              onChanged: (v) {
                setState(() => _enabled = v ?? false);
                if (!(v ?? false)) {
                  _controller.clear();
                  widget.onChanged(null);
                } else {
                  widget.onChanged(int.tryParse(_controller.text));
                }
              },
            ),
            Expanded(
              child: Text(widget.label),
            ),
          ],
        ),
        TextFormField(
          controller: _controller,
          enabled: _enabled,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            if (_enabled) widget.onChanged(int.tryParse(v));
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kampf- und Bewegungswerte
// ---------------------------------------------------------------------------

class _KampfWerteSection extends StatelessWidget {
  const _KampfWerteSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Kampf- und Bewegungswerte'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NullableIntField(
                label: 'INI',
                value: companion.ini,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(ini: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'Magieresistenz',
                value: companion.magieresistenz,
                isEditing: isEditing,
                onChanged: (v) =>
                    onChanged(companion.copyWith(magieresistenz: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'Loyalität',
                value: companion.loyalitaet,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(loyalitaet: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'Eigen-AP',
                value: companion.eigenAp,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(eigenAp: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        _GeschwindigkeitenEditor(
          speeds: companion.geschwindigkeiten,
          isEditing: isEditing,
          onChanged: (speeds) =>
              onChanged(companion.copyWith(geschwindigkeiten: speeds)),
        ),
      ],
    );
  }
}

class _NullableIntField extends StatelessWidget {
  const _NullableIntField({
    required this.label,
    required this.value,
    required this.isEditing,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final bool isEditing;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value?.toString() ?? '–'),
        ],
      );
    }
    return TextFormField(
      initialValue: value?.toString() ?? '',
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v)),
    );
  }
}

class _GeschwindigkeitenEditor extends StatelessWidget {
  const _GeschwindigkeitenEditor({
    required this.speeds,
    required this.isEditing,
    required this.onChanged,
  });

  final List<HeroCompanionSpeed> speeds;
  final bool isEditing;
  final ValueChanged<List<HeroCompanionSpeed>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Geschwindigkeit',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Geschwindigkeit hinzufügen',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final next = List<HeroCompanionSpeed>.from(speeds)
                    ..add(const HeroCompanionSpeed());
                  onChanged(next);
                },
              ),
          ],
        ),
        if (speeds.isEmpty && !isEditing)
          Text(
            '–',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        for (int i = 0; i < speeds.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _SpeedRow(
              speed: speeds[i],
              isEditing: isEditing,
              onChanged: (updated) {
                final next = List<HeroCompanionSpeed>.from(speeds);
                next[i] = updated;
                onChanged(next);
              },
              onDelete: () {
                final next = List<HeroCompanionSpeed>.from(speeds)
                  ..removeAt(i);
                onChanged(next);
              },
            ),
          ),
      ],
    );
  }
}

class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.speed,
    required this.isEditing,
    required this.onChanged,
    required this.onDelete,
  });

  final HeroCompanionSpeed speed;
  final bool isEditing;
  final ValueChanged<HeroCompanionSpeed> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return Text('${speed.art}: ${speed.wert}');
    }
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: speed.art,
            decoration: const InputDecoration(
              labelText: 'Art',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => onChanged(speed.copyWith(art: v)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: speed.wert.toString(),
            decoration: const InputDecoration(
              labelText: 'Wert',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) =>
                onChanged(speed.copyWith(wert: int.tryParse(v) ?? speed.wert)),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: onDelete,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// LeP / AuP / AsP
// ---------------------------------------------------------------------------

class _LepSection extends StatelessWidget {
  const _LepSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Lebenspunkte'),
        Row(
          children: [
            Expanded(
              child: _NullableIntField(
                label: 'LeP (max)',
                value: companion.maxLep,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxLep: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AuP (max)',
                value: companion.maxAup,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxAup: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _NullableIntField(
                label: 'AsP (max)',
                value: companion.maxAsp,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(maxAsp: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weiteres
// ---------------------------------------------------------------------------

class _WeiteresSection extends StatelessWidget {
  const _WeiteresSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Weiteres'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Tragkraft',
                value: companion.tragkraft,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(tragkraft: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _LabeledField(
                label: 'Zugkraft',
                value: companion.zugkraft,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(zugkraft: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: _innerFieldSpacing),
        _LabeledField(
          label: 'Ausbildung',
          value: companion.ausbildung,
          isEditing: isEditing,
          maxLines: 3,
          onChanged: (v) => onChanged(companion.copyWith(ausbildung: v)),
        ),
        const SizedBox(height: _innerFieldSpacing),
        _LabeledField(
          label: 'Futterbedarf',
          value: companion.futterbedarf,
          isEditing: isEditing,
          onChanged: (v) => onChanged(companion.copyWith(futterbedarf: v)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Vor- und Nachteile
// ---------------------------------------------------------------------------

class _VorNachteileSection extends StatelessWidget {
  const _VorNachteileSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Vor- und Nachteile'),
        _LabeledField(
          label: 'Vor- und Nachteile',
          value: companion.vorNachteile,
          isEditing: isEditing,
          maxLines: 5,
          onChanged: (v) => onChanged(companion.copyWith(vorNachteile: v)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Merkmale Gw / Au
// ---------------------------------------------------------------------------

class _MerkmaleSection extends StatelessWidget {
  const _MerkmaleSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionHeader('Merkmale'),
            const SizedBox(width: 8),
            // TODO(companion): Bedeutung von Gw und Au klaeren.
            Text(
              '(Gw / Au – Zweck noch zu klären)',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _LabeledField(
                label: 'Gw',
                value: companion.gw,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(gw: v)),
              ),
            ),
            const SizedBox(width: _fieldSpacing),
            Expanded(
              child: _LabeledField(
                label: 'Au',
                value: companion.au,
                isEditing: isEditing,
                onChanged: (v) => onChanged(companion.copyWith(au: v)),
              ),
            ),
            const Spacer(),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}
