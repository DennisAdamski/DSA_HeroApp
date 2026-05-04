import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';

/// Direkt speicherndes Geldfeld fuer den Inventar-Tab.
///
/// Das Feld bleibt als Freitext editierbar, bietet aber zusätzliche
/// Münzschritte für Dukaten, Silber und Kreuzer.
class DukatenField extends StatefulWidget {
  /// Erstellt ein Geldfeld mit aktuellem Wert und Speicher-Callback.
  const DukatenField({super.key, required this.value, required this.onCommit});

  /// Aktuell gespeicherter Geldwert des Helden.
  final String value;

  /// Speichert einen normalisierten oder manuell eingegebenen Geldwert.
  final Future<void> Function(String value) onCommit;

  @override
  State<DukatenField> createState() => _DukatenFieldState();
}

class _DukatenFieldState extends State<DukatenField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value)
      ..addListener(_handleTextChange);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant DukatenField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitIfChanged();
    }
  }

  Future<void> _commitIfChanged() async {
    final nextValue = _controller.text.trim();
    if (nextValue == widget.value.trim()) {
      return;
    }
    await widget.onCommit(nextValue);
  }

  Future<void> _adjustBy(int deltaKreuzer) async {
    final adjusted = adjustDsaCurrencyText(
      rawValue: _controller.text,
      deltaKreuzer: deltaKreuzer,
    );
    if (adjusted == null) {
      _showInvalidMoneySnackBar();
      return;
    }

    _controller.text = adjusted;
    _controller.selection = TextSelection.collapsed(offset: adjusted.length);
    await _commitIfChanged();
  }

  void _showInvalidMoneySnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Der Dukatenwert ist nicht numerisch lesbar.'),
      ),
    );
  }

  String _breakdownLabel() {
    final parsed = parseDsaCurrencyToKreuzer(_controller.text);
    if (parsed == null) {
      return 'Nicht lesbar';
    }
    return formatDsaCurrencyBreakdown(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final breakdownStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: const InputDecoration(
              labelText: 'Dukaten',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _commitIfChanged(),
            onTapOutside: (_) {
              _commitIfChanged();
              _focusNode.unfocus();
            },
          ),
        ),
        _CoinStepper(
          label: 'D',
          decrementKey: const ValueKey<String>(
            'inventory-dukaten-decrement-dukaten',
          ),
          incrementKey: const ValueKey<String>(
            'inventory-dukaten-increment-dukaten',
          ),
          decrementTooltip: '1 Dukat abziehen',
          incrementTooltip: '1 Dukat hinzufügen',
          onDecrement: () => _adjustBy(-dsaKreuzerPerDukat),
          onIncrement: () => _adjustBy(dsaKreuzerPerDukat),
        ),
        _CoinStepper(
          label: 'S',
          decrementKey: const ValueKey<String>(
            'inventory-dukaten-decrement-silber',
          ),
          incrementKey: const ValueKey<String>(
            'inventory-dukaten-increment-silber',
          ),
          decrementTooltip: '1 Silbertaler abziehen',
          incrementTooltip: '1 Silbertaler hinzufügen',
          onDecrement: () => _adjustBy(-dsaKreuzerPerSilber),
          onIncrement: () => _adjustBy(dsaKreuzerPerSilber),
        ),
        _CoinStepper(
          label: 'K',
          decrementKey: const ValueKey<String>(
            'inventory-dukaten-decrement-kreuzer',
          ),
          incrementKey: const ValueKey<String>(
            'inventory-dukaten-increment-kreuzer',
          ),
          decrementTooltip: '1 Kreuzer abziehen',
          incrementTooltip: '1 Kreuzer hinzufügen',
          onDecrement: () => _adjustBy(-1),
          onIncrement: () => _adjustBy(1),
        ),
        SizedBox(
          width: 120,
          child: Text(
            _breakdownLabel(),
            overflow: TextOverflow.ellipsis,
            style: breakdownStyle,
          ),
        ),
      ],
    );
  }
}

class _CoinStepper extends StatelessWidget {
  const _CoinStepper({
    required this.label,
    required this.decrementKey,
    required this.incrementKey,
    required this.decrementTooltip,
    required this.incrementTooltip,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final Key decrementKey;
  final Key incrementKey;
  final String decrementTooltip;
  final String incrementTooltip;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: decrementKey,
              tooltip: decrementTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onDecrement,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 24,
              child: Center(child: Text(label, style: labelStyle)),
            ),
            IconButton(
              key: incrementKey,
              tooltip: incrementTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onIncrement,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
