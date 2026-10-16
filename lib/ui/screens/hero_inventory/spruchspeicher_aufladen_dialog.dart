import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/artefakt_protokollieren.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_ladung_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_ladungen_editor.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Öffnet den Aufladedialog eines leeren, aufladbaren Spruchspeichers.
///
/// Zuerst würfelt der Dialog auf die Haltematrix (Wege der Alchimie 2012:
/// nur eine 20, jede bisherige Aufladung senkt die Schwelle um 1; Stäbe,
/// Ringe, Dschinnenlampen 2011: 19–20) und zeigt das Ergebnis. Erst
/// „Übernehmen“ schreibt: bei Beschädigung den Defekt, sonst die neuen
/// Ladungen (ein Dokument am Bogen); der Protokolleintrag folgt danach. Die
/// Sprüche der neuen Ladungen sind vorbelegt und änderbar, denn Repräsentation,
/// Spontane Modifikation und ZfP* dürfen abweichen, der Thesiskern nicht.
Future<void> zeigeSpruchspeicherAufladen({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _SpruchspeicherAufladenDialog(heroId: heroId, eintrag: eintrag),
  );
}

class _SpruchspeicherAufladenDialog extends ConsumerStatefulWidget {
  const _SpruchspeicherAufladenDialog({
    required this.heroId,
    required this.eintrag,
  });

  final String heroId;
  final HeroInventoryEntry eintrag;

  @override
  ConsumerState<_SpruchspeicherAufladenDialog> createState() =>
      _SpruchspeicherAufladenDialogState();
}

