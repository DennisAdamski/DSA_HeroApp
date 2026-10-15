import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';
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
    this.benoetigtZiel = false,
    this.benoetigtSchutzvorrat = false,
    this.benoetigtDauerAsp = false,
  });

  /// Ob die Dauer mit AsP über die Grundkosten hinaus vorausbezahlt wird
  /// (Psychostabilis).
  final bool benoetigtDauerAsp;

  /// Ob die Wirkung an ein festgelegtes Ziel gebunden ist (Falkenauge).
  final bool benoetigtZiel;

  /// Ob die Wirkung einen Schutzvorrat aus AsP und ZfP* bildet (Gardianum).
  final bool benoetigtSchutzvorrat;

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
    this.ziel,
    this.kapazitaet,
    this.dauerAsp,
  });

  /// Über die Grundkosten hinaus eingesetzte AsP, die die Dauer festlegen
  /// (Psychostabilis: 1 AsP je Spielrunde), falls angegeben.
  final int? dauerAsp;

  /// Anfangsvorrat eines Schutzschilds in TP, falls das Profil einen bildet.
  final int? kapazitaet;

  /// Ziel der Wirkung (Name des Gegners), falls das Profil eines verlangt.
  final String? ziel;

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
///
/// [gegnerNamen] sind die Namen der lokalen Gegner der Begegnung; sie dienen
/// als Auswahlhilfe für das Ziel, ein freier Name bleibt möglich.
Future<SpellEffectEingabe?> showSpellEffectInputDialog({
  required BuildContext context,
  required List<SpellEffectAuswahl> auswahl,
  List<String> gegnerNamen = const <String>[],
}) {
  return showAdaptiveInputDialog<SpellEffectEingabe>(
    context: context,
    builder: (_) =>
        _SpellEffectInputDialog(auswahl: auswahl, gegnerNamen: gegnerNamen),
  );
}

class _SpellEffectInputDialog extends StatefulWidget {
  const _SpellEffectInputDialog({
    required this.auswahl,
    required this.gegnerNamen,
  });

  final List<SpellEffectAuswahl> auswahl;
  final List<String> gegnerNamen;

  @override
  State<_SpellEffectInputDialog> createState() =>
      _SpellEffectInputDialogState();
}

class _SpellEffectInputDialogState extends State<_SpellEffectInputDialog> {
  final _zfp = TextEditingController();
  final _zfw = TextEditingController();
  final _quelle = TextEditingController();
  final _ziel = TextEditingController();
  final _asp = TextEditingController();
  final _dauerAsp = TextEditingController();
  Schutzvariante _variante = Schutzvariante.kuppel;
  late SpellEffectAuswahl _gewaehlt = widget.auswahl.first;

  @override
  void dispose() {
    _zfp.dispose();
    _zfw.dispose();
    _quelle.dispose();
    _ziel.dispose();
    _asp.dispose();
    _dauerAsp.dispose();
    super.dispose();
  }

  int? get _zfpWert => int.tryParse(_zfp.text.trim());
  int? get _zfwWert => int.tryParse(_zfw.text.trim());

  int? get _aspWert => int.tryParse(_asp.text.trim());

  int? get _dauerAspWert => int.tryParse(_dauerAsp.text.trim());

  /// Anfangsvorrat des Schilds aus den Eingaben; `null`, solange er nicht
  /// belegt ist. Gerechnet wird im Regelmodul.
  int? get _kapazitaet {
    final zfp = _zfpWert;
    final asp = _aspWert;
    if (!_gewaehlt.benoetigtSchutzvorrat || zfp == null || asp == null) {
      return null;
    }
    return gardianumKapazitaet(
      variante: _variante,
      zfpStern: zfp,
      investierteAsp: asp,
    );
  }

