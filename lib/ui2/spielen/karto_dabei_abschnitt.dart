import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spiel_dabei_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
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

/// Block „Dabei“ der Spielansicht (SPIEL-02): Geld und Verbrauchsgegenstände.
///
/// Zeigt den Geldstand mit Münzschritten und die Verbrauchsgegenstände des
/// Inventars mit +/−. Jeder Klick schreibt **frisch**: den gespeicherten Helden
/// laden, nur den Geldstand oder die Menge dieses einen Eintrags ändern,
/// speichern (`mitDukatenSchritt`, `mitVerbrauchsmengenSchritt`). Die Schritte
/// reihen sich je Held ein, deshalb zählt auch ein schneller Doppelklick. Gesperrt
/// ist alles während einer offenen Planung. Der Block rechnet nichts selbst.
class KartoDabeiAbschnitt extends ConsumerStatefulWidget {
  /// Erstellt den Block für den Helden [heroId].
  const KartoDabeiAbschnitt({
    super.key,
    required this.heroId,
    required this.dukaten,
    required this.verbrauch,
    this.onBenutzen,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Gespeicherter Geldstand des Bogens (Freitext).
  final String dukaten;

  /// Verbrauchsgegenstände aus `dabeiVerbrauchsgegenstaende`.
  final List<HeroInventoryEntry> verbrauch;

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
            // Auf breiter Kachel fließen die Zeilen in zwei Spalten; sonst
            // stünden Name und Knöpfe eine halbe Seite auseinander.
            LayoutBuilder(
              builder: (context, constraints) {
                final zweispaltig = constraints.maxWidth >= kDabeiZweispaltigAb;
                final zeilenbreite = zweispaltig
                    ? (constraints.maxWidth - Abstand.bahn) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: Abstand.bahn,
                  children: [
                    for (var i = 0; i < sichtbar.length; i++)
                      SizedBox(
                        width: zeilenbreite,
                        child: _Verbrauchszeile(
                          index: i,
                          eintrag: sichtbar[i],
                          gesperrt: gesperrt,
                          onSchritt: (delta) => _schreibe(
                            (held) => mitVerbrauchsmengenSchritt(
                              held,
                              sichtbar[i],
                              delta,
                            ),
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
                      ),
                  ],
                );
              },
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
