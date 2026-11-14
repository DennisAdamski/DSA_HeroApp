import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tragkraft_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spiel_dabei_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_held_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Anzahl Verbrauchsgegenstände, die ohne „Alle zeigen“ sichtbar bleiben.
const int kDabeiSichtbar = 6;

/// Dasselbe in einer weiten Kachel (SPIEL-07): zwei Spalten à sechs Zeilen.
const int kDabeiSichtbarWeit = 12;

/// Kachelbreite, ab der die Verbrauchsgegenstände zweispaltig fließen.
const double kDabeiZweispaltigAb = 560;

/// Satz unter der Munition, solange ein Gefecht des Helden läuft.
const String kDabeiMunitionImGefecht =
    'Im laufenden Gefecht zählt das Gefecht die Munition.';

/// Block „Dabei“ der Spielansicht (SPIEL-02): Geld, Munition und
/// Verbrauchsgegenstände.
///
/// Zeigt den Geldstand mit Münzschritten, die Geschossbestände der
/// Fernkampfwaffen und die Verbrauchsgegenstände des Inventars mit +/−. Jeder
/// Klick schreibt **frisch**: den gespeicherten Helden laden, nur den
/// Geldstand, den Bestand dieses Geschosses oder die Menge dieses einen
/// Eintrags ändern, speichern (`mitDukatenSchritt`, `mitMunitionsSchritt`,
/// `mitVerbrauchsmengenSchritt`). Munition zählt am Kampf-Slot; das Inventar
/// gleicht `updateHero` beim Speichern selbst ab. Solange ein Gefecht des
/// Helden läuft, gehört die Munition dem Gefecht (Ladezustand, Schuss) und
/// ist hier gesperrt. Die Schritte
/// reihen sich je Held ein, deshalb zählt auch ein schneller Doppelklick. Gesperrt
/// ist alles während einer offenen Planung. Der Block rechnet nichts selbst.
class KartoDabeiAbschnitt extends ConsumerStatefulWidget {
  /// Erstellt den Block für den Helden [heroId].
  const KartoDabeiAbschnitt({
    super.key,
    required this.heroId,
    required this.dukaten,
    required this.verbrauch,
    this.munition = const <DabeiMunition>[],
    this.begleiterVerbrauch = const <DabeiBegleiterVerbrauch>[],
    this.tragkraft,
    this.erschoepfung = 0,
    this.ueberanstrengung = 0,
    this.onBenutzen,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Gespeicherter Geldstand des Bogens (Freitext).
  final String dukaten;

  /// Verbrauchsgegenstände aus `dabeiVerbrauchsgegenstaende`.
  final List<HeroInventoryEntry> verbrauch;

  /// Geschossbestände aus `dabeiMunition`; leer heißt kein Abschnitt.
  final List<DabeiMunition> munition;

  /// Verbrauchsgegenstände, die Begleiter tragen, nach Begleiter gruppiert
  /// (`dabeiBegleiterVerbrauch`); leer heißt kein Abschnitt. Sie lassen sich
  /// zählen, aber nicht benutzen: Der Held hat sie nicht bei sich.
  final List<DabeiBegleiterVerbrauch> begleiterVerbrauch;

  /// Last und Tragkraft aus dem Regelmodul; ohne Wert entfällt „Belastung“.
  ///
  /// Die Tragkraftquellen (etwa die Bärenrune) pflegt der Inventar-Tab.
  final TragkraftErgebnis? tragkraft;

  /// Gespeicherte Erschöpfung (Laufzeitzustand).
  final int erschoepfung;

  /// Gespeicherte Überanstrengung (Laufzeitzustand).
  final int ueberanstrengung;

  /// Öffnet den Dialog zum Benutzen eines Tranks, Heilmittels oder Elixiers.
  ///
  /// Der Dialog bucht Wirkung und Verbrauch selbst und zeigt seine Fehler;
  /// dieser Block schreibt dabei nichts. Ohne Rückruf entfällt „Benutzen“.
  final Future<void> Function(HeroInventoryEntry eintrag)? onBenutzen;

  @override
  ConsumerState<KartoDabeiAbschnitt> createState() =>
      _KartoDabeiAbschnittState();
}

class _KartoDabeiAbschnittState extends ConsumerState<KartoDabeiAbschnitt>
    with KartoHeldSchreiben<KartoDabeiAbschnitt> {
  bool _alle = false;

  @override
  String get heroId => widget.heroId;

  @override
  String get planungsSperre => 'Während einer Planung ist „Dabei“ gesperrt.';

  // Bewusst ohne Sperre gegen Doppelklicks: jeder Klick soll zählen.
  Future<void> _schreibe(HeroSheet Function(HeroSheet held) aenderung) =>
      schreibeHeld(aenderung, einzeln: false, fehlerPraefix: '');

  // Erschöpfung und Überanstrengung liegen im Laufzeitzustand, nicht am
  // Bogen: frisch laden, nur das eigene Feld ändern, nie unter 0. Eine offene
  // Planung sperrt den Zustand nicht (wie im Zustandsblock).
  Future<void> _schreibeZustand(
    HeroState Function(HeroState aktuell) aenderung,
  ) async {
    setState(() => fehler = null);
    try {
      await ref
          .read(heroActionsProvider)
          .updateHeroState(widget.heroId, aenderung);
    } catch (error) {
      if (mounted) setState(() => fehler = schreibFehlerText(error));
    }
  }

  static int _ab0(int wert) => wert < 0 ? 0 : wert;

  Future<void> _betragAendern() async {
    final ergebnis = await showDialog<int>(
      context: context,
      builder: (_) => _BetragDialog(dukaten: widget.dukaten),
    );
    if (ergebnis == null || ergebnis == 0) return;
    await _schreibe((held) => mitDukatenSchritt(held, ergebnis));
  }

  @override
  Widget build(BuildContext context) {
    final gesperrt = this.gesperrt;
    final katalog = ref
        .watch(heroRulesCatalogProvider(widget.heroId))
        .valueOrNull;
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    // Die weite Kachel hat zwei Spalten und zeigt entsprechend mehr.
    final grenze = KartoKachelSteuerung.istWeit(context)
        ? kDabeiSichtbarWeit
        : kDabeiSichtbar;
    final sichtbar = _alle
        ? widget.verbrauch
        : widget.verbrauch.take(grenze).toList();
    final verborgen = widget.verbrauch.length - sichtbar.length;
    final imGefecht = ref.watch(gefechtProvider(widget.heroId)) != null;

    return KartoAbschnitt(
      titel: 'Dabei',
      symbol: Icons.backpack_outlined,
      dicht: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Geld(
            dukaten: widget.dukaten,
            gesperrt: gesperrt,
            onSchritt: (kreuzer) =>
                _schreibe((held) => mitDukatenSchritt(held, kreuzer)),
            onBetrag: _betragAendern,
          ),
          if (widget.munition.isNotEmpty) ...[
            const SizedBox(height: Abstand.weit),
            Text(
              'Munition',
              style: texte.marke.copyWith(color: karto.schriftLeise),
            ),
            const SizedBox(height: Abstand.eng),
            _Zeilen(
              children: [
                for (var i = 0; i < widget.munition.length; i++)
                  _Munitionszeile(
                    index: i,
                    munition: widget.munition[i],
                    gesperrt: gesperrt || imGefecht,
                    onSchritt: (delta) => _schreibe(
                      (held) =>
                          mitMunitionsSchritt(held, widget.munition[i], delta),
                    ),
                  ),
              ],
            ),
            if (imGefecht && !gesperrt)
              Padding(
                padding: const EdgeInsets.only(top: Abstand.eng),
                child: Text(
                  kDabeiMunitionImGefecht,
                  key: const ValueKey<String>('karto-dabei-munition-gefecht'),
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                ),
              ),
          ],
          const SizedBox(height: Abstand.weit),
          Text(
            'Verbrauchsgegenstände',
            style: texte.marke.copyWith(color: karto.schriftLeise),
          ),
          const SizedBox(height: Abstand.eng),
          if (widget.verbrauch.isEmpty)
            Text(
              'Keine Verbrauchsgegenstände im Inventar.',
              key: const ValueKey<String>('karto-dabei-leer'),
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            )
          else
            _Zeilen(
              children: [
                for (var i = 0; i < sichtbar.length; i++)
                  _Verbrauchszeile(
                    index: i,
                    eintrag: sichtbar[i],
                    gesperrt: gesperrt,
                    onSchritt: (delta) => _schreibe(
                      (held) =>
                          mitVerbrauchsmengenSchritt(held, sichtbar[i], delta),
                    ),
                    onBenutzen:
                        widget.onBenutzen != null &&
                            dabeiBenutzbar(
                              catalog: katalog,
                              eintrag: sichtbar[i],
                            )
                        ? () => widget.onBenutzen!(sichtbar[i])
                        : null,
                  ),
              ],
            ),
          if (widget.verbrauch.length > grenze)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey<String>('karto-dabei-alle'),
                onPressed: () => setState(() => _alle = !_alle),
                child: Text(
                  _alle ? 'Weniger zeigen' : 'Alle zeigen ($verborgen weitere)',
                ),
              ),
            ),
          for (var g = 0; g < widget.begleiterVerbrauch.length; g++) ...[
            const SizedBox(height: Abstand.weit),
            Text(
              'Beim Begleiter: ${widget.begleiterVerbrauch[g].name}',
              key: ValueKey<String>('karto-dabei-begleiter-$g'),
              style: texte.marke.copyWith(color: karto.schriftLeise),
            ),
            const SizedBox(height: Abstand.eng),
            _Zeilen(
              children: [
                for (
                  var i = 0;
                  i < widget.begleiterVerbrauch[g].eintraege.length;
                  i++
                )
                  _Verbrauchszeile(
                    index: i,
                    schluessel: 'karto-dabei-begleiter-$g-$i',
                    eintrag: widget.begleiterVerbrauch[g].eintraege[i],
                    gesperrt: gesperrt,
                    onSchritt: (delta) => _schreibe(
                      (held) => mitVerbrauchsmengenSchritt(
                        held,
                        widget.begleiterVerbrauch[g].eintraege[i],
                        delta,
                      ),
                    ),
                    onBenutzen: null,
                  ),
              ],
            ),
          ],
          if (widget.tragkraft != null) ...[
            const SizedBox(height: Abstand.weit),
            _Belastung(
              tragkraft: widget.tragkraft!,
              erschoepfung: widget.erschoepfung,
              ueberanstrengung: widget.ueberanstrengung,
              onErschoepfung: (delta) => _schreibeZustand(
                (z) => z.copyWith(erschoepfung: _ab0(z.erschoepfung + delta)),
              ),
              onUeberanstrengung: (delta) => _schreibeZustand(
                (z) => z.copyWith(
                  ueberanstrengung: _ab0(z.ueberanstrengung + delta),
                ),
              ),
            ),
          ],
          if (gesperrt) ...[
            const SizedBox(height: Abstand.normal),
            Text(
              planungsSperre,
              key: const ValueKey<String>('karto-dabei-gesperrt'),
              style: texte.etikett.copyWith(color: karto.schriftLeise),
            ),
          ],
          if (fehler != null) ...[
            const SizedBox(height: Abstand.normal),
            Text(
              fehler!,
              key: const ValueKey<String>('karto-dabei-fehler'),
              style: texte.etikett.copyWith(color: karto.siegel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Geldstand mit Münzschritten für Dukaten, Silbertaler und Kreuzer.
class _Geld extends StatelessWidget {
  const _Geld({
    required this.dukaten,
    required this.gesperrt,
    required this.onSchritt,
    required this.onBetrag,
  });

  final String dukaten;
  final bool gesperrt;
  final void Function(int kreuzer) onSchritt;
  final VoidCallback onBetrag;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final text = dabeiGeldText(dukaten);
    final lesbar = text != null;

    Widget muenze(String kuerzel, String name, int wert) {
      final kann = !gesperrt && lesbar;
      return _Schritt(
        schluessel: 'karto-dabei-geld-${kuerzel.toLowerCase()}',
        beschriftung: kuerzel,
        minusTipp: '1 $name abziehen',
        plusTipp: '1 $name hinzufügen',
        // Abziehen erst, wenn genug da ist; der Ablauf prüft es noch einmal
        // gegen den gespeicherten Stand.
        onMinus: kann && dabeiKannAbziehen(dukaten, wert)
            ? () => onSchritt(-wert)
            : null,
        onPlus: kann ? () => onSchritt(wert) : null,
      );
    }

    // Betrag, Stift und Münzschritte stehen beieinander und brechen erst
    // um, wenn die Kachel schmal ist; kein leerer Raum dazwischen.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: Abstand.weit,
          runSpacing: Abstand.eng,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Geld',
              style: texte.marke.copyWith(color: karto.schriftLeise),
            ),
            InkWell(
              key: const ValueKey<String>('karto-dabei-geld'),
              onTap: gesperrt || !lesbar ? null : onBetrag,
              borderRadius: BorderRadius.circular(kKartoRadiusKlein),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        lesbar ? text : dukaten.trim(),
                        key: const ValueKey<String>('karto-dabei-geld-wert'),
                        style: texte.wert.copyWith(color: karto.schrift),
                      ),
                    ),
                    if (!gesperrt && lesbar) ...[
                      const SizedBox(width: Abstand.knapp),
                      Tooltip(
                        message: 'Betrag hinzufügen oder abziehen',
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: karto.meer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: Abstand.normal,
              runSpacing: Abstand.eng,
              children: [
                muenze('D', 'Dukat', dsaKreuzerPerDukat),
                muenze('S', 'Silbertaler', dsaKreuzerPerSilber),
                muenze('K', 'Kreuzer', 1),
              ],
            ),
          ],
        ),
        if (!lesbar)
          Padding(
            padding: const EdgeInsets.only(top: Abstand.eng),
            child: Text(
              'Der Geldstand ist kein Betrag. Im Inventar korrigieren.',
              key: const ValueKey<String>('karto-dabei-geld-unlesbar'),
              style: texte.etikett.copyWith(color: karto.siegel),
            ),
          ),
      ],
    );
  }
}

