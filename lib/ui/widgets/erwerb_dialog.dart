import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Ergebnis eines bestaetigten Erwerbsdialogs.
class ErwerbErgebnis {
  /// Erzeugt ein unveraenderliches Dialogergebnis.
  const ErwerbErgebnis({
    required this.apKosten,
    required this.mitLehrmeister,
    required this.lehrmeisterTaW,
    required this.dukaten,
  });

  /// Effektive AP-Kosten, inklusive Epos-Aufschlag und moeglichem
  /// Lehrmeister-Rabatt.
  final int apKosten;

  /// Ob der Erwerb mit einem Lehrmeister erfolgt ist.
  final bool mitLehrmeister;

  /// Eingegebener Lehrmeister-TaW oder `null`, wenn keiner genutzt wurde.
  final int? lehrmeisterTaW;

  /// Errechnete Dukatenkosten fuer den Lehrmeister oder `null`.
  final double? dukaten;
}

/// Oeffnet einen Dialog zur AP-basierten Bestaetigung eines Einmalkaufs
/// (Sonderfertigkeit, Manoever, nachtraeglicher Vor-/Nachteil-Erwerb).
///
/// Im Gegensatz zu `showSteigerungsDialog` gibt es keinen Zielwert-Stepper —
/// die AP-Kosten werden als editierbares Feld angezeigt, vorbelegt mit
/// [vorgeschlageneApKosten] (oder leer, wenn `null`).
Future<ErwerbErgebnis?> showErwerbDialog({
  required BuildContext context,
  required String bezeichnung,
  String? kostenHinweis,
  int? vorgeschlageneApKosten,
  required int verfuegbareAp,
  bool lehrmeisterUeblich = false,
  bool episch = false,
  bool epischerInhalt = false,
}) {
  return showAdaptiveInputDialog<ErwerbErgebnis>(
    context: context,
    builder: (dialogContext) {
      return _ErwerbDialog(
        bezeichnung: bezeichnung,
        kostenHinweis: kostenHinweis,
        vorgeschlageneApKosten: vorgeschlageneApKosten,
        verfuegbareAp: verfuegbareAp,
        lehrmeisterUeblich: lehrmeisterUeblich,
        episch: episch,
        epischerInhalt: epischerInhalt,
      );
    },
  );
}

class _ErwerbDialog extends StatefulWidget {
  const _ErwerbDialog({
    required this.bezeichnung,
    this.kostenHinweis,
    this.vorgeschlageneApKosten,
    required this.verfuegbareAp,
    required this.lehrmeisterUeblich,
    required this.episch,
    required this.epischerInhalt,
  });

  final String bezeichnung;
  final String? kostenHinweis;
  final int? vorgeschlageneApKosten;
  final int verfuegbareAp;
  final bool lehrmeisterUeblich;
  final bool episch;
  final bool epischerInhalt;

  @override
  State<_ErwerbDialog> createState() => _ErwerbDialogState();
}

class _ErwerbDialogState extends State<_ErwerbDialog> {
  late final TextEditingController _apKostenController;
  late final TextEditingController _lehrmeisterController;
  bool _mitLehrmeister = false;
  bool _keinEposAufschlag = false;
  int _lehrmeisterTaW = 15;

  @override
  void initState() {
    super.initState();
    _apKostenController = TextEditingController(
      text: widget.vorgeschlageneApKosten?.toString() ?? '',
    );
    _lehrmeisterController = TextEditingController(
      text: _lehrmeisterTaW.toString(),
    );
  }

  @override
  void dispose() {
    _apKostenController.dispose();
    _lehrmeisterController.dispose();
    super.dispose();
  }

