import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_verkauf_rules.dart';

/// Wahl im Dialog „Verkaufen“.
class InventarVerkauf {
  /// [anzahl] Stück für [erloesKreuzer] Kreuzer.
  const InventarVerkauf({required this.anzahl, required this.erloesKreuzer});

  /// Verkaufte Stückzahl.
  final int anzahl;

  /// Erlös in Kreuzern; kommt auf den Geldstand.
  final int erloesKreuzer;
}

/// Fragt, wie viele Stück von [eintrag] für welchen Erlös verkauft werden
/// (ARCH-03). Der Erlös ist mit dem vollen Wert vorbelegt und folgt der
/// Anzahl, bis man ihn selbst ändert. Liefert `null` bei Abbruch.
Future<InventarVerkauf?> zeigeVerkaufenDialog(
  BuildContext context,
  HeroInventoryEntry eintrag,
) {
  return showDialog<InventarVerkauf>(
    context: context,
    builder: (_) => _VerkaufenDialog(eintrag: eintrag),
  );
}

class _VerkaufenDialog extends StatefulWidget {
  const _VerkaufenDialog({required this.eintrag});

  final HeroInventoryEntry eintrag;

  @override
  State<_VerkaufenDialog> createState() => _VerkaufenDialogState();
}

class _VerkaufenDialogState extends State<_VerkaufenDialog> {
  late final int _hoechstens = verkaufbareStueckzahl(widget.eintrag);
  late int _anzahl = _hoechstens;
  late final TextEditingController _erloes = TextEditingController(
    text: _vorschlag(_anzahl),
  );
  // Ob der Nutzer den Erlös selbst geändert hat; dann folgt er der Anzahl
  // nicht mehr.
  bool _erloesGeaendert = false;
  String? _fehler;

  @override
  void dispose() {
    _erloes.dispose();
    super.dispose();
  }

  String _vorschlag(int anzahl) {
    final kreuzer = verkaufsvorschlagKreuzer(widget.eintrag, anzahl);
    return formatDsaCurrencyDukaten(kreuzer);
  }

  void _setze(int wert) {
    setState(() {
      _anzahl = wert.clamp(1, _hoechstens);
      if (!_erloesGeaendert) {
        _erloes.text = _vorschlag(_anzahl);
      }
    });
  }

  void _bestaetige() {
    final kreuzer = parseDsaCurrencyToKreuzer(_erloes.text);
    if (kreuzer == null || kreuzer < 0) {
      setState(() => _fehler = 'Bitte einen Betrag wie „12,5“ oder „3 D 5 S“.');
      return;
    }
    Navigator.of(context)
        .pop(InventarVerkauf(anzahl: _anzahl, erloesKreuzer: kreuzer));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eintrag = widget.eintrag;
    final hinweis = verkaufEntferntAusKampf(eintrag)
        ? 'Der Gegenstand wird auch aus dem Kampfbereich entfernt.'
        : eintrag.sourceRef != null &&
              eintrag.source == InventoryItemSource.geschoss
        ? 'Der Bestand an der Waffe sinkt entsprechend.'
        : null;
    return AlertDialog(
      title: const Text('Verkaufen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _hoechstens > 1
                ? '${eintrag.gegenstand}: $_hoechstens Stück'
                : eintrag.gegenstand,
          ),
          if (_hoechstens > 1)
            Row(
              children: [
                const Expanded(child: Text('Verkaufen')),
                IconButton(
                  key: const ValueKey<String>('verkaufen-minus'),
                  tooltip: 'Ein Stück weniger',
                  onPressed: _anzahl > 1 ? () => _setze(_anzahl - 1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '$_anzahl',
                  key: const ValueKey<String>('verkaufen-anzahl'),
                  style: theme.textTheme.titleMedium,
                ),
                IconButton(
                  key: const ValueKey<String>('verkaufen-plus'),
                  tooltip: 'Ein Stück mehr',
                  onPressed: _anzahl < _hoechstens
                      ? () => _setze(_anzahl + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('verkaufen-erloes'),
            controller: _erloes,
            onChanged: (_) => _erloesGeaendert = true,
            decoration: InputDecoration(
              labelText: 'Erlös (Dukaten)',
              helperText: 'Vorbelegt mit dem vollen Wert',
              errorText: _fehler,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (hinweis != null) ...[
            const SizedBox(height: 8),
            Text(hinweis, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          Text(
            'Ungespeicherte Änderungen im Editor gehen dabei verloren.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('verkaufen-ok'),
          onPressed: _bestaetige,
          child: const Text('Verkaufen'),
        ),
      ],
    );
  }
}