/// Mindestbreite einer Zelle für Erschöpfung oder Überanstrengung.
const double kDabeiStufenZelleMin = 120;

/// Abschnitt „Belastung“: eine Zeile Last gegen Tragkraft, darunter
/// Erschöpfung und Überanstrengung, nebeneinander, sofern Platz ist.
///
/// Zeigt nur an, was das Regelmodul liefert (`berechneTragkraft`). Die
/// Herleitung der Tragkraft, die volle Folge einer Überschreitung und der
/// Hinweis auf Einträge ohne Gewicht stehen im Tooltip der Lastzeile; die
/// Tragkraftquellen pflegt der Inventar-Tab. Die Schreibwege liegen beim
/// Block.
class _Belastung extends StatelessWidget {
  const _Belastung({
    required this.tragkraft,
    required this.erschoepfung,
    required this.ueberanstrengung,
    required this.onErschoepfung,
    required this.onUeberanstrengung,
  });

  final TragkraftErgebnis tragkraft;
  final int erschoepfung;
  final int ueberanstrengung;
  final void Function(int delta) onErschoepfung;
  final void Function(int delta) onUeberanstrengung;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final ueber = tragkraft.stufe != TragkraftStufe.frei;
    final hinweis = tragkraft.hinweis;
    final mindestens = tragkraft.ohneGewicht > 0;
    final tipp = [
      'Tragkraft ${tragkraftFormel(tragkraft.tragkraft)}',
      ?hinweis,
      if (mindestens)
        tragkraft.ohneGewicht == 1
            ? '1 getragener Eintrag hat kein Gewicht: die Last ist '
                  'mindestens so hoch.'
            : '${tragkraft.ohneGewicht} getragene Einträge haben kein '
                  'Gewicht: die Last ist mindestens so hoch.',
    ].join('\n');

