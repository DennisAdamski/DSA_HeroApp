import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Ein zur Auswahl stehender Zauber mit belegtem Profil.
class SpellEffectAuswahl {
  /// Erstellt einen Auswahleintrag.
  const SpellEffectAuswahl({
    required this.zauberId,
    required this.name,
    required this.benoetigtZfw,
    required this.hinweis,
  });

  /// Katalog-ID des Zaubers.
  final String zauberId;

  /// Anzeigename.
  final String name;

  /// Ob das Profil das ZfW des Zaubernden braucht.
  final bool benoetigtZfw;

  /// Kurzer Hinweis zur Wirkung, aus dem Profil.
  final String hinweis;
}

/// Bestätigte Eingaben für eine neue Wirkungsquelle.
class SpellEffectEingabe {
  /// Erstellt die Eingabe.
  const SpellEffectEingabe({
    required this.zauberId,
    required this.zfpStern,
    this.zfw,
    this.quelle,
  });

  /// Gewählter Zauber.
  final String zauberId;

  /// ZfP* der Probe des Zaubernden.
  final int zfpStern;

  /// ZfW des Zaubernden, falls das Profil es braucht und angegeben wurde.
  final int? zfw;

  /// Freitext zum Ursprung (z. B. Name des Zaubernden), oder `null`.
  final String? quelle;
}

/// Öffnet den Eingabedialog für eine Zauberwirkung auf den Helden.
///
/// Zahlen sind Werte des **ursprünglich Zaubernden** (bei fremden Zaubern also
/// nicht die des Helden). `null`, wenn der Nutzer abbricht.
Future<SpellEffectEingabe?> showSpellEffectInputDialog({
  required BuildContext context,
  required List<SpellEffectAuswahl> auswahl,
}) {
  return showAdaptiveInputDialog<SpellEffectEingabe>(
    context: context,
    builder: (_) => _SpellEffectInputDialog(auswahl: auswahl),
  );
}

class _SpellEffectInputDialog extends StatefulWidget {
  const _SpellEffectInputDialog({required this.auswahl});

  final List<SpellEffectAuswahl> auswahl;

  @override
  State<_SpellEffectInputDialog> createState() =>
      _SpellEffectInputDialogState();
}

class _SpellEffectInputDialogState extends State<_SpellEffectInputDialog> {
  final _zfp = TextEditingController();
  final _zfw = TextEditingController();
  final _quelle = TextEditingController();
  late SpellEffectAuswahl _gewaehlt = widget.auswahl.first;

  @override
  void dispose() {
    _zfp.dispose();
    _zfw.dispose();
    _quelle.dispose();
    super.dispose();
  }

  int? get _zfpWert => int.tryParse(_zfp.text.trim());
  int? get _zfwWert => int.tryParse(_zfw.text.trim());

  bool get _gueltig =>
      _zfpWert != null &&
      _zfpWert! >= 0 &&
      (!_gewaehlt.benoetigtZfw || (_zfwWert != null && _zfwWert! >= 0));

  void _bestaetigen() {
    final quelle = _quelle.text.trim();
    Navigator.of(context).pop(
      SpellEffectEingabe(
        zauberId: _gewaehlt.zauberId,
        zfpStern: _zfpWert!,
        zfw: _gewaehlt.benoetigtZfw ? _zfwWert : null,
        quelle: quelle.isEmpty ? null : quelle,
      ),
    );
  }

  Widget _zahlfeld(Key key, TextEditingController controller, String label) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        labelText: label,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveInputDialog(
      title: 'Zauberwirkung hinzufügen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trage die Werte des Zaubernden ein, nicht die des Helden. '
            'Die App rechnet daraus nur, was das Regelwerk belegt.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kDialogSectionSpacing),
          DropdownButtonFormField<SpellEffectAuswahl>(
            key: const ValueKey<String>('spell-effect-input-zauber'),
            initialValue: _gewaehlt,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: 'Zauber',
            ),
            items: [
              for (final eintrag in widget.auswahl)
                DropdownMenuItem(value: eintrag, child: Text(eintrag.name)),
            ],
            onChanged: (wert) {
              if (wert != null) {
                setState(() => _gewaehlt = wert);
              }
            },
          ),
          const SizedBox(height: kDialogInlineSpacing),
          Text(_gewaehlt.hinweis, style: theme.textTheme.bodySmall),
          const SizedBox(height: kDialogFieldSpacing),
          _zahlfeld(
            const ValueKey<String>('spell-effect-input-zfp'),
            _zfp,
            'ZfP* des Zaubernden',
          ),
          if (_gewaehlt.benoetigtZfw) ...[
            const SizedBox(height: kDialogFieldSpacing),
            _zahlfeld(
              const ValueKey<String>('spell-effect-input-zfw'),
              _zfw,
              'ZfW des Zaubernden',
            ),
          ],
          const SizedBox(height: kDialogFieldSpacing),
          TextField(
            key: const ValueKey<String>('spell-effect-input-quelle'),
            controller: _quelle,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: 'Quelle (optional, z. B. Name des Zaubernden)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('spell-effect-input-confirm'),
          onPressed: _gueltig ? _bestaetigen : null,
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
