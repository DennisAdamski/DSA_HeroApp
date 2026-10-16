import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/artefakt_protokollieren.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_intervall_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_ladung_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_spruchspeicher_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_zauber_liste_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/aventurian_age_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_karte.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Öffnet den Auslösedialog eines Spruchspeichers.
///
/// Bei einem ladungsbasierten Speicher wählt der Anwender eine freie Ladung,
/// bei einem semipermanenten löst er eine Anwendung im Intervall aus; dazu
/// kommt das Ziel. Wirkung, ZfP*, Reichweite und Dauer stehen im Artefakt
/// fest. Es gibt keine Zauberdauer, keine AsP-Kosten und keine Zauberprobe,
/// und der Anwender muss nicht zauberkundig sein. Der Dialog schreibt die
/// Ladung bzw. Anwendung am Bogen (ein Dokument); der Protokolleintrag folgt
/// danach als eigene Buchung. Das Intervall eines semipermanenten Speichers
/// ist nur eine Anzeige und sperrt nie.
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
  // Der Stand des Gegenstands, auf dem der Dialog arbeitet; nach einer
  // Buchung der gespeicherte.
  late HeroInventoryEntry _eintrag = widget.eintrag;
  String? _ladungId;
  bool _laeuft = false;
  String? _fehler;
  String? _protokollFehler;
  List<ArtefaktZauber>? _ausgeloest;
  ArtefaktDaten? _danach;
  AventurianDate? _datumDerBuchung;

  ArtefaktDaten? get _daten => _eintrag.artefaktDaten;
  bool get _semi => _daten?.art == ArtefaktArt.spruchspeicherSemipermanent;

  @override
  void initState() {
    super.initState();
    final daten = _daten;
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

  // Der gespeicherte Stand des Gegenstands im Helden [held].
  HeroInventoryEntry? _gespeicherterEintrag(HeroSheet held) {
    final id = _eintrag.instanzId;
    if (id == null) return null;
    return held.inventoryEntries.where((e) => e.instanzId == id).firstOrNull;
  }

  Future<void> _ausloesen() async {
    final ladungId = _ladungId;
    if (_laeuft || (!_semi && ladungId == null)) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
      _protokollFehler = null;
    });
    try {
      // Ausgelöst wird für den Stand, den der Dialog zeigt; hat ein anderer
      // Weg den Gegenstand inzwischen geändert, wirft die Änderung.
      final gespeichert = _eintrag;
      final daten = gespeichert.artefaktDaten;
      if (daten == null) {
        throw StateError('Der Gegenstand ist kein Artefakt mehr.');
      }
      final pruefung = pruefeSpruchspeicherAusloesung(daten);
      if (!pruefung.moeglich) {
        throw StateError(pruefung.sperrgrund!);
      }
      final List<ArtefaktZauber> zauber;
      if (_semi) {
        zauber = daten.zauber;
      } else {
        final ladung = daten.ladungen
            .where((l) => l.id == ladungId)
            .firstOrNull;
        if (ladung == null || ladung.verbraucht) {
          throw StateError('Die gewählte Ladung ist nicht mehr frei.');
        }
        zauber = ladung.zauber;
      }
      final neuerHeld = await aendereHeldImEditor(
        ref: ref,
        heroId: widget.heroId,
        aenderung: (aktuell) => _semi
            ? mitVermerkterAnwendung(aktuell, gespeichert)
            : mitVerbrauchterLadung(aktuell, gespeichert, ladungId!),
      );
      final danach = _gespeicherterEintrag(neuerHeld)?.artefaktDaten ?? daten;
      final datum = resolveCurrentAdventureDate(neuerHeld);
      if (!mounted) return;
      setState(() {
        _ausgeloest = zauber;
        _danach = danach;
        _datumDerBuchung = datum;
      });
      await _protokolliere(gespeichert, zauber, danach, datum);
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

  // Der Vorgang im Protokoll: Stand der Ladungen bzw. des Intervalls nach
  // der Buchung.
  String _vorgang(ArtefaktDaten danach, AventurianDate? datum) {
    if (danach.art == ArtefaktArt.spruchspeicherSemipermanent) {
      final status = intervallStatus(danach, datum);
      return 'Anwendung (${intervallStatusText(danach, status)})';
    }
    final frei = freieLadungen(danach).length;
    return 'Ladung ausgelöst ($frei von ${danach.ladungen.length} frei)';
  }

  // Das Protokoll ist eine eigene Buchung nach der Bogenänderung: scheitert
  // sie, bleibt die Buchung am Bogen bestehen und der Fehler wird genannt.
  Future<void> _protokolliere(
    HeroInventoryEntry gespeichert,
    List<ArtefaktZauber> zauber,
    ArtefaktDaten danach,
    AventurianDate? datum,
  ) async {
    final ziel = _ziel.text;
    try {
      await ref
          .read(artefaktProtokollierenProvider)
          .protokolliere(
            heroId: widget.heroId,
            baue: (jetzt) => baueSpruchspeicherProtokoll(
              artefaktName: gespeichert.gegenstand,
              zauber: zauber,
              vorgang: _vorgang(danach, datum),
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

  // Vermerkt, dass der semipermanente Speicher seine Matrizen regeneriert hat.
  Future<void> _regeneriert() async {
    if (_laeuft) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
      final gespeichert = _eintrag;
      final neuerHeld = await aendereHeldImEditor(
        ref: ref,
        heroId: widget.heroId,
        aenderung: (aktuell) => mitRegenerierterMatrix(aktuell, gespeichert),
      );
      final neu = _gespeicherterEintrag(neuerHeld);
      if (!mounted) return;
      setState(() {
        if (neu != null) {
          _eintrag = neu;
        } else {
          _fehler =
              'Der Gegenstand lässt sich nicht wiederfinden. Bitte den '
              'Dialog neu öffnen.';
        }
      });
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
    final daten = _daten;
    final name = _eintrag.gegenstand.isEmpty
        ? 'Spruchspeicher'
        : _eintrag.gegenstand;
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
    final hero = ref.watch(heroComputedProvider(widget.heroId)).asData?.value;
    final heute = hero == null ? null : resolveCurrentAdventureDate(hero.hero);
    final ausgeloest = _ausgeloest;
    return AlertDialog(
      title: Text('$name auslösen'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: ausgeloest == null
              ? _buildEingabe(context, daten, heute)
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
                        (!_semi && _ladungId == null) ||
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

  Widget _buildEingabe(
    BuildContext context,
    ArtefaktDaten daten,
    AventurianDate? heute,
  ) {
    final texte = Theme.of(context).textTheme;
    final status = _semi ? intervallStatus(daten, heute) : null;
    final pruefung = pruefeSpruchspeicherAusloesung(
      daten,
      intervallHinweis: status != null && !status.istFrei
          ? 'Alle ${status.erlaubt} Anwendung'
                '${status.erlaubt == 1 ? '' : 'en'} je '
                '${artefaktIntervallLabel(daten.intervall)} sind verbraucht'
                '${status.fruehestensWieder == null ? '' : ', frühestens wieder am ${formatAventurianDate(status.fruehestensWieder!)}'}. '
                'Die App sperrt nicht; der Spielleiter entscheidet.'
          : null,
    );
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
          status != null
              ? intervallStatusText(daten, status)
              : spruchspeicherLadungenText(daten),
          key: const ValueKey<String>('spruchspeicher-ausloesen-status'),
          style: texte.titleSmall,
        ),
        if (status != null && daten.anwendungen.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey<String>(
                'spruchspeicher-ausloesen-regeneriert',
              ),
              onPressed: _laeuft ? null : _regeneriert,
              child: const Text('Matrizen regeneriert'),
            ),
          ),
        if (daten.ausloeser.isNotEmpty)
          Text(
            'Auslöser: ${daten.ausloeser} (${daten.ausloeserAktionen} '
            'Aktion${daten.ausloeserAktionen == 1 ? '' : 'en'})',
            style: texte.bodySmall,
          ),
        const SizedBox(height: 8),
        if (_semi) ...[
          if (daten.zauber.isEmpty) const Text('Kein Zauber hinterlegt.'),
          for (final z in daten.zauber) ArtefaktZauberKarte(zauber: z),
        ] else
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

  Widget _buildErgebnis(BuildContext context, List<ArtefaktZauber> zauber) {
    final texte = Theme.of(context).textTheme;
    final danach = _danach;
    final semi = danach?.art == ArtefaktArt.spruchspeicherSemipermanent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          semi ? 'Anwendung vermerkt.' : 'Ladung ausgelöst.',
          key: const ValueKey<String>('spruchspeicher-ausloesen-gebucht'),
          style: texte.titleSmall,
        ),
        if (danach != null)
          Text(
            semi
                ? intervallStatusText(
                    danach,
                    intervallStatus(danach, _datumDerBuchung),
                  )
                : spruchspeicherLadungenText(danach),
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
        if (semi && _datumDerBuchung == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Der Held hat kein aventurisches Datum. Die Anwendung ist ohne '
              'Datum vermerkt und verfällt erst mit „Matrizen regeneriert“.',
              key: const ValueKey<String>(
                'spruchspeicher-ausloesen-ohne-datum',
              ),
              style: texte.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (final z in zauber) ArtefaktZauberKarte(zauber: z),
        Text(
          'Die Wirkung gilt mit den gespeicherten Werten. Laufende '
          'Zaubereffekte pflegst du bei Bedarf im Magie-Tab.',
          style: texte.bodySmall,
        ),
        if (_protokollFehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Der Bogen ist gespeichert, aber der Protokolleintrag konnte '
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
