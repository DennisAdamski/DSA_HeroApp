import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/rules/derived/epic_ap_cost_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trait_ap_cost_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Ergebnis eines bestaetigten Nachteil-Abbau-Dialogs.
class NachteilAbbauErgebnis {
  /// Erzeugt ein unveraenderliches Dialogergebnis.
  const NachteilAbbauErgebnis({
    required this.neuerWert,
    required this.apKosten,
    required this.mitSpeziellerErfahrung,
  });

  /// Neuer Zielwert nach dem Abbau. Liegt dieser unter dem minimalen Wert
  /// des Nachteils, ist der Nachteil vollstaendig entfernt worden.
  final int neuerWert;

  /// Effektive AP-Kosten, inklusive moeglichem Epos-Aufschlag.
  final int apKosten;

  /// Ob der Abbau mit Spezieller Erfahrung (guenstigerer Faktor) erfolgte.
  final bool mitSpeziellerErfahrung;
}

/// Oeffnet einen Dialog zum stufenweisen Absenken eines gestuften Nachteils.
///
/// Der Zielwert-Stepper reicht von `minWert - 1` (entspricht "wird
/// entfernt") bis `aktuellerWert - 1`. Die AP-Kosten werden pro gesenktem
/// Punkt aufsummiert (analog zum Steigerungsdialog, nur abwaerts).
Future<NachteilAbbauErgebnis?> showNachteilAbbauDialog({
  required BuildContext context,
  required String bezeichnung,
  required int aktuellerWert,
  required int minWert,
  int? gpWertProPunkt,
  bool istSpeziellerErfahrungFaehig = false,
  required int verfuegbareAp,
  bool episch = false,
}) {
  return showAdaptiveInputDialog<NachteilAbbauErgebnis>(
    context: context,
    builder: (dialogContext) {
      return _NachteilAbbauDialog(
        bezeichnung: bezeichnung,
        aktuellerWert: aktuellerWert,
        minWert: minWert,
        gpWertProPunkt: gpWertProPunkt,
        istSpeziellerErfahrungFaehig: istSpeziellerErfahrungFaehig,
        verfuegbareAp: verfuegbareAp,
        episch: episch,
      );
    },
  );
}

class _NachteilAbbauDialog extends StatefulWidget {
  const _NachteilAbbauDialog({
    required this.bezeichnung,
    required this.aktuellerWert,
    required this.minWert,
    this.gpWertProPunkt,
    required this.istSpeziellerErfahrungFaehig,
    required this.verfuegbareAp,
    required this.episch,
  });

  final String bezeichnung;
  final int aktuellerWert;
  final int minWert;
  final int? gpWertProPunkt;
  final bool istSpeziellerErfahrungFaehig;
  final int verfuegbareAp;
  final bool episch;

  @override
  State<_NachteilAbbauDialog> createState() => _NachteilAbbauDialogState();
}

class _NachteilAbbauDialogState extends State<_NachteilAbbauDialog> {
  late int _neuerWert;
  late final TextEditingController _wertController;
  late final TextEditingController _apKostenController;
  bool _mitSpeziellerErfahrung = false;

  @override
  void initState() {
    super.initState();
    _neuerWert = _normalizeZielwert(widget.aktuellerWert - 1);
    _wertController = TextEditingController(text: _neuerWert.toString());
    _apKostenController = TextEditingController(
      text: (_berechneteKosten ?? 0).toString(),
    );
  }

  @override
  void dispose() {
    _wertController.dispose();
    _apKostenController.dispose();
    super.dispose();
  }

  int get _minZielwert {
    return widget.minWert - 1;
  }

  int get _maxZielwert {
    return math.max(widget.aktuellerWert - 1, _minZielwert);
  }

  bool get _wirdEntfernt {
    return _neuerWert < widget.minWert;
  }

  int get _gesenktePunkte {
    return widget.aktuellerWert - _neuerWert;
  }

  int get _faktor {
    if (widget.istSpeziellerErfahrungFaehig) {
      return _mitSpeziellerErfahrung
          ? kSchlechteEigenschaftSpezErfahrungFaktor
          : kSchlechteEigenschaftSelbststudiumFaktor;
    }
    return kNachteilAbbauFaktor;
  }

  int? get _berechneteKosten {
    final gpWertProPunkt = widget.gpWertProPunkt;
    if (gpWertProPunkt == null) {
      return null;
    }
    return computeTraitAbbauApCost(
      gpWertProPunkt: gpWertProPunkt,
      faktor: _faktor,
      punkte: _gesenktePunkte,
    );
  }