    Widget stufe(
      String schluessel,
      String name,
      int wert,
      void Function(int delta) onSchritt,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: texte.etikett.copyWith(color: karto.schriftLeise),
          ),
          _MengeSchritt(
            schluessel: schluessel,
            menge: '$wert',
            name: name,
            onMinus: wert > 0 ? () => onSchritt(-1) : null,
            onPlus: () => onSchritt(1),
          ),
        ],
      );
    }

    final stufen = <Widget>[
      stufe(
        'karto-dabei-erschoepfung',
        'Erschöpfung',
        erschoepfung,
        onErschoepfung,
      ),
      stufe(
        'karto-dabei-ueberanstrengung',
        'Überanstrengung',
        ueberanstrengung,
        onUeberanstrengung,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tooltip(
          message: tipp,
          child: Wrap(
            spacing: Abstand.normal,
            runSpacing: Abstand.eng,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Belastung',
                style: texte.marke.copyWith(color: karto.schriftLeise),
              ),
              Text(
                '${mindestens ? '≥ ' : ''}'
                '${formatiereStein(tragkraft.lastGramm)} / '
                '${tragkraft.tragkraftStein} Stein',
                key: const ValueKey<String>('karto-dabei-last'),
                style: texte.wert.copyWith(
                  color: ueber ? karto.siegel : karto.schrift,
                ),
              ),
              if (ueber)
                Text(
                  'BE +${tragkraft.zusatzBe}',
                  key: const ValueKey<String>('karto-dabei-last-hinweis'),
                  style: texte.etikett.copyWith(color: karto.siegel),
                ),
            ],
          ),
        ),
        const SizedBox(height: Abstand.eng),
        LayoutBuilder(
          builder: (context, constraints) {
            final nebeneinander =
                constraints.maxWidth >= 2 * kDabeiStufenZelleMin + Abstand.weit;
            if (!nebeneinander) {
              return Column(
                key: const ValueKey<String>('karto-dabei-stufen'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  stufen[0],
                  const SizedBox(height: Abstand.eng),
                  stufen[1],
                ],
              );
            }
            return Row(
              key: const ValueKey<String>('karto-dabei-stufen-nebeneinander'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: stufen[0]),
                const SizedBox(width: Abstand.weit),
                Expanded(child: stufen[1]),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Zeilen des Blocks; auf breiter Kachel fließen sie in zwei Spalten, sonst
/// stünden Name und Knöpfe eine halbe Seite auseinander.
class _Zeilen extends StatelessWidget {
  const _Zeilen({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zweispaltig = constraints.maxWidth >= kDabeiZweispaltigAb;
        final zeilenbreite = zweispaltig
            ? (constraints.maxWidth - Abstand.bahn) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: Abstand.bahn,
          children: [
            for (final zeile in children)
              SizedBox(width: zeilenbreite, child: zeile),
          ],
        );
      },
    );
  }
}

/// Zeile eines Geschossbestands: Geschoss, Waffe, Bestand, − und +.
class _Munitionszeile extends StatelessWidget {
  const _Munitionszeile({
    required this.index,
    required this.munition,
    required this.gesperrt,
    required this.onSchritt,
  });

  final int index;
  final DabeiMunition munition;
  final bool gesperrt;
  final void Function(int delta) onSchritt;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final leer = !munition.kannAbziehen;
    return Padding(
      key: ValueKey<String>('karto-dabei-munition-$index'),
      padding: const EdgeInsets.only(top: Abstand.eng),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  munition.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: texte.fliess.copyWith(
                    color: leer ? karto.schriftStumm : karto.schrift,
                  ),
                ),
                Text(
                  munition.aktiv
                      ? '${munition.waffenName} · aktiv'
                      : munition.waffenName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                ),
              ],
            ),
          ),
          _MengeSchritt(
            schluessel: 'karto-dabei-munition-$index',
            menge: '${munition.anzahl}',
            name: '${munition.name} (${munition.waffenName})',
            onMinus: gesperrt || leer ? null : () => onSchritt(-1),
            onPlus: gesperrt || !munition.kannHinzufuegen
                ? null
                : () => onSchritt(1),
          ),
        ],
      ),
    );
  }
}

