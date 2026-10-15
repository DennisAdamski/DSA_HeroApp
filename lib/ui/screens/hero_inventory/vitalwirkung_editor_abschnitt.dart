import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';

/// Editorabschnitt „Wirkung auf Vitalwerte“ für Verbrauchsgegenstände.
///
/// Hält nur die Vorbelegung für den Anwendungsdialog (Heiltrank, Verband …);
/// gewürfelte Wirkungen trägt der Nutzer beim Anwenden ein. Sind alle Felder
/// leer, meldet der Abschnitt `null`, damit nichts ins JSON geschrieben wird.
/// Felder einer neueren App-Version bleiben über `copyWith` erhalten.
class VitalwirkungEditorAbschnitt extends StatefulWidget {
  /// Erstellt den Abschnitt.
  const VitalwirkungEditorAbschnitt({
    super.key,
    required this.wirkung,
    required this.onChanged,
  });

  /// Aktuelle Vorbelegung des Entwurfs.
  final Vitalwirkung? wirkung;

  /// Meldet die neue Vorbelegung oder `null`, wenn nichts belegt ist.
  final ValueChanged<Vitalwirkung?> onChanged;

  @override
  State<VitalwirkungEditorAbschnitt> createState() =>
      _VitalwirkungEditorAbschnittState();
}

class _VitalwirkungEditorAbschnittState
    extends State<VitalwirkungEditorAbschnitt> {
  late final TextEditingController _lep = _controller(widget.wirkung?.lep);
  late final TextEditingController _asp = _controller(widget.wirkung?.asp);
  late final TextEditingController _aup = _controller(widget.wirkung?.aup);
  late final TextEditingController _wunden = _controller(
    widget.wirkung?.wunden,
  );

  static TextEditingController _controller(int? wert) =>
      TextEditingController(text: wert == null || wert == 0 ? '' : '$wert');

  @override
  void dispose() {
    _lep.dispose();
    _asp.dispose();
    _aup.dispose();
    _wunden.dispose();
    super.dispose();
  }

  void _melde() {
    int zahl(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    final neu = (widget.wirkung ?? const Vitalwirkung()).copyWith(
      lep: zahl(_lep),
      asp: zahl(_asp),
      aup: zahl(_aup),
      wunden: zahl(_wunden),
    );
    // Unbekannte Felder einer neueren Version halten die Wirkung am Leben.
    final leer = !neu.istBelegt && neu.unbekannteFelder.isEmpty;
    widget.onChanged(leer ? null : neu);
  }

  Widget _feld(String schluessel, TextEditingController c, String label) {
    return Expanded(
      child: TextField(
        key: ValueKey<String>(schluessel),
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _melde(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Wirkung auf Vitalwerte', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Vorschlag für „Anwenden“, etwa bei einem Heiltrank. Beim Anwenden '
          'lässt sich alles ändern; gewürfelte Werte trägst du dort ein.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _feld('inventory-editor-vital-lep', _lep, 'LeP'),
            const SizedBox(width: 8),
            _feld('inventory-editor-vital-asp', _asp, 'AsP'),
            const SizedBox(width: 8),
            _feld('inventory-editor-vital-aup', _aup, 'AuP'),
            const SizedBox(width: 8),
            _feld('inventory-editor-vital-wunden', _wunden, 'Wunden'),
          ],
        ),
      ],
    );
  }
}
