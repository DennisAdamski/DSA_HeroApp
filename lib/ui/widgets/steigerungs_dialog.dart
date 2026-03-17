import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_rules.dart';

/// Ergebnis eines bestaetigten Steigerungsdialogs.
class SteigerungsErgebnis {
  /// Erzeugt ein unveraenderliches Dialogergebnis.
  const SteigerungsErgebnis({
    required this.neuerWert,
    required this.apKosten,
    required this.seVerbraucht,
    required this.lehrmeisterTaW,
    required this.dukaten,
  });

  /// Neuer Zielwert nach der Steigerung.
  final int neuerWert;

  /// Effektive AP-Kosten, inklusive moeglichem Lehrmeister-Rabatt.
  final int apKosten;

  /// Anzahl der in dieser Steigerung verbrauchten Sondererfahrungen.
  final int seVerbraucht;

  /// Eingegebener Lehrmeister-TaW oder `null`, wenn keiner genutzt wurde.
  final int? lehrmeisterTaW;

  /// Errechnete Dukatenkosten fuer den Lehrmeister oder `null`.
  final double? dukaten;
}

/// Oeffnet einen Dialog zur AP-basierten Steigerung eines Werts.
///
/// `aktuellerWert < 0` repraesentiert einen noch nicht aktivierten Wert.
/// Dadurch koennen Talente mit Aktivierungskosten ohne separates Zusatz-Flag
/// verarbeitet werden.
Future<SteigerungsErgebnis?> showSteigerungsDialog({
  required BuildContext context,
  required String bezeichnung,
  required int aktuellerWert,
  required LearnCost effektiveKomplexitaet,
  required int verfuegbareAp,
  required int maxWert,
  int seAnzahl = 0,
  bool lehrmeisterVerfuegbar = false,
}) {
  return showAdaptiveDetailSheet<SteigerungsErgebnis>(
    context: context,
    builder: (dialogContext) {
      return _SteigerungsDialog(
        bezeichnung: bezeichnung,
        aktuellerWert: aktuellerWert,
        maxWert: maxWert,
        effektiveKomplexitaet: effektiveKomplexitaet,
        verfuegbareAp: verfuegbareAp,
        seAnzahl: seAnzahl,
        lehrmeisterVerfuegbar: lehrmeisterVerfuegbar,
      );
    },
  );
}

class _SteigerungsDialog extends StatefulWidget {
  const _SteigerungsDialog({
    required this.bezeichnung,
    required this.aktuellerWert,
    required this.maxWert,
    required this.effektiveKomplexitaet,
    required this.verfuegbareAp,
    required this.seAnzahl,
    required this.lehrmeisterVerfuegbar,
  });

  final String bezeichnung;
  final int aktuellerWert;
  final int maxWert;
  final LearnCost effektiveKomplexitaet;
  final int verfuegbareAp;
  final int seAnzahl;
  final bool lehrmeisterVerfuegbar;

  @override
  State<_SteigerungsDialog> createState() => _SteigerungsDialogState();
}

class _SteigerungsDialogState extends State<_SteigerungsDialog> {
  late int _neuerWert;
  late LearnCost _ausgewaehlteKomplexitaet;
  late final TextEditingController _wertController;
  late final TextEditingController _lehrmeisterController;
  bool _mitLehrmeister = false;
  int _lehrmeisterTaW = 15;

  @override
  void initState() {
    super.initState();
    final initialValue = math.max(widget.aktuellerWert + 1, 0);
    _neuerWert = _normalizeZielwert(initialValue);
    _ausgewaehlteKomplexitaet = widget.effektiveKomplexitaet;
    _wertController = TextEditingController(text: _neuerWert.toString());
    _lehrmeisterController = TextEditingController(
      text: _lehrmeisterTaW.toString(),
    );
  }

  @override
  void dispose() {
    _wertController.dispose();
    _lehrmeisterController.dispose();
    super.dispose();
  }

  int get _minZielwert {
    return math.max(widget.aktuellerWert, 0);
  }

  int get _maxZielwert {
    return math.max(widget.maxWert, _minZielwert);
  }

  ({int apKosten, int seVerbraucht}) get _basisKosten {
    return berechneSteigerungskosten(
      vonWert: widget.aktuellerWert,
      aufWert: _neuerWert,
      effektiveKomplexitaet: _ausgewaehlteKomplexitaet,
      seAnzahl: widget.seAnzahl,
    );
  }

  int get _effektiveApKosten {
    final basisKosten = _basisKosten.apKosten;
    if (!_mitLehrmeister) {
      return basisKosten;
    }
    return apMitLehrmeister(basisKosten);
  }

  double? get _dukaten {
    if (!_mitLehrmeister) {
      return null;
    }
    return dukatenFuerLehrmeister(_effektiveApKosten, _lehrmeisterTaW);
  }

  bool get _istGueltigerZielwert {
    return _neuerWert > widget.aktuellerWert && _neuerWert <= _maxZielwert;
  }

  bool get _hatMaximalwertErreicht {
    return widget.aktuellerWert >= _maxZielwert;
  }

  bool get _hatGenugAp {
    return _effektiveApKosten <= widget.verfuegbareAp;
  }

