import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_healing_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Öffnet den Dialog „Heilzauber erhalten“ für einen Helden (MAG-EFF-05).
///
/// Der Dialog schließt sich nach dem Übernehmen selbst.
Future<void> showHeilungDialog({
  required BuildContext context,
  required String heroId,
}) {
  return showAdaptiveDetailSheet<void>(
    context: context,
    builder: (sheetContext) => AlertDialog(
      key: const ValueKey<String>('heilung-dialog'),
      title: const Text('Heilzauber erhalten'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: HeilungPanel(
            heroId: heroId,
            onUebernommen: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('heilung-dialog-close'),
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
}

/// Eingaben und Vorschau des Ablaufs „Heilung erhalten“.
///
/// Das Panel sammelt nur Eingaben. Gerechnet und geprüft wird in
/// `spell_effect_healing_rules.dart`, gespeichert über den Ablauf
/// `HeilungErhalten` auf dem frisch geladenen Zustand. Die Vorgangs-ID bleibt
/// bis zum Schließen, ein erneuter Versuch bucht so nie doppelt.
class HeilungPanel extends ConsumerStatefulWidget {
  /// Erstellt das Panel.
  const HeilungPanel({
    super.key,
    required this.heroId,
    required this.onUebernommen,
  });

  /// Held, dem die Heilung gebucht wird.
  final String heroId;

  /// Wird nach erfolgreichem Speichern aufgerufen.
  final VoidCallback onUebernommen;

  @override
  ConsumerState<HeilungPanel> createState() => _HeilungPanelState();
}

class _HeilungPanelState extends ConsumerState<HeilungPanel> {
  static const Map<String, String> _namen = <String, String>{
    kBalsamZauberId: 'Balsam Salabunde',
    kHexenspeichelZauberId: 'Hexenspeichel',
    kLachDichGesundZauberId: 'Lach dich gesund',
  };

  String _zauberId = kBalsamZauberId;
  HeilSchaden _schaden = HeilSchaden.wunde;
  bool _wundheilung = false;
  bool _selbst = false;
  WundZone? _zone;
  int? _wundenUeberschrieben;
  final TextEditingController _zfw = TextEditingController();
  final TextEditingController _asp = TextEditingController();
  final TextEditingController _zfp = TextEditingController();

  bool _schreibt = false;
  String? _fehler;
  String? _vorgangId;

  @override
  void dispose() {
    _zfw.dispose();
    _asp.dispose();
    _zfp.dispose();
    super.dispose();
  }

  int get _zfwWert => int.tryParse(_zfw.text.trim()) ?? 0;
  int get _aspWert => int.tryParse(_asp.text.trim()) ?? 0;
  int get _zfpWert => int.tryParse(_zfp.text.trim()) ?? 0;

  HeilEingabe _eingabe(int wunden) => HeilEingabe(
    zauberId: _zauberId,
    asp: _zauberId == kLachDichGesundZauberId ? 0 : _aspWert,
    zfw: _zfwWert,
    zfpStern: _zfpWert,
    schaden: _schaden,
    wundheilungAngesagt: _wundheilung && _zauberId == kBalsamZauberId,
    zone: _zone,
    wunden: wunden,
    selbstGewirkt: _selbst && _zauberId != kLachDichGesundZauberId,
  );

  Future<void> _uebernehme(HeilEingabe eingabe, int maxLep) async {
    if (_schreibt) {
      return;
    }
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      await ref
          .read(heilungErhaltenProvider)
          .uebernehmeHeilung(
            heroId: widget.heroId,
            eingabe: eingabe,
            zauberName: _namen[_zauberId]!,
            maxLep: maxLep,
            vorgangId: _vorgangId ??= const Uuid().v4(),
          );
      if (mounted) {
        widget.onUebernommen();
      }
    } catch (fehler) {
      if (mounted) {
        final text = fehler is StateError ? fehler.message : '$fehler';
        setState(() => _fehler = 'Heilung konnte nicht gebucht werden: $text');
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
      onChanged: (_) => setState(() => _wundenUeberschrieben = null),
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
    final balsam = _zauberId == kBalsamZauberId;
    final lach = _zauberId == kLachDichGesundZauberId;
    final zonenMitWunden = <WundZone>[
      for (final zone in WundZone.values)
        if (state.wpiZustand.wundenInZone(zone) > 0) zone,
    ];
    final zone = _zone != null && zonenMitWunden.contains(_zone)
        ? _zone
        : (zonenMitWunden.isEmpty ? null : zonenMitWunden.first);
    _zone = zone;

    final ohneWunden = pruefeHeilung(state, _eingabe(0), maxLep: maxLep);
    final vorschlag = _wundheilung && balsam
        ? (zone == null
              ? 0
              : ohneWunden.wundenVorschlag.clamp(
                  0,
                  state.wpiZustand.wundenInZone(zone),
                ))
        : 0;
    final wunden = _wundenUeberschrieben ?? vorschlag;
    final eingabe = _eingabe(wunden);
    final pruefung = pruefeHeilung(state, eingabe, maxLep: maxLep);
    final vorschau = pruefung.gueltig
        ? wendeHeilungAn(state, eingabe, maxLep: maxLep)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          key: const ValueKey<String>('heilung-zauber'),
          segments: [
            for (final eintrag in _namen.entries)
              ButtonSegment<String>(
                value: eintrag.key,
                label: Text(eintrag.value),
              ),
          ],
          selected: <String>{_zauberId},
          onSelectionChanged: _schreibt
              ? null
              : (auswahl) => setState(() {
                  _zauberId = auswahl.single;
                  _wundenUeberschrieben = null;
                }),
        ),
        const SizedBox(height: kDialogFieldSpacing),
        if (lach)
          _zahlfeld('heilung-zfp', _zfp, 'ZfP* des Zaubernden')
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _zahlfeld('heilung-zfw', _zfw, 'ZfW des Zaubernden'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _zahlfeld(
                  'heilung-asp',
                  _asp,
                  balsam ? 'Eingesetzte AsP (ab 5)' : 'Eingesetzte AsP',
                ),
              ),
            ],
          ),
        if (!balsam && !lach) ...[
          const SizedBox(height: kDialogFieldSpacing),
          SegmentedButton<HeilSchaden>(
            key: const ValueKey<String>('heilung-schaden'),
            segments: const [
              ButtonSegment<HeilSchaden>(
                value: HeilSchaden.wunde,
                label: Text('Wunden'),
              ),
              ButtonSegment<HeilSchaden>(
                value: HeilSchaden.krankheit,
                label: Text('Krankheit'),
              ),
              ButtonSegment<HeilSchaden>(
                value: HeilSchaden.vergiftung,
                label: Text('Vergiftung'),
              ),
            ],
            selected: <HeilSchaden>{_schaden},
            onSelectionChanged: _schreibt
                ? null
                : (auswahl) => setState(() => _schaden = auswahl.single),
          ),
        ],
        if (balsam)
          SwitchListTile(
            key: const ValueKey<String>('heilung-wundheilung'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Wundheilung angesagt'),
            subtitle: const Text(
              'Je 7 zurückgegebene LeP schließen eine Wunde',
            ),
            value: _wundheilung,
            onChanged: _schreibt
                ? null
                : (wert) => setState(() {
                    _wundheilung = wert;
                    _wundenUeberschrieben = null;
                  }),
          ),
        if (balsam && _wundheilung)
          ..._wundenBereich(theme, state, zone, wunden),
        if (!lach)
          SwitchListTile(
            key: const ValueKey<String>('heilung-selbst'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Der Held zaubert selbst'),
            subtitle: const Text(
              'Zieht die AsP des Helden ab; bei fremder Quelle bleibt sie unberührt',
            ),
            value: _selbst,
            onChanged: _schreibt
                ? null
                : (wert) => setState(() => _selbst = wert),
          ),
        const SizedBox(height: 8),
        for (final fehler in pruefung.fehler)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              fehler,
              key: const ValueKey<String>('heilung-fehler'),
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
            '${vorschau.wunden > 0 ? ' · ${vorschau.wunden == 1 ? '1 Wunde' : '${vorschau.wunden} Wunden'} geschlossen' : ''}',
            key: const ValueKey<String>('heilung-vorschau'),
            style: theme.textTheme.titleMedium,
          ),
        ],
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('heilung-speicherfehler'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey<String>('heilung-uebernehmen'),
            onPressed: !pruefung.gueltig || _schreibt
                ? null
                : () => _uebernehme(eingabe, maxLep),
            child: const Text('Übernehmen'),
          ),
        ),
      ],
    );
  }

  List<Widget> _wundenBereich(
    ThemeData theme,
    HeroState state,
    WundZone? zone,
    int wunden,
  ) {
    final zonen = <WundZone>[
      for (final z in WundZone.values)
        if (state.wpiZustand.wundenInZone(z) > 0) z,
    ];
    if (zonen.isEmpty) {
      return [
        Text(
          'Es sind keine Wunden eingetragen.',
          key: const ValueKey<String>('heilung-keine-wunden'),
          style: theme.textTheme.bodySmall,
        ),
      ];
    }
    final vorhanden = zone == null ? 0 : state.wpiZustand.wundenInZone(zone);
    return [
      DropdownButtonFormField<WundZone>(
        key: const ValueKey<String>('heilung-zone'),
        initialValue: zone,
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          labelText: 'Zone der Wunden',
        ),
        items: [
          for (final z in zonen)
            DropdownMenuItem<WundZone>(
              value: z,
              child: Text(
                '${wundZoneLabel[z]} (${state.wpiZustand.wundenInZone(z)})',
              ),
            ),
        ],
        onChanged: _schreibt
            ? null
            : (z) => setState(() {
                _zone = z;
                _wundenUeberschrieben = null;
              }),
      ),
      Row(
        children: [
          const Expanded(child: Text('Geschlossene Wunden')),
          IconButton(
            key: const ValueKey<String>('heilung-wunden-minus'),
            tooltip: 'Eine Wunde weniger',
            onPressed: wunden > 0 && !_schreibt
                ? () => setState(() => _wundenUeberschrieben = wunden - 1)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '$wunden',
            key: const ValueKey<String>('heilung-wunden'),
            style: theme.textTheme.titleMedium,
          ),
          IconButton(
            key: const ValueKey<String>('heilung-wunden-plus'),
            tooltip: 'Eine Wunde mehr',
            onPressed: wunden < vorhanden && !_schreibt
                ? () => setState(() => _wundenUeberschrieben = wunden + 1)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    ];
  }
}
