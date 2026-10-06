import 'package:flutter/material.dart';

/// Ganzzahliges Gefechtsfeld mit −/+ für häufige kleine Änderungen.
///
/// Das Textfeld bleibt die Quelle der Wahrheit, damit Tastatureingabe,
/// Fokus und bestehende Formularprüfungen unverändert funktionieren. Die
/// Knöpfe ändern den Wert ausschließlich um ±1 und melden die Änderung wie
/// eine Eingabe. Ungültiger Text wird von den Knöpfen wie 0 behandelt.
class GefechtZahlfeld extends StatelessWidget {
  /// [feldKey] bleibt am Textfeld, damit Tests und Fokus es wiederfinden.
  const GefechtZahlfeld({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.feldKey,
    this.minimum,
    this.hilfe,
  });

  /// Gemeinsamer Controller des Formulars.
  final TextEditingController controller;

  /// Sichtbare Beschriftung des Feldes.
  final String label;

  /// Wird nach jeder Eingabe oder Knopfänderung aufgerufen.
  final VoidCallback onChanged;

  /// Optionaler Schlüssel des eigentlichen Textfelds.
  final Key? feldKey;

  /// Untere Grenze der Knöpfe; die Regelprüfung bleibt davon unberührt.
  final int? minimum;

  /// Kurzer Hilfetext unter dem Feld.
  final String? hilfe;

  // Ändert den sichtbaren Text, ohne eine eigene Regel anzuwenden.
  void _schritt(int delta) {
    final aktuell = int.tryParse(controller.text.trim()) ?? 0;
    var neu = aktuell + delta;
    final grenze = minimum;
    if (grenze != null && neu < grenze) neu = grenze;
    controller.value = TextEditingValue(
      text: '$neu',
      selection: TextSelection.collapsed(offset: '$neu'.length),
    );
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final wert = int.tryParse(controller.text.trim());
    final grenze = minimum;
    final kleiner = grenze == null || wert == null || wert > grenze;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              key: feldKey,
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(labelText: label, helperText: hilfe),
              onChanged: (_) => onChanged(),
            ),
          ),
          IconButton(
            tooltip: '$label verringern',
            onPressed: kleiner ? () => _schritt(-1) : null,
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            tooltip: '$label erhöhen',
            onPressed: () => _schritt(1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