  int _normalizeZielwert(int value) {
    return value.clamp(_minZielwert, _maxZielwert);
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
    });
  }

  void _setLehrmeisterTaW(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) {
      return;
    }
    final normalized = math.max(parsed, 15);
    if (normalized == _lehrmeisterTaW) {
      return;
    }
    setState(() {
      _lehrmeisterTaW = normalized;
    });
  }

  void _setKomplexitaet(LearnCost value) {
    if (value == _ausgewaehlteKomplexitaet) {
      return;
    }
    setState(() {
      _ausgewaehlteKomplexitaet = value;
    });
  }

  String _aktuellerWertLabel() {
    if (widget.aktuellerWert < 0) {
      return 'nicht aktiviert';
    }
    return widget.aktuellerWert.toString();
  }

  String _ausgewaehlteKomplexitaetLabel() {
    return komplexitaetLabel(_ausgewaehlteKomplexitaet);
  }

  String? _komplexitaetsHinweisText() {
    final hinweise = <String>[];
    if (_ausgewaehlteKomplexitaet != widget.effektiveKomplexitaet) {
      final standardLabel = komplexitaetLabel(widget.effektiveKomplexitaet);
      hinweise.add('Standard: $standardLabel');
    }

    final verbrauchteSe = _basisKosten.seVerbraucht;
    if (verbrauchteSe > 0) {
      final reduzierteKomplexitaet = komplexitaetLabel(
        _ausgewaehlteKomplexitaet.previous(),
      );
      final seLabel = verbrauchteSe == 1
          ? '1 Schritt'
          : '$verbrauchteSe Schritte';
      hinweise.add(
        'Mit ${widget.seAnzahl} SE: $seLabel als $reduzierteKomplexitaet',
      );
    }

    if (hinweise.isEmpty) {
      return null;
    }
    return hinweise.join(' | ');
  }

  String _formatDukaten(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restAp = widget.verfuegbareAp - _effektiveApKosten;
    final kannBestaetigen = _istGueltigerZielwert && _hatGenugAp;
    final basisKosten = _basisKosten;
    final komplexitaetsHinweis = _komplexitaetsHinweisText();

    return AlertDialog(
      title: Text('${widget.bezeichnung} steigern'),
      content: SizedBox(
        width: kDialogWidthSmall,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aktueller Wert: ${_aktuellerWertLabel()} | '
                'Maximaler Wert: ${widget.maxWert}',
              ),
              const SizedBox(height: 12),
              Text('Neuer Wert'),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    onPressed: _neuerWert <= _minZielwert
                        ? null
                        : () => _setNeuerWert(_neuerWert - 1),
                    icon: const Icon(Icons.remove),
                    tooltip: 'Wert senken',
                  ),
                  SizedBox(
                    width: 92,
                    child: TextField(
                      controller: _wertController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (raw) {
                        final parsed = int.tryParse(raw);
                        if (parsed == null) {
                          return;
                        }
                        _setNeuerWert(parsed);
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: _neuerWert >= _maxZielwert
                        ? null
                        : () => _setNeuerWert(_neuerWert + 1),
                    icon: const Icon(Icons.add),
                    tooltip: 'Wert steigern',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Komplexität'),
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    key: const ValueKey<String>(
                      'steigerungs-dialog-complexity-decrease',
                    ),
                    onPressed:
                        _ausgewaehlteKomplexitaet == LearnCost.values.first
                        ? null
                        : () => _setKomplexitaet(
                            _ausgewaehlteKomplexitaet.previous(),
                          ),
                    icon: const Icon(Icons.remove),
                    tooltip: 'Komplexität reduzieren',
                  ),
                  SizedBox(
                    width: 92,
                    child: Center(
                      child: Text(
                        _ausgewaehlteKomplexitaetLabel(),
                        key: const ValueKey<String>(
                          'steigerungs-dialog-complexity-value',
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>(
                      'steigerungs-dialog-complexity-increase',
                    ),
                    onPressed:
                        _ausgewaehlteKomplexitaet == LearnCost.values.last
                        ? null
                        : () => _setKomplexitaet(
                            _ausgewaehlteKomplexitaet.next(),
                          ),
                    icon: const Icon(Icons.add),
                    tooltip: 'Komplexität erhöhen',
                  ),
                ],
              ),
              if (komplexitaetsHinweis != null) ...[
                Text(komplexitaetsHinweis, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 4),
              Text('AP-Kosten: ${basisKosten.apKosten}'),
              const SizedBox(height: 12),
              Text('Verfügbare AP: ${widget.verfuegbareAp}'),
              Text(
                'AP nach Steigerung: $restAp',
                style: !_hatGenugAp
                    ? theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
              if (widget.lehrmeisterVerfuegbar) ...[
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
                    onSubmitted: (raw) {
                      final normalized = math.max(
                        int.tryParse(raw.trim()) ?? 15,
                        15,
                      );
                      _lehrmeisterController.value = TextEditingValue(
                        text: normalized.toString(),
                        selection: TextSelection.collapsed(
                          offset: normalized.toString().length,
                        ),
                      );
                      _setLehrmeisterTaW(normalized.toString());
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Kosten (LM): $_effektiveApKosten AP'),
                  Text('Dukaten: ${_formatDukaten(_dukaten ?? 0)}'),
                ],
              ],
              if (_hatMaximalwertErreicht) ...[
                const SizedBox(height: 12),
                Text(
                  'Der Maximalwert ist bereits erreicht.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ] else if (!_istGueltigerZielwert) ...[
                const SizedBox(height: 12),
                Text(
                  'Der neue Wert muss ueber dem aktuellen Wert liegen.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ] else if (!_hatGenugAp) ...[
                const SizedBox(height: 12),
                Text(
                  'Nicht genug AP fuer diese Steigerung.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: !kannBestaetigen
              ? null
              : () {
                  Navigator.of(context).pop(
                    SteigerungsErgebnis(
                      neuerWert: _neuerWert,
                      apKosten: _effektiveApKosten,
                      seVerbraucht: basisKosten.seVerbraucht,
                      lehrmeisterTaW: _mitLehrmeister ? _lehrmeisterTaW : null,
                      dukaten: _mitLehrmeister ? _dukaten : null,
                    ),
                  );
                },
          icon: const Icon(Icons.trending_up),
          label: const Text('Steigern'),
        ),
      ],
    );
  }
}
