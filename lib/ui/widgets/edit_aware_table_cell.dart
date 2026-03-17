import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tabellenzelle, die im View-Modus Plain Text rendert und im Edit-Modus
/// ein [TextField] mit [OutlineInputBorder] anzeigt.
///
/// Ersetzt das bisherige `TextField(readOnly: !isEditing)` Pattern, bei dem
/// auch im View-Modus ein Border sichtbar war.
class EditAwareTableCell extends StatelessWidget {
  const EditAwareTableCell({
    super.key,
    required this.value,
    required this.isEditing,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.isError = false,
    this.suffixIcon,
    this.suffixIconConstraints,
    this.textStyle,
    this.padding = const EdgeInsets.fromLTRB(4, 4, 4, 4),
  });

  /// Anzeigewert -- wird im View-Modus als Text und im Edit-Modus als
  /// Fallback fuer den Controller genutzt.
  final String value;

  final bool isEditing;

  /// Optionaler Controller -- hat Vorrang vor [value] im Edit-Modus.
  final TextEditingController? controller;

  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  /// Zeigt einen roten Border bei Validierungsfehlern.
  final bool isError;

  /// Optionales Suffix-Icon (z.B. Steigerungs-Button).
  final Widget? suffixIcon;
  final BoxConstraints? suffixIconConstraints;

  /// Optionaler Text-Style fuer den View-Modus.
  final TextStyle? textStyle;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      return Padding(
        padding: padding,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(value, style: textStyle),
        ),
      );
    }

    final theme = Theme.of(context).colorScheme;
    final borderColor = isError ? theme.error : theme.outline;
    return Padding(
      padding: padding,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: isError ? theme.error : theme.primary,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          suffixIcon: suffixIcon,
          suffixIconConstraints: suffixIconConstraints,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
