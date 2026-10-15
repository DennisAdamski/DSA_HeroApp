import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_verbrauch_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vitalwirkung_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Ob [eintrag] im Inventar „Anwenden“ anbietet: ein Verbrauchsgegenstand
/// mit hinterlegter Wirkung auf Vitalwerte oder Wunden.
bool hatVitalwirkung(HeroInventoryEntry eintrag) =>
    eintrag.vitalwirkung?.istBelegt ?? false;

/// Öffnet den Dialog „Gegenstand anwenden“ (Heiltrank, Verband …).
///
/// LeP, AsP, AuP und geschlossene Wunden sind mit der Vorbelegung des
/// Gegenstands gefüllt und frei änderbar. Beim Übernehmen bucht der Dialog die
/// Wirkung auf den frisch geladenen Zustand und zieht auf Wunsch ein Stück
/// vom Bestand ab. Liefert `true`, wenn die Wirkung gebucht wurde.
Future<bool> zeigeVitalwirkungAnwenden({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
}) async {
  final ergebnis = await showAdaptiveDetailSheet<bool>(
    context: context,
    builder: (sheetContext) => AlertDialog(
      key: const ValueKey<String>('vitalwirkung-dialog'),
      title: Text('${eintrag.gegenstand} anwenden'),
      content: SizedBox(
        width: kDialogWidthMedium,
        child: SingleChildScrollView(
          child: VitalwirkungPanel(
            heroId: heroId,
            eintrag: eintrag,
            onFertig: () => Navigator.of(sheetContext).pop(true),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('vitalwirkung-abbrechen'),
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: const Text('Abbrechen'),
        ),
      ],
    ),
  );
  return ergebnis ?? false;
}

/// Eingaben und Vorschau des Ablaufs „Gegenstand anwenden“.
///
/// Das Panel sammelt nur Eingaben. Gerechnet und geprüft wird in
/// `vitalwirkung_rules.dart`, gespeichert über den Ablauf
/// `VitalwirkungAnwenden`. Die Vorgangs-ID bleibt bis zum Schließen, ein
/// erneuter Versuch bucht so nie doppelt.
class VitalwirkungPanel extends ConsumerStatefulWidget {
  /// Erstellt das Panel.
  const VitalwirkungPanel({
    super.key,
    required this.heroId,
    required this.eintrag,
    required this.onFertig,
  });

  /// Held, dem die Wirkung gebucht wird.
  final String heroId;

  /// Der angezeigte Inventareintrag.
  final HeroInventoryEntry eintrag;

  /// Wird nach erfolgreichem Speichern aufgerufen.
  final VoidCallback onFertig;

  @override
  ConsumerState<VitalwirkungPanel> createState() => _VitalwirkungPanelState();
}

class _VitalwirkungPanelState extends ConsumerState<VitalwirkungPanel> {
  final TextEditingController _lep = TextEditingController();
  final TextEditingController _asp = TextEditingController();
  final TextEditingController _aup = TextEditingController();
  final Map<WundZone, int> _wunden = <WundZone, int>{};
  bool _initialisiert = false;
  bool _verbrauchen = true;
  bool _schreibt = false;
  bool _gebucht = false;
  String? _fehler;
  String? _vorgangId;

  @override
  void dispose() {
    _lep.dispose();
    _asp.dispose();
    _aup.dispose();
    super.dispose();
  }

  // Füllt die Felder einmalig aus der Vorbelegung des Gegenstands.
  void _initialisiere(HeroState zustand) {
    _initialisiert = true;
    final vorschlag = vitalVorschlag(widget.eintrag.vitalwirkung, zustand);
    String text(int wert) => wert > 0 ? '$wert' : '';
    _lep.text = text(vorschlag.lep);
    _asp.text = text(vorschlag.asp);
    _aup.text = text(vorschlag.aup);
    _wunden.addAll(vorschlag.wundenJeZone);
    _verbrauchen = inventarAbbuchbar(widget.eintrag);
  }

  int _zahl(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  VitalEingabe _eingabe() => VitalEingabe(
    lep: _zahl(_lep),
    asp: _zahl(_asp),
    aup: _zahl(_aup),
    wundenJeZone: <WundZone, int>{
      for (final e in _wunden.entries)
        if (e.value > 0) e.key: e.value,
    },
  );

  Future<void> _uebernehme(
    VitalEingabe eingabe,
    VitalGrenzen grenzen, {
    required bool verbrauchen,
  }) async {
    if (_schreibt) {
      return;
    }
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      if (!_gebucht) {
        await ref
            .read(vitalwirkungAnwendenProvider)
            .uebernimm(
              heroId: widget.heroId,
              eingabe: eingabe,
              gegenstand: widget.eintrag.gegenstand,
              grenzen: grenzen,
              vorgangId: _vorgangId ??= const Uuid().v4(),
            );
        _gebucht = true;
      }
      if (verbrauchen) {
        await ref
            .read(heroActionsProvider)
            .updateHero(
              widget.heroId,
              (held) => mitVerbrauchtemInventarEintrag(held, widget.eintrag),
            );
      }
      if (mounted) {
        widget.onFertig();
      }
    } catch (fehler) {
      if (mounted) {
        final text = fehler is StateError ? fehler.message : '$fehler';
        setState(
          () => _fehler = _gebucht
              ? 'Die Wirkung ist gebucht, das Stück konnte aber nicht '
                    'abgezogen werden: $text'
              : 'Die Wirkung konnte nicht gebucht werden: $text',
        );
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
      enabled: !_gebucht && !_schreibt,
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
    final zustand = ref.watch(heroStateProvider(widget.heroId)).valueOrNull;
    final computed = ref.watch(heroComputedProvider(widget.heroId)).valueOrNull;
    if (zustand == null || computed == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_initialisiert) {
      _initialisiere(zustand);
    }
    final theme = Theme.of(context);
    final grenzen = VitalGrenzen(
      maxLep: computed.derivedStats.maxLep,
      maxAsp: computed.derivedStats.maxAsp,
      maxAu: computed.derivedStats.maxAu,
    );
    final planung =
        ref.watch(advancementSessionProvider(widget.heroId)) != null;
    final abbuchbar = inventarAbbuchbar(widget.eintrag) && !planung;
    final eingabe = _eingabe();
    final pruefung = pruefeVitalwirkung(zustand, eingabe, grenzen: grenzen);
    final vorschau = pruefung.gueltig
        ? wendeVitalwirkungAn(zustand, eingabe, grenzen: grenzen)
        : null;
    final zonen = <WundZone>[
      for (final z in WundZone.values)
        if (zustand.wpiZustand.wundenInZone(z) > 0) z,
    ];
    final menge = inventarMenge(widget.eintrag);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _zahlfeld(
                'vitalwirkung-lep',
                _lep,
                'LeP (${zustand.currentLep} / ${grenzen.maxLep})',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _zahlfeld(
                'vitalwirkung-asp',
                _asp,
                'AsP (${zustand.currentAsp} / ${grenzen.maxAsp})',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _zahlfeld(
                'vitalwirkung-aup',
                _aup,
                'AuP (${zustand.currentAu} / ${grenzen.maxAu})',
              ),
            ),
          ],
        ),
        const SizedBox(height: kDialogFieldSpacing),
        if (zonen.isEmpty)
          Text(
            'Es sind keine Wunden eingetragen.',
            key: const ValueKey<String>('vitalwirkung-keine-wunden'),
            style: theme.textTheme.bodySmall,
          )
        else ...[
          Text('Geschlossene Wunden', style: theme.textTheme.titleSmall),
          for (final zone in zonen) _wundenZeile(theme, zustand, zone),
        ],
        if (abbuchbar)
          CheckboxListTile(
            key: const ValueKey<String>('vitalwirkung-verbrauchen'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Ein Stück verbrauchen'),
            subtitle: Text('Bestand $menge → ${menge! - 1}'),
            value: _verbrauchen,
            onChanged: _schreibt || _gebucht
                ? null
                : (wert) => setState(() => _verbrauchen = wert ?? false),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              planung
                  ? 'Während einer Planung wird das Inventar nicht geändert; '
                        'das Stück bitte danach von Hand abziehen.'
                  : 'Die Menge ist nicht eindeutig: Es wird kein Stück '
                        'abgezogen.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (final fehler in pruefung.fehler)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              fehler,
              key: const ValueKey<String>('vitalwirkung-fehler'),
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
            _vorschauText(zustand, vorschau),
            key: const ValueKey<String>('vitalwirkung-vorschau'),
            style: theme.textTheme.titleMedium,
          ),
        ],
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('vitalwirkung-speicherfehler'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            key: const ValueKey<String>('vitalwirkung-uebernehmen'),
            onPressed: (!_gebucht && !pruefung.gueltig) || _schreibt
                ? null
                : () => _uebernehme(
                    eingabe,
                    grenzen,
                    verbrauchen: _verbrauchen && abbuchbar,
                  ),
            child: Text(_gebucht ? 'Stück abziehen' : 'Anwenden'),
          ),
        ),
      ],
    );
  }

  String _vorschauText(HeroState zustand, VitalAnwendung vorschau) {
    final teile = <String>[
      'LeP ${zustand.currentLep} → ${vorschau.zustand.currentLep}',
      if (vorschau.asp > 0)
        'AsP ${zustand.currentAsp} → ${vorschau.zustand.currentAsp}',
      if (vorschau.aup > 0)
        'AuP ${zustand.currentAu} → ${vorschau.zustand.currentAu}',
      if (vorschau.wunden > 0)
        vorschau.wunden == 1
            ? '1 Wunde geschlossen'
            : '${vorschau.wunden} Wunden geschlossen',
    ];
    return teile.join(' · ');
  }

  Widget _wundenZeile(ThemeData theme, HeroState zustand, WundZone zone) {
    final vorhanden = zustand.wpiZustand.wundenInZone(zone);
    final wert = (_wunden[zone] ?? 0).clamp(0, vorhanden);
    final gesperrt = _schreibt || _gebucht;
    return Row(
      children: [
        Expanded(child: Text('${wundZoneLabel[zone]} ($vorhanden)')),
        IconButton(
          key: ValueKey<String>('vitalwirkung-wunden-minus-${zone.name}'),
          tooltip: 'Eine Wunde weniger',
          onPressed: wert > 0 && !gesperrt
              ? () => setState(() => _wunden[zone] = wert - 1)
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '$wert',
          key: ValueKey<String>('vitalwirkung-wunden-${zone.name}'),
          style: theme.textTheme.titleMedium,
        ),
        IconButton(
          key: ValueKey<String>('vitalwirkung-wunden-plus-${zone.name}'),
          tooltip: 'Eine Wunde mehr',
          onPressed: wert < vorhanden && !gesperrt
              ? () => setState(() => _wunden[zone] = wert + 1)
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