/// Zeile eines Verbrauchsgegenstands: Name, Menge, − und +.
class _Verbrauchszeile extends StatelessWidget {
  const _Verbrauchszeile({
    required this.index,
    this.schluessel,
    required this.eintrag,
    required this.gesperrt,
    required this.onSchritt,
    required this.onBenutzen,
  });

  final int index;

  /// Schlüssel-Präfix der Zeile; ohne Angabe `karto-dabei-<index>`.
  final String? schluessel;
  final HeroInventoryEntry eintrag;
  final bool gesperrt;
  final void Function(int delta) onSchritt;
  final VoidCallback? onBenutzen;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final aenderbar = !gesperrt && dabeiMengeAenderbar(eintrag);
    final menge = dabeiMengeText(eintrag);
    final aufgebraucht = menge == '0';
    return Padding(
      padding: const EdgeInsets.only(top: Abstand.eng),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dabeiName(eintrag),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: texte.fliess.copyWith(
                color: aufgebraucht ? karto.schriftStumm : karto.schrift,
              ),
            ),
          ),
          if (onBenutzen != null)
            Tooltip(
              message: '${dabeiName(eintrag)} benutzen',
              child: TextButton(
                key: ValueKey<String>(
                  '${schluessel ?? 'karto-dabei-$index'}-benutzen',
                ),
                onPressed: gesperrt || aufgebraucht ? null : onBenutzen,
                child: const Text('Benutzen'),
              ),
            ),
          _MengeSchritt(
            schluessel: schluessel ?? 'karto-dabei-$index',
            menge: menge,
            name: dabeiName(eintrag),
            onMinus: aenderbar && !aufgebraucht ? () => onSchritt(-1) : null,
            onPlus: aenderbar ? () => onSchritt(1) : null,
          ),
        ],
      ),
    );
  }
}