  int? get _eingegebeneBasiskosten {
    if (widget.gpWertProPunkt != null) {
      return _berechneteKosten;
    }
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
      isSpecialExperience: _mitSpeziellerErfahrung,
    );
  }

  int get _eposAufschlagDelta {
    final basis = _eingegebeneBasiskosten ?? 0;
    return computeEpicApSurchargeDelta(
      basis,
      ruleActive: true,
      isEpisch: widget.episch,
      isSpecialExperience: _mitSpeziellerErfahrung,
    );
  }

  int get _effektiveApKosten {
    return _kostenNachEpos;
  }

  bool get _hatGenugAp {
    return _effektiveApKosten <= widget.verfuegbareAp;
  }

  bool get _istGueltigerZielwert {
    return _neuerWert < widget.aktuellerWert && _neuerWert >= _minZielwert;
  }

  bool get _kannBestaetigen {
    return _istGueltigerZielwert &&
        _eingegebeneBasiskosten != null &&
        _hatGenugAp;
  }

  int _normalizeZielwert(int value) {
    return value.clamp(widget.minWert - 1, widget.aktuellerWert - 1);
  }

  void _setNeuerWert(int value) {
    final normalized = _normalizeZielwert(value);
    if (normalized == _neuerWert) {
      return;
    }
    setState(() {
      _neuerWert = normalized;
      _wertController.value = TextEditingValue(
        text: normalized.toString(),
        selection: TextSelection.collapsed(
          offset: normalized.toString().length,
        ),
      );
      if (widget.gpWertProPunkt != null) {
        _apKostenController.text = (_berechneteKosten ?? 0).toString();
      }
    });
  }

  String _zielwertLabel(int value) {
    return value < widget.minWert ? 'entfernt' : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restAp = widget.verfuegbareAp - _effektiveApKosten;
    final kostenBerechnet = widget.gpWertProPunkt != null;

    return AdaptiveInputDialog(
      title: '${widget.bezeichnung} abbauen',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aktueller Wert: ${widget.aktuellerWert} | '
            'Minimaler Wert: ${widget.minWert}',
          ),
          const SizedBox(height: 12),
          const Text('Neuer Wert'),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: _neuerWert <= _minZielwert
                    ? null
                    : () => _setNeuerWert(_neuerWert - 1),
                icon: const Icon(Icons.remove),
                tooltip: 'Wert weiter senken',
              ),
              SizedBox(
                width: 92,
                child: Center(
                  child: Text(
                    _zielwertLabel(_neuerWert),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                onPressed: _neuerWert >= _maxZielwert
                    ? null
                    : () => _setNeuerWert(_neuerWert + 1),
                icon: const Icon(Icons.add),
                tooltip: 'Wert weniger senken',
              ),
            ],
          ),
          if (widget.istSpeziellerErfahrungFaehig) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const ValueKey<String>(
                'nachteil-abbau-dialog-spezielle-erfahrung',
              ),
              value: _mitSpeziellerErfahrung,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Mit Spezieller Erfahrung abbauen '
                '($kSchlechteEigenschaftSpezErfahrungFaktor× statt '
                '$kSchlechteEigenschaftSelbststudiumFaktor× GP-Wert je Punkt)',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _mitSpeziellerErfahrung = value ?? false;
                  if (widget.gpWertProPunkt != null) {
                    _apKostenController.text =
                        (_berechneteKosten ?? 0).toString();
                  }
                });
              },
            ),
          ],
          const SizedBox(height: 8),
          if (kostenBerechnet)
            Text('AP-Kosten: ${_eingegebeneBasiskosten ?? 0}')
          else
            TextField(
              key: const ValueKey<String>(
                'nachteil-abbau-dialog-ap-kosten',
              ),
              controller: _apKostenController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'AP-Kosten',
                helperText:
                    'Katalogtext nicht eindeutig auswertbar, bitte manuell '
                    'eintragen.',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          if (widget.episch && _eposAufschlagDelta > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Epos-Aufschlag (+25 %): +$_eposAufschlagDelta AP',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text('Verfügbare AP: ${widget.verfuegbareAp}'),
          Text(
            'AP nach Abbau: $restAp',
            style: !_hatGenugAp
                ? theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  )
                : null,
          ),
          if (_wirdEntfernt) ...[
            const SizedBox(height: 12),
            Text(
              'Der Nachteil wird bei Bestätigung vollständig entfernt.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (!_istGueltigerZielwert) ...[
            const SizedBox(height: 12),
            Text(
              'Der neue Wert muss unter dem aktuellen Wert liegen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ] else if (!_hatGenugAp) ...[
            const SizedBox(height: 12),
            Text(
              'Nicht genug AP für diesen Abbau.',
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
                    NachteilAbbauErgebnis(
                      neuerWert: _neuerWert,
                      apKosten: _effektiveApKosten,
                      mitSpeziellerErfahrung: _mitSpeziellerErfahrung,
                    ),
                  );
                },
          icon: const Icon(Icons.trending_down),
          label: const Text('Abbauen'),
        ),
      ],
    );
  }
}
