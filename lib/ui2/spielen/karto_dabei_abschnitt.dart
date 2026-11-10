import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_tragkraft_bonus.dart';
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
import 'package:uuid/uuid.dart';

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
    this.tragkraft,
    this.tragkraftBoni = const <HeroTragkraftBonus>[],
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

  /// Last und Tragkraft aus dem Regelmodul; ohne Wert entfällt „Belastung“.
  final TragkraftErgebnis? tragkraft;

  /// Dauerhafte Tragkraftquellen des Helden (z. B. Bärenrune).
  final List<HeroTragkraftBonus> tragkraftBoni;

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

  Future<void> _baerenruneHinzufuegen() async {
    final ergebnis = await showDialog<({int rkp, bool kk})>(
      context: context,
      builder: (_) => const _BaerenruneDialog(),
    );
    if (ergebnis == null) return;
    final bonus = baerenruneBonus(
      id: const Uuid().v4(),
      rkp: ergebnis.rkp,
      hausregelKk: ergebnis.kk,
    );
    await _schreibe((held) => mitTragkraftBonus(held, bonus));
  }

  Future<void> _quelleHinzufuegen() async {
    final ergebnis = await showDialog<HeroTragkraftBonus>(
      context: context,
      builder: (_) => const _QuelleDialog(),
    );
    if (ergebnis == null) return;
    final bonus = ergebnis.copyWith(id: const Uuid().v4());
    await _schreibe((held) => mitTragkraftBonus(held, bonus));
  }

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
          if (widget.tragkraft != null) ...[
            const SizedBox(height: Abstand.weit),
            _Belastung(
              tragkraft: widget.tragkraft!,
              quellen: widget.tragkraftBoni,
              erschoepfung: widget.erschoepfung,
              ueberanstrengung: widget.ueberanstrengung,
              gesperrt: gesperrt,
              onErschoepfung: (delta) => _schreibeZustand(
                (z) => z.copyWith(erschoepfung: _ab0(z.erschoepfung + delta)),
              ),
              onUeberanstrengung: (delta) => _schreibeZustand(
                (z) => z.copyWith(
                  ueberanstrengung: _ab0(z.ueberanstrengung + delta),
                ),
              ),
              onBaerenrune: _baerenruneHinzufuegen,
              onQuelle: _quelleHinzufuegen,
              onEntfernen: (id) =>
                  _schreibe((held) => ohneTragkraftBonus(held, id)),
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

/// Abschnitt „Belastung“: getragenes Gewicht gegen die Tragkraft, die
/// dauerhaften Tragkraftquellen sowie Erschöpfung und Überanstrengung.
///
/// Zeigt nur an, was das Regelmodul liefert (`berechneTragkraft`); die
/// Schreibwege liegen beim Block.
class _Belastung extends StatelessWidget {
  const _Belastung({
    required this.tragkraft,
    required this.quellen,
    required this.erschoepfung,
    required this.ueberanstrengung,
    required this.gesperrt,
    required this.onErschoepfung,
    required this.onUeberanstrengung,
    required this.onBaerenrune,
    required this.onQuelle,
    required this.onEntfernen,
  });

  final TragkraftErgebnis tragkraft;
  final List<HeroTragkraftBonus> quellen;
  final int erschoepfung;
  final int ueberanstrengung;
  final bool gesperrt;
  final void Function(int delta) onErschoepfung;
  final void Function(int delta) onUeberanstrengung;
  final VoidCallback onBaerenrune;
  final VoidCallback onQuelle;
  final void Function(String id) onEntfernen;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final ueber = tragkraft.stufe != TragkraftStufe.frei;
    final hinweis = tragkraft.hinweis;
    final formel = tragkraftFormel(tragkraft.tragkraft);

    Widget stufenZeile(
      String schluessel,
      String name,
      int wert,
      void Function(int delta) onSchritt,
    ) {
      return Padding(
        padding: const EdgeInsets.only(top: Abstand.eng),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: texte.fliess.copyWith(color: karto.schrift),
              ),
            ),
            _MengeSchritt(
              schluessel: schluessel,
              menge: '$wert',
              name: name,
              onMinus: wert > 0 ? () => onSchritt(-1) : null,
              onPlus: () => onSchritt(1),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Belastung',
          style: texte.marke.copyWith(color: karto.schriftLeise),
        ),
        const SizedBox(height: Abstand.eng),
        Text(
          'Last ${formatiereStein(tragkraft.lastGramm)} von '
          '${tragkraft.tragkraftStein} Stein',
          key: const ValueKey<String>('karto-dabei-last'),
          style: texte.wert.copyWith(
            color: ueber ? karto.siegel : karto.schrift,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Abstand.haar),
          child: Text(
            'Tragkraft $formel',
            key: const ValueKey<String>('karto-dabei-tragkraft-formel'),
            style: texte.etikett.copyWith(color: karto.schriftLeise),
          ),
        ),
        if (hinweis != null)
          Padding(
            padding: const EdgeInsets.only(top: Abstand.eng),
            child: Text(
              hinweis,
              key: const ValueKey<String>('karto-dabei-last-hinweis'),
              style: texte.etikett.copyWith(color: karto.siegel),
            ),
          ),
        if (tragkraft.ohneGewicht > 0)
          Padding(
            padding: const EdgeInsets.only(top: Abstand.eng),
            child: Text(
              tragkraft.ohneGewicht == 1
                  ? '1 getragener Eintrag hat kein Gewicht: die Last ist '
                        'mindestens so hoch.'
                  : '${tragkraft.ohneGewicht} getragene Einträge haben kein '
                        'Gewicht: die Last ist mindestens so hoch.',
              key: const ValueKey<String>('karto-dabei-last-ohne-gewicht'),
              style: texte.etikett.copyWith(color: karto.schriftLeise),
            ),
          ),
        for (var i = 0; i < quellen.length; i++)
          Padding(
            key: ValueKey<String>('karto-dabei-tragkraft-$i'),
            padding: const EdgeInsets.only(top: Abstand.eng),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    quellen[i].anzeigeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: texte.fliess.copyWith(color: karto.schrift),
                  ),
                ),
                Text(
                  [
                    if (quellen[i].stein != 0) '+${quellen[i].stein} Stein',
                    if (quellen[i].kk != 0)
                      'KK ${quellen[i].kk > 0 ? '+' : ''}${quellen[i].kk}',
                  ].join(' · '),
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                ),
                _Knopf(
                  key: ValueKey<String>('karto-dabei-tragkraft-$i-entfernen'),
                  zeichen: '×',
                  tipp: '${quellen[i].anzeigeName} entfernen',
                  onTap: gesperrt ? null : () => onEntfernen(quellen[i].id),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: Abstand.normal,
          children: [
            TextButton(
              key: const ValueKey<String>('karto-dabei-baerenrune'),
              onPressed: gesperrt ? null : onBaerenrune,
              child: const Text('+ Bärenrune'),
            ),
            TextButton(
              key: const ValueKey<String>('karto-dabei-tragkraft-quelle'),
              onPressed: gesperrt ? null : onQuelle,
              child: const Text('+ Andere Tragkraftquelle'),
            ),
          ],
        ),
        stufenZeile(
          'karto-dabei-erschoepfung',
          'Erschöpfung',
          erschoepfung,
          onErschoepfung,
        ),
        stufenZeile(
          'karto-dabei-ueberanstrengung',
          'Überanstrengung',
          ueberanstrengung,
          onUeberanstrengung,
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
    required this.eintrag,
    required this.gesperrt,
    required this.onSchritt,
    required this.onBenutzen,
  });

  final int index;
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
                key: ValueKey<String>('karto-dabei-$index-benutzen'),
                onPressed: gesperrt || aufgebraucht ? null : onBenutzen,
                child: const Text('Benutzen'),
              ),
            ),
          _MengeSchritt(
            schluessel: 'karto-dabei-$index',
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

/// Dialog „Bärenrune“: RkP* der Rune, dazu die Hausregel „KK +1“.
///
/// Liefert RkP* und den Schalter der Hausregel oder nichts bei Abbruch. Die
/// Tragkraft (RkP* × 10 Stein) rechnet `baerenruneBonus`.
class _BaerenruneDialog extends StatefulWidget {
  const _BaerenruneDialog();

  @override
  State<_BaerenruneDialog> createState() => _BaerenruneDialogState();
}

class _BaerenruneDialogState extends State<_BaerenruneDialog> {
  final TextEditingController _rkp = TextEditingController();
  bool _kk = false;
  String? _fehler;

  @override
  void dispose() {
    _rkp.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final rkp = int.tryParse(_rkp.text.trim());
    if (rkp == null || rkp <= 0) {
      setState(() => _fehler = 'Bitte die RkP* als Zahl über 0 eingeben.');
      return;
    }
    Navigator.of(context).pop((rkp: rkp, kk: _kk));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bärenrune'),
      content: SizedBox(
        width: Breite.klein,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey<String>('karto-dabei-baerenrune-rkp'),
              controller: _rkp,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'RkP*',
                helperText: 'Tragkraft + RkP* × 10 Stein (WdA S. 161)',
                errorText: _fehler,
              ),
              onChanged: (_) {
                if (_fehler != null) setState(() => _fehler = null);
              },
              onSubmitted: (_) => _uebernehmen(),
            ),
            CheckboxListTile(
              key: const ValueKey<String>('karto-dabei-baerenrune-kk'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _kk,
              onChanged: (wert) => setState(() => _kk = wert ?? false),
              title: const Text('Hausregel: zusätzlich KK +1'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-dabei-baerenrune-ok'),
          onPressed: _uebernehmen,
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}

/// Dialog „Tragkraftquelle“: Name, zusätzliche Stein und KK nur für die
/// Tragkraft. Liefert die Quelle (ohne ID) oder nichts bei Abbruch.
class _QuelleDialog extends StatefulWidget {
  const _QuelleDialog();

  @override
  State<_QuelleDialog> createState() => _QuelleDialogState();
}

class _QuelleDialogState extends State<_QuelleDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _stein = TextEditingController();
  final TextEditingController _kk = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _name.dispose();
    _stein.dispose();
    _kk.dispose();
    super.dispose();
  }

  void _uebernehmen() {
    final name = _name.text.trim();
    final stein = _stein.text.trim().isEmpty
        ? 0
        : int.tryParse(_stein.text.trim());
    final kk = _kk.text.trim().isEmpty ? 0 : int.tryParse(_kk.text.trim());
    if (name.isEmpty) {
      setState(() => _fehler = 'Bitte einen Namen eingeben.');
      return;
    }
    if (stein == null || stein < 0 || kk == null) {
      setState(() => _fehler = 'Stein und KK müssen ganze Zahlen sein.');
      return;
    }
    if (stein == 0 && kk == 0) {
      setState(() => _fehler = 'Stein oder KK muss ungleich 0 sein.');
      return;
    }
    Navigator.of(context)
        .pop(HeroTragkraftBonus(id: '', name: name, stein: stein, kk: kk));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tragkraftquelle'),
      content: SizedBox(
        width: Breite.klein,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey<String>('karto-dabei-quelle-name'),
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Name',
                helperText: 'Nur Dauerhaftes, keine Kurzzeitzauber',
                errorText: _fehler,
              ),
              onChanged: (_) {
                if (_fehler != null) setState(() => _fehler = null);
              },
            ),
            TextField(
              key: const ValueKey<String>('karto-dabei-quelle-stein'),
              controller: _stein,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Zusätzliche Stein'),
            ),
            TextField(
              key: const ValueKey<String>('karto-dabei-quelle-kk'),
              controller: _kk,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'KK nur für die Tragkraft',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-dabei-quelle-ok'),
          onPressed: _uebernehmen,
          child: const Text('Hinzufügen'),
        ),
      ],
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