class _SpruchspeicherAufladenDialogState
    extends ConsumerState<_SpruchspeicherAufladenDialog> {
  static final math.Random _zufall = math.Random();

  final _w20 = TextEditingController();
  late List<ArtefaktLadung> _neu = [
    for (final l
        in widget.eintrag.artefaktDaten?.ladungen ?? const <ArtefaktLadung>[])
      l.copyWith(verbraucht: false),
  ];
  bool _vonHand = false;
  bool _laeuft = false;
  int? _wurf;
  bool? _fertigBeschaedigt;
  String? _fehler;
  String? _protokollFehler;

  @override
  void dispose() {
    _w20.dispose();
    super.dispose();
  }

  // Würfelt oder liest den Handwert; `null` bei einem Wert außerhalb 1–20.
  int? _bestimmeWurf() {
    if (!_vonHand) {
      return _zufall.nextInt(20) + 1;
    }
    final wert = int.tryParse(_w20.text.trim());
    return wert != null && wert >= 1 && wert <= 20 ? wert : null;
  }

  void _wuerfeln() {
    final wurf = _bestimmeWurf();
    setState(() {
      if (wurf == null) {
        _fehler = 'Der eingetragene Wurf liegt außerhalb des Bereichs 1–20.';
        _wurf = null;
      } else {
        _fehler = null;
        _wurf = wurf;
      }
    });
  }

  Future<void> _uebernehmen(ArtefaktDaten daten) async {
    final wurf = _wurf;
    if (_laeuft || wurf == null) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
      _protokollFehler = null;
    });
    try {
      // Gewürfelt und gebucht wird für den Stand, den der Dialog zeigt; hat ein
      // anderer Weg den Gegenstand inzwischen geändert, wirft die Änderung.
      final gespeichert = widget.eintrag;
      final aktuell = gespeichert.artefaktDaten;
      if (aktuell == null) {
        throw StateError('Der Gegenstand ist kein Artefakt mehr.');
      }
      final beschaedigt = aufladeBeschaedigt(
        fassung: aktuell.regelfassung,
        aufladungen: aktuell.aufladungen,
        w20: wurf,
      );
      final schadenAb = aufladeSchadenAb(
        aktuell.regelfassung,
        aktuell.aufladungen,
      );
      await aendereHeldImEditor(
        ref: ref,
        heroId: widget.heroId,
        aenderung: (held) => beschaedigt
            ? mitBeschaedigtemArtefakt(held, gespeichert)
            : mitAufgeladenemSpeicher(held, gespeichert, _neu),
      );
      if (!mounted) return;
      setState(() => _fertigBeschaedigt = beschaedigt);
      try {
        await ref
            .read(artefaktProtokollierenProvider)
            .protokolliere(
              heroId: widget.heroId,
              baue: (jetzt) => baueAufladeProtokoll(
                artefaktName: gespeichert.gegenstand,
                w20: wurf,
                schadenAb: schadenAb,
                beschaedigt: beschaedigt,
                zeitpunkt: jetzt,
              ),
            );
      } catch (error) {
        if (mounted) {
          setState(
            () => _protokollFehler = error is StateError
                ? error.message
                : '$error',
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _fehler = error is StateError ? error.message : '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daten = widget.eintrag.artefaktDaten;
    final name = widget.eintrag.gegenstand.isEmpty
        ? 'Spruchspeicher'
        : widget.eintrag.gegenstand;
    if (daten == null) {
      return AlertDialog(
        title: Text(name),
        content: const Text('Der Gegenstand hat keine Artefaktdaten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      );
    }
    final fertig = _fertigBeschaedigt;
    final pruefung = pruefeAufladung(daten: daten, neu: _neu);
    final wurf = _wurf;
    return AlertDialog(
      title: Text('$name aufladen'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: fertig != null
              ? _buildErgebnis(context, fertig)
              : _buildEingabe(context, daten, pruefung),
        ),
      ),
      actions: fertig != null
          ? [
              FilledButton(
                key: const ValueKey<String>(
                  'spruchspeicher-aufladen-schliessen',
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ]
          : [
              TextButton(
                onPressed: _laeuft ? null : () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              if (wurf == null)
                FilledButton(
                  key: const ValueKey<String>(
                    'spruchspeicher-aufladen-wuerfeln',
                  ),
                  onPressed: _laeuft || !pruefung.moeglich ? null : _wuerfeln,
                  child: const Text('Haltematrix prüfen'),
                )
              else
                FilledButton(
                  key: const ValueKey<String>(
                    'spruchspeicher-aufladen-uebernehmen',
                  ),
                  onPressed: _laeuft || !pruefung.moeglich
                      ? null
                      : () => _uebernehmen(daten),
                  child: const Text('Übernehmen'),
                ),
            ],
    );
  }

  Widget _buildEingabe(
    BuildContext context,
    ArtefaktDaten daten,
    SpruchspeicherPruefung pruefung,
  ) {
    final texte = Theme.of(context).textTheme;
    final schadenAb = aufladeSchadenAb(daten.regelfassung, daten.aufladungen);
    final wurf = _wurf;
    final beschaedigt = wurf != null && wurf >= schadenAb;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sind alle Ladungen verbraucht, lässt sich ein aufladbarer '
          'Spruchspeicher mit Sprüchen desselben Thesiskerns neu laden. '
          'Zuerst wird auf die Haltematrix gewürfelt. Ein erneuter ARCANOVI '
          'oder permanente AsP sind nicht nötig.',
          style: texte.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Haltematrix beschädigt ab W20 $schadenAb '
          '(${matrixRegelfassungLabel(daten.regelfassung)}, '
          '${daten.aufladungen} bisherige Aufladung'
          '${daten.aufladungen == 1 ? '' : 'en'}).',
          key: const ValueKey<String>('spruchspeicher-aufladen-schwelle'),
          style: texte.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Ein anderer Zauberer als der Ersteller braucht eine Abschrift der '
          'Thesis oder muss den Gegenstand mit ANALYS entschlüsselt haben. Die '
          'Sprüche müssen binnen eines Tages (Sonnenaufgang bis Sonnenaufgang) '
          'eingewirkt werden, sonst verflüchtigt sich die Kraft.',
          style: texte.bodySmall,
        ),
        const SizedBox(height: 12),
        ArtefaktLadungenEditor(
          keyPraefix: 'spruchspeicher-aufladen',
          zeigeVerbraucht: false,
          ladungen: _neu,
          onChanged: (l) => setState(() {
            _neu = l;
            _wurf = null;
          }),
        ),
        for (final hinweis in [
          if (pruefung.sperrgrund != null) pruefung.sperrgrund!,
          ...pruefung.hinweise,
        ])
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hinweis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        SwitchListTile.adaptive(
          key: const ValueKey<String>('spruchspeicher-aufladen-von-hand'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _vonHand,
          onChanged: (v) => setState(() {
            _vonHand = v;
            _wurf = null;
          }),
          title: const Text('Würfelwurf von Hand eintragen'),
        ),
        if (_vonHand)
          SizedBox(
            width: 140,
            child: TextField(
              key: const ValueKey<String>('spruchspeicher-aufladen-w20'),
              controller: _w20,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() => _wurf = null),
              decoration: const InputDecoration(
                labelText: 'W20 Haltematrix',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        if (wurf != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              beschaedigt
                  ? 'W20 $wurf: Die Zaubermatrix ist irreparabel beschädigt. '
                        'Übernehmen vermerkt das am Gegenstand; neu geladen '
                        'wird nicht.'
                  : 'W20 $wurf: Die Haltematrix ist unversehrt. Übernehmen '
                        'lädt den Spruchspeicher neu.',
              key: const ValueKey<String>('spruchspeicher-aufladen-ausgang'),
              style: texte.titleSmall,
            ),
          ),
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('spruchspeicher-aufladen-fehler'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildErgebnis(BuildContext context, bool beschaedigt) {
    final texte = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          beschaedigt
              ? 'Der Gegenstand ist als irreparabel beschädigt vermerkt.'
              : 'Der Spruchspeicher ist neu geladen.',
          key: const ValueKey<String>('spruchspeicher-aufladen-gebucht'),
          style: texte.titleSmall,
        ),
        if (_protokollFehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Der Bogen ist gespeichert, aber der Protokolleintrag konnte '
              'nicht gespeichert werden: $_protokollFehler',
              key: const ValueKey<String>(
                'spruchspeicher-aufladen-protokollfehler',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