  int? get _eingegebeneBasiskosten {
    final parsed = int.tryParse(_apKostenController.text.trim());
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  int get _kostenNachEpos {
    final basis = _eingegebeneBasiskosten ?? 0;
    return applyEpicApSurcharge(
      basis,
      ruleActive: true,
      isEpisch: widget.episch,
      isEpicContent: widget.epischerInhalt,
      isBegabung: _keinEposAufschlag,
      lehrmeisterHebtAuf: _mitLehrmeister,
    );
  }

  int get _eposAufschlagDelta {
    final basis = _eingegebeneBasiskosten ?? 0;
    return computeEpicApSurchargeDelta(
      basis,
      ruleActive: true,
      isEpisch: widget.episch,
      isEpicContent: widget.epischerInhalt,
      isBegabung: _keinEposAufschlag,
      lehrmeisterHebtAuf: _mitLehrmeister,
    );
  }

  int get _effektiveApKosten {
    final kosten = _kostenNachEpos;
    if (!_mitLehrmeister) {
      return kosten;
    }
    return apMitLehrmeister(kosten);
  }

  double? get _dukaten {
    if (!_mitLehrmeister) {
      return null;
    }
    return dukatenFuerLehrmeister(_effektiveApKosten, _lehrmeisterTaW);
  }

  bool get _hatGenugAp {
    return _effektiveApKosten <= widget.verfuegbareAp;
  }

  bool get _kannBestaetigen {
    return _eingegebeneBasiskosten != null && _hatGenugAp;
  }

  void _setLehrmeisterTaW(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) {
      return;
    }
    final normalized = parsed < 15 ? 15 : parsed;
    if (normalized == _lehrmeisterTaW) {
      return;
    }
    setState(() {
      _lehrmeisterTaW = normalized;
    });
  }

  String _formatDukaten(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restAp = widget.verfuegbareAp - _effektiveApKosten;
    final kostenHinweis = widget.kostenHinweis?.trim();

    return AdaptiveInputDialog(
      title: '${widget.bezeichnung} erwerben',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kostenHinweis != null && kostenHinweis.isNotEmpty) ...[
            Text('Katalog: $kostenHinweis', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _apKostenController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'AP-Kosten',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (widget.episch) ...[
            const SizedBox(height: 12),
            Text(
              _eposAufschlagDelta > 0
                  ? 'Epos-Aufschlag (+25 %): +$_eposAufschlagDelta AP'
                  : 'Kein Epos-Aufschlag',
              style: theme.textTheme.bodySmall,
            ),
            CheckboxListTile(
              value: _keinEposAufschlag,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Begabung/Sondererfahrung (kein Aufschlag)'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _keinEposAufschlag = value ?? false;
                });
              },
            ),
          ],
          const SizedBox(height: 8),
          Text('Verfügbare AP: ${widget.verfuegbareAp}'),
          Text(
            'AP nach Erwerb: $restAp',
            style: !_hatGenugAp
                ? theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  )
                : null,
          ),
          if (widget.lehrmeisterUeblich) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _mitLehrmeister,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Mit Lehrmeister'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _mitLehrmeister = value ?? false;
                });
              },
            ),
            if (_mitLehrmeister) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _lehrmeisterController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Lehrer-TaW',
                  helperText: 'Mindestens 15',
                  isDense: true,
                ),
                onChanged: _setLehrmeisterTaW,
              ),
              const SizedBox(height: 8),
              Text('Kosten (LM): $_effektiveApKosten AP'),
              Text('Dukaten: ${_formatDukaten(_dukaten ?? 0)}'),
            ],
          ],
          if (_eingegebeneBasiskosten == null) ...[
            const SizedBox(height: 12),
            Text(
              'Bitte gültige AP-Kosten eingeben.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ] else if (!_hatGenugAp) ...[
            const SizedBox(height: 12),
            Text(
              'Nicht genug AP für diesen Erwerb.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: !_kannBestaetigen
              ? null
              : () {
                  Navigator.of(context).pop(
                    ErwerbErgebnis(
                      apKosten: _effektiveApKosten,
                      mitLehrmeister: _mitLehrmeister,
                      lehrmeisterTaW: _mitLehrmeister ? _lehrmeisterTaW : null,
                      dukaten: _mitLehrmeister ? _dukaten : null,
                    ),
                  );
                },
          icon: const Icon(Icons.shopping_cart_checkout),
          label: const Text('Erwerben'),
        ),
      ],
    );
  }
}
