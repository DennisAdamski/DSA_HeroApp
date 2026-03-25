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
    final isEditing = readOnly == true ? false : (readOnly ?? _editController.isEditing);
    final fieldKey = ValueKey<String>('overview-field-$keyName');
    if (!isEditing) {
      return KeyedSubtree(
        key: fieldKey,
        child: EditAwareField(
          label: label,
          isEditing: false,
          controller: _field(keyName),
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
        ),
      );
    }
    return TextField(
      key: fieldKey,
      controller: _field(keyName),
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label),
      onChanged: _onFieldChanged,
    );
  }

  Widget _buildReadOnlyValueField({
    required String label,
    required String value,
    Key? key,
  }) {
    return EditAwareField(
      key: key,
      label: label,
      value: value,
      isEditing: false,
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