/// − Menge + für einen Verbrauchsgegenstand.
class _MengeSchritt extends StatelessWidget {
  const _MengeSchritt({
    required this.schluessel,
    required this.menge,
    required this.name,
    required this.onMinus,
    required this.onPlus,
  });

  final String schluessel;
  final String menge;
  final String name;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Knopf(
          key: ValueKey<String>('$schluessel-minus'),
          zeichen: '−',
          tipp: '$name: 1 weniger',
          onTap: onMinus,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 36),
          child: Text(
            menge,
            key: ValueKey<String>('$schluessel-menge'),
            textAlign: TextAlign.center,
            style: texte.wert.copyWith(color: karto.schrift),
          ),
        ),
        _Knopf(
          key: ValueKey<String>('$schluessel-plus'),
          zeichen: '+',
          tipp: '$name: 1 mehr',
          onTap: onPlus,
        ),
      ],
    );
  }
}

/// − D + für eine Münzsorte.
class _Schritt extends StatelessWidget {
  const _Schritt({
    required this.schluessel,
    required this.beschriftung,
    required this.minusTipp,
    required this.plusTipp,
    required this.onMinus,
    required this.onPlus,
  });

  final String schluessel;
  final String beschriftung;
  final String minusTipp;
  final String plusTipp;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: karto.senke,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Knopf(
            key: ValueKey<String>('$schluessel-minus'),
            zeichen: '−',
            tipp: minusTipp,
            onTap: onMinus,
          ),
          SizedBox(
            width: 20,
            child: Text(
              beschriftung,
              textAlign: TextAlign.center,
              style: texte.etikett.copyWith(color: karto.schriftLeise),
            ),
          ),
          _Knopf(
            key: ValueKey<String>('$schluessel-plus'),
            zeichen: '+',
            tipp: plusTipp,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

/// Tippziel von mindestens 40 × 40 dp; ohne [onTap] gedämpft und stumm.
class _Knopf extends StatelessWidget {
  const _Knopf({
    super.key,
    required this.zeichen,
    required this.tipp,
    required this.onTap,
  });

  final String zeichen;
  final String tipp;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Tooltip(
      message: tipp,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              zeichen,
              style: texte.wert.copyWith(
                color: onTap == null ? karto.schriftStumm : karto.schrift,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog „Betrag ändern“: ein Betrag, dazu Hinzufügen oder Abziehen.
///
/// Liefert die Kreuzerdifferenz (positiv zum Hinzufügen, negativ zum
/// Abziehen) oder nichts bei Abbruch. Er prüft nur die Lesbarkeit und den
/// Bestand der Anzeige; die endgültige Prüfung läuft beim Schreiben gegen den
/// gespeicherten Stand.
class _BetragDialog extends StatefulWidget {
  const _BetragDialog({required this.dukaten});

  final String dukaten;

  @override
  State<_BetragDialog> createState() => _BetragDialogState();
}

class _BetragDialogState extends State<_BetragDialog> {
  final TextEditingController _text = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _uebernehmen({required bool abziehen}) {
    final betrag = dabeiBetragKreuzer(_text.text);
    if (betrag == null) {
      setState(
        () =>
            _fehler = 'Bitte einen Betrag wie „12 D 5 S“ oder „12,5“ eingeben.',
      );
      return;
    }
    if (abziehen && !dabeiKannAbziehen(widget.dukaten, betrag)) {
      setState(
        () => _fehler = 'Nicht genug Geld: ${dabeiGeldText(widget.dukaten)}.',
      );
      return;
    }
    Navigator.of(context).pop(abziehen ? -betrag : betrag);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Betrag ändern'),
      content: SizedBox(
        width: Breite.klein,
        child: TextField(
          key: const ValueKey<String>('karto-dabei-betrag'),
          controller: _text,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Betrag',
            hintText: 'z. B. 12 D 5 S oder 12,5',
            helperText: 'Vorhanden: ${dabeiGeldText(widget.dukaten) ?? '–'}',
            errorText: _fehler,
          ),
          onChanged: (_) {
            if (_fehler != null) setState(() => _fehler = null);
          },
          onSubmitted: (_) => _uebernehmen(abziehen: false),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          key: const ValueKey<String>('karto-dabei-abziehen'),
          onPressed: () => _uebernehmen(abziehen: true),
          child: const Text('Abziehen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-dabei-hinzufuegen'),
          onPressed: () => _uebernehmen(abziehen: false),
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
