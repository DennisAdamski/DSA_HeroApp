import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/artefakt_protokollieren.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_ladung_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_zauber_liste_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_karte.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Öffnet den Auslösedialog eines ladungsbasierten Spruchspeichers.
///
/// Der Anwender wählt eine freie Ladung und das Ziel; Wirkung, ZfP*,
/// Reichweite und Dauer stehen im Artefakt fest. Es gibt keine Zauberdauer,
/// keine AsP-Kosten und keine Zauberprobe, und der Anwender muss nicht
/// zauberkundig sein. Der Dialog markiert die Ladung am Bogen als verbraucht
/// (ein Dokument); der Protokolleintrag folgt danach als eigene Buchung.
Future<void> zeigeSpruchspeicherAusloesen({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        _SpruchspeicherAusloesenDialog(heroId: heroId, eintrag: eintrag),
  );
}

class _SpruchspeicherAusloesenDialog extends ConsumerStatefulWidget {
  const _SpruchspeicherAusloesenDialog({
    required this.heroId,
    required this.eintrag,
  });

  final String heroId;
  final HeroInventoryEntry eintrag;

  @override
  ConsumerState<_SpruchspeicherAusloesenDialog> createState() =>
      _SpruchspeicherAusloesenDialogState();
}

class _SpruchspeicherAusloesenDialogState
    extends ConsumerState<_SpruchspeicherAusloesenDialog> {
  final _ziel = TextEditingController();
  String? _ladungId;
  bool _laeuft = false;
  String? _fehler;
  String? _protokollFehler;
  ArtefaktLadung? _ausgeloest;
  ArtefaktDaten? _danach;

  @override
  void initState() {
    super.initState();
    final daten = widget.eintrag.artefaktDaten;
    final frei = daten == null
        ? const <ArtefaktLadung>[]
        : freieLadungen(daten);
    if (frei.isNotEmpty) {
      _ladungId = frei.first.id;
    }
  }

  @override
  void dispose() {
    _ziel.dispose();
    super.dispose();
  }

  Future<void> _ausloesen() async {
    final ladungId = _ladungId;
    if (_laeuft || ladungId == null) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
      _protokollFehler = null;
    });
    try {
      // Ausgelöst wird für den Stand, den der Dialog zeigt; hat ein anderer
      // Weg den Gegenstand inzwischen geändert, wirft die Änderung.
      final gespeichert = widget.eintrag;
      final daten = gespeichert.artefaktDaten;
      if (daten == null) {
        throw StateError('Der Gegenstand ist kein Artefakt mehr.');
      }
      final pruefung = pruefeSpruchspeicherAusloesung(daten);
      if (!pruefung.moeglich) {
        throw StateError(pruefung.sperrgrund!);
      }
      final ladung = daten.ladungen.where((l) => l.id == ladungId).firstOrNull;
      if (ladung == null || ladung.verbraucht) {
        throw StateError('Die gewählte Ladung ist nicht mehr frei.');
      }
      final neuerHeld = await aendereHeldImEditor(
        ref: ref,
        heroId: widget.heroId,
        aenderung: (aktuell) =>
            mitVerbrauchterLadung(aktuell, gespeichert, ladungId),
      );
      final danach = neuerHeld.inventoryEntries
          .where(
            (e) => e.instanzId != null && e.instanzId == gespeichert.instanzId,
          )
          .firstOrNull
          ?.artefaktDaten;
      if (!mounted) return;
      setState(() {
        _ausgeloest = ladung;
        _danach = danach ?? daten;
      });
      await _protokolliere(gespeichert, ladung, daten);
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

  // Das Protokoll ist eine eigene Buchung nach der Bogenänderung: scheitert
  // sie, bleibt die Ladung verbraucht und der Fehler wird genannt.
  Future<void> _protokolliere(
    HeroInventoryEntry gespeichert,
    ArtefaktLadung ladung,
    ArtefaktDaten daten,
  ) async {
    final ziel = _ziel.text;
    try {
      await ref
          .read(artefaktProtokollierenProvider)
          .protokolliere(
            heroId: widget.heroId,
            baue: (jetzt) => baueSpruchspeicherProtokoll(
              artefaktName: gespeichert.gegenstand,
              ladung: ladung,
              daten: daten.copyWith(
                ladungen: [
                  for (final l in daten.ladungen)
                    l.id == ladung.id ? l.copyWith(verbraucht: true) : l,
                ],
              ),
              ziel: ziel,
              zeitpunkt: jetzt,
            ),
          );
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _protokollFehler = error is StateError ? error.message : '$error',
        );
      }
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
    final ausgeloest = _ausgeloest;
    return AlertDialog(
      title: Text('$name auslösen'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: ausgeloest == null
              ? _buildEingabe(context, daten)
              : _buildErgebnis(context, ausgeloest),
        ),
      ),
      actions: ausgeloest == null
          ? [
              TextButton(
                onPressed: _laeuft ? null : () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                key: const ValueKey<String>(
                  'spruchspeicher-ausloesen-bestaetigen',
                ),
                onPressed:
                    _laeuft ||
                        _ladungId == null ||
                        !pruefeSpruchspeicherAusloesung(daten).moeglich
                    ? null
                    : _ausloesen,
                child: const Text('Auslösen'),
              ),
            ]
          : [
              FilledButton(
                key: const ValueKey<String>(
                  'spruchspeicher-ausloesen-schliessen',
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ],
    );
  }

  Widget _buildEingabe(BuildContext context, ArtefaktDaten daten) {
    final texte = Theme.of(context).textTheme;
    final pruefung = pruefeSpruchspeicherAusloesung(daten);
    final frei = freieLadungen(daten);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Die Wirkung tritt sofort ein: keine Zauberdauer, keine AsP-Kosten, '
          'und der Anwender muss nicht zauberkundig sein. Der Zauber gilt mit '
          'den gespeicherten Werten; nur das Ziel wählt der Anwender.',
          style: texte.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          spruchspeicherLadungenText(daten),
          key: const ValueKey<String>('spruchspeicher-ausloesen-status'),
          style: texte.titleSmall,
        ),
        if (daten.ausloeser.isNotEmpty)
          Text(
            'Auslöser: ${daten.ausloeser} (${daten.ausloeserAktionen} '
            'Aktion${daten.ausloeserAktionen == 1 ? '' : 'en'})',
            style: texte.bodySmall,
          ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _ladungId,
          onChanged: (v) => setState(() => _ladungId = v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final ladung in frei)
                RadioListTile<String>(
                  key: ValueKey<String>(
                    'spruchspeicher-ausloesen-ladung-${daten.ladungen.indexOf(ladung)}',
                  ),
                  value: ladung.id,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Ladung ${daten.ladungen.indexOf(ladung) + 1}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ladung.zauber.isEmpty) const Text('Kein Zauber.'),
                      for (final z in ladung.zauber)
                        ArtefaktZauberKarte(zauber: z),
                    ],
                  ),
                ),
            ],
          ),
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
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('spruchspeicher-ausloesen-ziel'),
          controller: _ziel,
          decoration: const InputDecoration(
            labelText: 'Ziel (nur fürs Protokoll)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('spruchspeicher-ausloesen-fehler'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildErgebnis(BuildContext context, ArtefaktLadung ladung) {
    final texte = Theme.of(context).textTheme;
    final danach = _danach;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ladung ausgelöst.',
          key: const ValueKey<String>('spruchspeicher-ausloesen-gebucht'),
          style: texte.titleSmall,
        ),
        if (danach != null)
          Text(
            spruchspeicherLadungenText(danach),
            key: const ValueKey<String>('spruchspeicher-ausloesen-rest'),
            style: texte.bodySmall,
          ),
        if (danach != null && spruchspeicherErloschen(danach))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Der einmalige Spruchspeicher hat damit jede magische Wirkung '
              'verloren.',
              key: const ValueKey<String>('spruchspeicher-ausloesen-erloschen'),
              style: texte.bodySmall,
            ),
          ),
        if (danach != null && spruchspeicherAufladbarLeer(danach))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Alle Ladungen sind verbraucht. Der Spruchspeicher lässt sich '
              'jetzt wieder aufladen.',
              style: texte.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (final z in ladung.zauber) ArtefaktZauberKarte(zauber: z),
        Text(
          'Die Wirkung gilt mit den gespeicherten Werten. Laufende '
          'Zaubereffekte pflegst du bei Bedarf im Magie-Tab.',
          style: texte.bodySmall,
        ),
        if (_protokollFehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Die Ladung ist verbraucht, aber der Protokolleintrag konnte '
              'nicht gespeichert werden: $_protokollFehler',
              key: const ValueKey<String>(
                'spruchspeicher-ausloesen-protokollfehler',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
