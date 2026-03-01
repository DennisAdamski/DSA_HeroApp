part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewFormFieldsSection on _HeroOverviewTabState {
  Widget _buildInputField({
    required String label,
    required String keyName,
    int? minLines,
    int? maxLines = 1,
    TextInputType? keyboardType,
    bool? readOnly,
  }) {
    if (readOnly == true) {
      return _buildLabeledStaticValueField(
        key: ValueKey<String>('overview-field-$keyName'),
        label: label,
        value: _field(keyName).text,
      );
    }

    final isReadOnly = readOnly ?? !_editController.isEditing;
    return TextField(
      key: ValueKey<String>('overview-field-$keyName'),
      controller: _field(keyName),
      readOnly: isReadOnly,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
      onChanged: isReadOnly ? null : _onFieldChanged,
    );
  }

  Widget _buildReadOnlyValueField({
    required String label,
    required String value,
    Key? key,
  }) {
    return _buildLabeledStaticValueField(key: key, label: label, value: value);
  }

  Widget _buildLabeledStaticValueField({
    required String label,
    required String value,
    Key? key,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }
}
