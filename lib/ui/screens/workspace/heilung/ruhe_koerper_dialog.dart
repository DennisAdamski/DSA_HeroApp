import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_rest_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Öffnet den Dialog „Ruhe Körper“ für einen Helden (MAG-EFF-05).
Future<void> showRuheKoerperDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (sheetContext) => AlertDialog(
      key: const ValueKey<String>('ruhe-koerper-dialog'),
      title: const Text('Ruhe Körper'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: RuheKoerperPanel(
            heroId: heroId,
            onUebernommen: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('ruhe-koerper-close'),
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
}

/// Eingaben und Vorschau des Schlafs unter Ruhe Körper.
///
/// Das Panel sammelt nur Eingaben; gerechnet und geprüft wird in
/// `spell_effect_rest_rules.dart`, gespeichert über `RuheKoerperErhalten`.
/// Die Vorgangs-ID bleibt bis zum Schließen.
class RuheKoerperPanel extends ConsumerStatefulWidget {
  /// Erstellt das Panel.
  const RuheKoerperPanel({
    super.key,
    required this.heroId,
    required this.onUebernommen,
  });

  /// Held, der schläft.
  final String heroId;

  /// Wird nach erfolgreichem Speichern aufgerufen.
  final VoidCallback onUebernommen;

  @override
  ConsumerState<RuheKoerperPanel> createState() => _RuheKoerperPanelState();
}

class _RuheKoerperPanelState extends ConsumerState<RuheKoerperPanel> {
  final TextEditingController _zfp = TextEditingController();
  final TextEditingController _stunden = TextEditingController();
  final TextEditingController _asp = TextEditingController();
  final Map<WundZone, int> _wunden = <WundZone, int>{};

  bool _schreibt = false;
  String? _fehler;
  String? _vorgangId;

  @override
  void dispose() {
    _zfp.dispose();
    _stunden.dispose();
    _asp.dispose();
    super.dispose();
  }

  int _zahl(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  RuheKoerperEingabe _eingabe() => RuheKoerperEingabe(
    zfpStern: _zahl(_zfp),
    stunden: _zahl(_stunden),
    aspRegeneration: _zahl(_asp),
    geschlosseneWunden: Map<WundZone, int>.of(_wunden),
  );

  Future<void> _uebernehme(
    RuheKoerperEingabe eingabe,
    int maxLep,
    int maxAsp,
  ) async {
    if (_schreibt) {
      return;
    }
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      await ref
          .read(ruheKoerperErhaltenProvider)
          .uebernehmeSchlaf(
            heroId: widget.heroId,
            eingabe: eingabe,
            maxLep: maxLep,
            maxAsp: maxAsp,
            vorgangId: _vorgangId ??= const Uuid().v4(),
          );
      if (mounted) {
        widget.onUebernommen();
      }
    } catch (fehler) {
      if (mounted) {
        final text = fehler is StateError ? fehler.message : '$fehler';
        setState(() => _fehler = 'Schlaf konnte nicht gebucht werden: $text');
      }
    } finally {
      if (mounted) {
        setState(() => _schreibt = false);
      }
    }
  }

  Widget _zahlfeld(String schluessel, TextEditingController c, String label) {
    return TextField(
      key: ValueKey<String>(schluessel),
      controller: c,
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
    final state = ref.watch(heroStateProvider(widget.heroId)).valueOrNull;
    final computed = ref.watch(heroComputedProvider(widget.heroId)).valueOrNull;
    if (state == null || computed == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final maxLep = computed.derivedStats.maxLep;
    final maxAsp = computed.derivedStats.maxAsp;
    final eingabe = _eingabe();
    final pruefung = pruefeRuheKoerper(state, eingabe, maxAsp: maxAsp);
    final vorschau = pruefung.gueltig
        ? wendeRuheKoerperAn(state, eingabe, maxLep: maxLep, maxAsp: maxAsp)
        : null;
    final zonen = <WundZone>[
      for (final zone in WundZone.values)
        if (state.wpiZustand.wundenInZone(zone) > 0) zone,
    ];
    final frei = pruefung.wundenMoeglich - eingabe.wundenGesamt;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Der Zauber ersetzt die normale Regeneration der Schlafstunden '
          '(LC S. 220): 2 LeP, 4 Überanstrengung und 8 Erschöpfung weniger '
          'je Stunde, je 6 Stunden eine Wunde vollständig geheilt.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: kDialogFieldSpacing),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _zahlfeld('ruhe-zfp', _zfp, 'ZfP* des Zaubernden')),
            const SizedBox(width: 12),
            Expanded(
              child: _zahlfeld(
                'ruhe-stunden',
                _stunden,
                'Verschlafene Stunden',
              ),
            ),
          ],
        ),
        const SizedBox(height: kDialogFieldSpacing),
        _zahlfeld('ruhe-asp', _asp, 'Zurückbekommene AsP (optional)'),
        if (zonen.isNotEmpty && pruefung.wundenMoeglich > 0) ...[
          const SizedBox(height: kDialogFieldSpacing),
          Text(
            'Verheilte Wunden (bis zu ${pruefung.wundenMoeglich})',
            style: theme.textTheme.titleSmall,
          ),
          for (final zone in zonen)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${wundZoneLabel[zone]} '
                    '(${state.wpiZustand.wundenInZone(zone)})',
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('ruhe-wunden-minus-${zone.name}'),
                  tooltip: 'Eine Wunde weniger',
                  onPressed: (_wunden[zone] ?? 0) > 0 && !_schreibt
                      ? () => setState(() => _wunden[zone] = _wunden[zone]! - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${_wunden[zone] ?? 0}',
                  key: ValueKey<String>('ruhe-wunden-${zone.name}'),
                ),
                IconButton(
                  key: ValueKey<String>('ruhe-wunden-plus-${zone.name}'),
                  tooltip: 'Eine Wunde mehr',
                  onPressed:
                      frei > 0 &&
                          (_wunden[zone] ?? 0) <
                              state.wpiZustand.wundenInZone(zone) &&
                          !_schreibt
                      ? () => setState(
                          () => _wunden[zone] = (_wunden[zone] ?? 0) + 1,
                        )
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
        ],
        const SizedBox(height: 8),
        for (final fehler in pruefung.fehler)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              fehler,
              key: const ValueKey<String>('ruhe-fehler'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        for (final hinweis in pruefung.hinweise)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(hinweis, style: theme.textTheme.bodySmall),
          ),
        if (vorschau != null) ...[
          const SizedBox(height: 8),
          Text(
            'LeP ${state.currentLep} → ${vorschau.zustand.currentLep}'
            '${vorschau.asp > 0 ? ' · AsP ${state.currentAsp} → ${vorschau.zustand.currentAsp}' : ''}'
            '${vorschau.ueberanstrengung > 0 ? ' · Überanstrengung ${state.ueberanstrengung} → ${vorschau.zustand.ueberanstrengung}' : ''}'
            '${vorschau.erschoepfung > 0 ? ' · Erschöpfung ${state.erschoepfung} → ${vorschau.zustand.erschoepfung}' : ''}'
            '${vorschau.wundenGesamt > 0 ? ' · ${vorschau.wundenGesamt} Wunde${vorschau.wundenGesamt == 1 ? '' : 'n'} geheilt' : ''}',
            key: const ValueKey<String>('ruhe-vorschau'),
            style: theme.textTheme.titleMedium,
          ),
        ],
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('ruhe-speicherfehler'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey<String>('ruhe-uebernehmen'),
            onPressed: !pruefung.gueltig || _schreibt
                ? null
                : () => _uebernehme(eingabe, maxLep, maxAsp),
            child: const Text('Übernehmen'),
          ),
        ),
      ],
    );
  }
}
