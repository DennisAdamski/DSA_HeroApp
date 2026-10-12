import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_herkunft_bearbeitung_rules.dart';

/// Fragt einen Herkunftsmodifikator ab (Ziel und Betrag oder freier Text).
///
/// Mit [bisher] wird ein vorhandener Eintrag bearbeitet: ID und unbekannte
/// Felder bleiben erhalten. Ein neuer Eintrag bekommt seine ID (UUID v4) erst
/// bei der Bestätigung; ein Abbruch liefert `null` und ändert nichts. Ziel,
/// Betrag und Text prüfen die Regelhelfer aus
/// `hero_herkunft_bearbeitung_rules.dart`; der Dialog rechnet nichts selbst.
/// Er schließt sich selbst.
Future<HeroHerkunftsModifikator?> zeigeHerkunftsEintragDialog({
  required BuildContext context,
  required String herkunftName,
  HeroHerkunftsModifikator? bisher,
}) {
  return showDialog<HeroHerkunftsModifikator>(
    context: context,
    builder: (dialogContext) =>
        _HerkunftsEintragDialog(herkunftName: herkunftName, bisher: bisher),
  );
}

enum _Modus { eigenschaft, basiswert, frei }

class _HerkunftsEintragDialog extends StatefulWidget {
  const _HerkunftsEintragDialog({
    required this.herkunftName,
    required this.bisher,
  });

  final String herkunftName;
  final HeroHerkunftsModifikator? bisher;

  @override
  State<_HerkunftsEintragDialog> createState() =>
      _HerkunftsEintragDialogState();
}

class _HerkunftsEintragDialogState extends State<_HerkunftsEintragDialog> {
  late _Modus _modus;
  String? _ziel;
  late final TextEditingController _betrag;
  late final TextEditingController _text;
  String? _fehler;

  @override
  void initState() {
    super.initState();
    final bisher = widget.bisher;
    _modus = _Modus.eigenschaft;
    var betrag = '1';
    var text = '';
    if (bisher != null) {
      switch (bisher.art) {
        case HeroHerkunftsModifikatorArt.eigenschaft
            when herkunftEigenschaftsZiele.contains(bisher.ziel):
          _modus = _Modus.eigenschaft;
          _ziel = bisher.ziel;
          betrag = '${bisher.betrag ?? 0}';
        case HeroHerkunftsModifikatorArt.basiswert
            when herkunftBasiswertZiele.contains(bisher.ziel):
          _modus = _Modus.basiswert;
          _ziel = bisher.ziel;
          betrag = '${bisher.betrag ?? 0}';
        default:
          _modus = _Modus.frei;
          text = bisher.text;
      }
    }
    _betrag = TextEditingController(text: betrag);
    _text = TextEditingController(text: text);
  }

  @override
  void dispose() {
    _betrag.dispose();
    _text.dispose();
    super.dispose();
  }

  List<String> get _ziele => _modus == _Modus.basiswert
      ? herkunftBasiswertZiele
      : herkunftEigenschaftsZiele;

  void _uebernehmen() {
    final bisher = widget.bisher;
    final HeroHerkunftsModifikator? eintrag;
    if (_modus == _Modus.frei) {
      eintrag = baueFreienHerkunftsEintrag(
        text: _text.text,
        id: const Uuid().v4(),
        bisher: bisher,
      );
      if (eintrag == null) {
        setState(
          () => _fehler =
              'Bitte genau einen Modifikator eintragen, ohne Komma, '
              'Semikolon oder Zeilenumbruch.',
        );
        return;
      }
    } else {
      final betrag = int.tryParse(_betrag.text.trim().replaceAll('+', ''));
      final ziel = _ziel;
      if (ziel == null || betrag == null) {
        setState(
          () => _fehler =
              'Bitte ein Ziel wählen und einen ganzzahligen '
              'Betrag eintragen.',
        );
        return;
      }
      eintrag = baueDirektenHerkunftsEintrag(
        ziel: ziel,
        betrag: betrag,
        id: const Uuid().v4(),
        bisher: bisher,
      );
      if (eintrag == null) {
        setState(() => _fehler = 'Dieses Ziel wird nicht unterstützt.');
        return;
      }
    }
    Navigator.of(context).pop(eintrag);
  }

  @override
  Widget build(BuildContext context) {
    final istNeu = widget.bisher == null;
    return AlertDialog(
      title: Text(
        istNeu
            ? '${widget.herkunftName}: Modifikator hinzufügen'
            : '${widget.herkunftName}: Modifikator ändern',
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                key: const ValueKey<String>('herkunft-dialog-modus'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (modus, text) in const <(_Modus, String)>[
                    (_Modus.eigenschaft, 'Eigenschaft'),
                    (_Modus.basiswert, 'Basiswert'),
                    (_Modus.frei, 'Freier Text'),
                  ])
                    ChoiceChip(
                      key: ValueKey<String>(
                        'herkunft-dialog-modus-${modus.name}',
                      ),
                      label: Text(text),
                      selected: _modus == modus,
                      onSelected: (_) => setState(() {
                        _modus = modus;
                        _ziel = null;
                        _fehler = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (_modus == _Modus.frei)
                TextField(
                  key: const ValueKey<String>('herkunft-dialog-text'),
                  controller: _text,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Modifikator',
                    helperText: 'z. B. MU+1 oder ein eigener Hinweis',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _fehler = null),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey<String>('herkunft-dialog-ziel-${_modus.name}'),
                  initialValue: _ziel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ziel',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final ziel in _ziele)
                      DropdownMenuItem(value: ziel, child: Text(ziel)),
                  ],
                  onChanged: (wert) => setState(() {
                    _ziel = wert;
                    _fehler = null;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('herkunft-dialog-betrag'),
                  controller: _betrag,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-+0-9]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Betrag',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _fehler = null),
                ),
              ],
              if (_fehler != null) ...[
                const SizedBox(height: 8),
                Text(
                  _fehler!,
                  key: const ValueKey<String>('herkunft-dialog-fehler'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('herkunft-dialog-abbrechen'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('herkunft-dialog-uebernehmen'),
          onPressed: _uebernehmen,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
