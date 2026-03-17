import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// EditAwareField -- Textfeld mit View/Edit-Modus-Umschaltung
// ---------------------------------------------------------------------------

/// Anzeige-/Eingabefeld, das im View-Modus Plain Text rendert und im
/// Edit-Modus ein [TextFormField] mit [OutlineInputBorder] anzeigt.
///
/// Unterstuetzt sowohl `initialValue`- als auch `controller`-Variante.
/// Bei `controller != null` wird `initialValue` ignoriert.
class EditAwareField extends StatelessWidget {
  const EditAwareField({
    super.key,
    required this.label,
    this.value,
    required this.isEditing,
    this.onChanged,
    this.controller,
    this.maxLines,
    this.minLines,
    this.keyboardType,
    this.inputFormatters,
    this.emptyPlaceholder = '–',
  });

  final String label;

  /// Aktueller Wert -- wird im View-Modus und als `initialValue` genutzt.
  /// Kann null sein, wenn [controller] gesetzt ist.
  final String? value;

  final bool isEditing;
  final ValueChanged<String>? onChanged;

  /// Optionaler Controller -- hat Vorrang vor [value] im Edit-Modus.
  final TextEditingController? controller;

  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Platzhaltertext fuer leere Werte im View-Modus.
  final String emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      final displayValue = controller?.text ?? value ?? '';
      return _StaticLabeledValue(
        label: label,
        value: displayValue,
        emptyPlaceholder: emptyPlaceholder,
      );
    }
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? (value ?? '') : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// EditAwareIntField -- Ganzzahlfeld mit View/Edit-Modus-Umschaltung
// ---------------------------------------------------------------------------

/// Variante von [EditAwareField] fuer Ganzzahlwerte mit optionalem
/// Suffix-Icon (z.B. Steigerungs-Button).
class EditAwareIntField extends StatelessWidget {
  const EditAwareIntField({
    super.key,
    required this.label,
    this.value,
    required this.isEditing,
    this.onChanged,
    this.controller,
    this.suffixIcon,
    this.suffixIconConstraints,
    this.emptyPlaceholder = '–',
  });

  final String label;
  final int? value;
  final bool isEditing;
  final ValueChanged<int?>? onChanged;
  final TextEditingController? controller;
  final Widget? suffixIcon;
  final BoxConstraints? suffixIconConstraints;
  final String emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      final displayValue = controller?.text ?? (value != null ? '$value' : '');
      return _StaticLabeledValue(
        label: label,
        value: displayValue,
        emptyPlaceholder: emptyPlaceholder,
      );
    }
    return TextFormField(
      controller: controller,
      initialValue: controller == null
          ? (value != null ? '$value' : '')
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: suffixIcon,
        suffixIconConstraints: suffixIconConstraints,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
      onChanged: onChanged == null
          ? null
          : (raw) => onChanged!(int.tryParse(raw.trim())),
    );
  }
}

// ---------------------------------------------------------------------------
// Gemeinsamer View-Modus-Baustein
// ---------------------------------------------------------------------------

/// Statische Label+Value-Darstellung ohne Border.
class _StaticLabeledValue extends StatelessWidget {
  const _StaticLabeledValue({
    required this.label,
    required this.value,
    required this.emptyPlaceholder,
  });

  final String label;
  final String value;
  final String emptyPlaceholder;

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
        const SizedBox(height: 2),
        Text(value.isEmpty ? emptyPlaceholder : value),
      ],
    );
  }
}