  bool get _gueltig =>
      _zfpWert != null &&
      _zfpWert! >= 0 &&
      (!_gewaehlt.benoetigtSchutzvorrat || _kapazitaet != null) &&
      (!_gewaehlt.benoetigtZfw || (_zfwWert != null && _zfwWert! >= 0)) &&
      (!_gewaehlt.benoetigtZiel || _ziel.text.trim().isNotEmpty);

  void _bestaetigen() {
    final quelle = _quelle.text.trim();
    Navigator.of(context).pop(
      SpellEffectEingabe(
        zauberId: _gewaehlt.zauberId,
        zfpStern: _zfpWert!,
        zfw: _gewaehlt.benoetigtZfw ? _zfwWert : null,
        quelle: quelle.isEmpty ? null : quelle,
        ziel: _gewaehlt.benoetigtZiel ? _ziel.text.trim() : null,
        kapazitaet: _gewaehlt.benoetigtSchutzvorrat ? _kapazitaet : null,
        dauerAsp: _gewaehlt.benoetigtDauerAsp ? _dauerAspWert : null,
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

  /// Eingaben eines Schutzvorrats: Ausprägung und eingesetzte AsP.
  List<Widget> _schutzFelder(ThemeData theme) {
    final kapazitaet = _kapazitaet;
    final hinweis = schutzvarianteHinweis(_variante, _zfwWert);
    return [
      const SizedBox(height: kDialogFieldSpacing),
      SegmentedButton<Schutzvariante>(
        key: const ValueKey<String>('spell-effect-input-variante'),
        segments: const [
          ButtonSegment<Schutzvariante>(
            value: Schutzvariante.kuppel,
            label: Text('Kuppel'),
          ),
          ButtonSegment<Schutzvariante>(
            value: Schutzvariante.persoenlich,
            label: Text('Persönlicher Schild'),
          ),
        ],
        selected: <Schutzvariante>{_variante},
        onSelectionChanged: (auswahl) =>
            setState(() => _variante = auswahl.single),
      ),
      const SizedBox(height: kDialogFieldSpacing),
      _zahlfeld(
        const ValueKey<String>('spell-effect-input-asp'),
        _asp,
        'Eingesetzte AsP (mindestens $kGardianumMindestAsp)',
      ),
      const SizedBox(height: kDialogInlineSpacing),
      Text(
        kapazitaet == null
            ? 'Schutzvorrat: ZfP* und mindestens $kGardianumMindestAsp AsP '
                  'eintragen'
            : 'Schutzvorrat: $kapazitaet TP',
        key: const ValueKey<String>('spell-effect-input-kapazitaet'),
        style: theme.textTheme.bodySmall,
      ),
      if (hinweis != null)
        Text(
          hinweis,
          key: const ValueKey<String>('spell-effect-input-varianten-hinweis'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
    ];
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
          if (_gewaehlt.benoetigtSchutzvorrat) ..._schutzFelder(theme),
          if (_gewaehlt.benoetigtDauerAsp) ...[
            const SizedBox(height: kDialogFieldSpacing),
            _zahlfeld(
              const ValueKey<String>('spell-effect-input-dauer-asp'),
              _dauerAsp,
              'Über die Grundkosten hinaus eingesetzte AsP (optional)',
            ),
            const SizedBox(height: kDialogInlineSpacing),
            Text(
              'Die Dauer ist vorausbezahlt: 1 AsP entspricht 1 Spielrunde. '
              'Die AsP werden hier nicht abgezogen.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (_gewaehlt.benoetigtZiel) ...[
            const SizedBox(height: kDialogFieldSpacing),
            TextField(
              key: const ValueKey<String>('spell-effect-input-ziel'),
              controller: _ziel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                labelText: 'Ziel (Name des Gegners)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.gegnerNamen.isNotEmpty)
              Wrap(
                spacing: kDialogInlineSpacing,
                children: [
                  for (final name in widget.gegnerNamen)
                    ActionChip(
                      label: Text(name),
                      onPressed: () => setState(() => _ziel.text = name),
                    ),
                ],
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
