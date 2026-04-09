part of '../hero_begleiter_tab.dart';

// ---------------------------------------------------------------------------
// Eigenschaften
// ---------------------------------------------------------------------------

class _EigenschaftenSection extends StatelessWidget {
  const _EigenschaftenSection({
    required this.companion,
    required this.isEditing,
    required this.onChanged,
    this.onRaiseRegular,
  });

  final HeroCompanion companion;
  final bool isEditing;
  final ValueChanged<HeroCompanion> onChanged;
  final void Function(String key, String label)? onRaiseRegular;

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
          _AttrChip(
            label: label,
            value: companionEffektivwert(companion, key) ?? _valueFor(key)!,
            hasSteigerung: companionSteigerung(companion, key) > 0,
            onRaise: onRaiseRegular != null
                ? () => onRaiseRegular!(key, label)
                : null,
          ),
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
                      onRaise: onRaiseRegular != null &&
                              _valueFor(_attrs[j].$2) != null
                          ? () => onRaiseRegular!(
                                _attrs[j].$2,
                                _attrs[j].$1,
                              )
                          : null,
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
  const _AttrChip({
    required this.label,
    required this.value,
    this.hasSteigerung = false,
    this.onRaise,
  });
  final String label;
  final int value;
  final bool hasSteigerung;
  final VoidCallback? onRaise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          label: Text(
            '$label $value',
            style: hasSteigerung
                ? TextStyle(color: theme.colorScheme.primary)
                : null,
          ),
          visualDensity: VisualDensity.compact,
        ),
        if (onRaise != null)
          IconButton(
            icon: Icon(
              Icons.trending_up,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            tooltip: '$label steigern',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: onRaise,
          ),
      ],
    );
  }
}

class _AttrEditField extends StatefulWidget {
  const _AttrEditField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.onRaise,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final VoidCallback? onRaise;

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
                  final parsed = int.tryParse(_controller.text) ?? 0;
                  if (_controller.text != parsed.toString()) {
                    _controller.text = parsed.toString();
                  }
                  widget.onChanged(parsed);
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
            suffixIcon: widget.onRaise != null && _enabled
                ? IconButton(
                    icon: Icon(
                      Icons.trending_up,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: '${widget.label} steigern',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onRaise,
                  )
                : null,
            suffixIconConstraints: widget.onRaise != null && _enabled
                ? const BoxConstraints(minWidth: 32, minHeight: 32)
                : null,
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
