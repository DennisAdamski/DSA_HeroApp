import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/spiel_zauber_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/zauber_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Ab so vielen Zaubern zeigt die Kachel das Suchfeld.
const int kZauberSucheAb = 6;

/// Zauber als Kachel der Spielansicht, nach dem Vorbild der Magie-Seite:
/// Kopf mit Repräsentation, Leiteigenschaft und Merkmalskenntnissen, darunter
/// die gelernten Zauber mit ZfW*, Probe, Kosten, Zauberdauer, Reichweite und
/// Wirkungsdauer.
///
/// Die Kachel ist **optional**: sie steht ausgeblendet in der Standard-
/// anordnung und wird im Anordnen-Modus über „Ausgeblendet: Zauber“ auf die
/// Seite geholt. Sie schreibt nichts am Helden; Würfeln läuft über die
/// Gefechtsbrücke, die selbst ins Würfelprotokoll schreibt. Suche, Sortierung
/// und Merkmalsfilter leben nur im Widget. Gerechnet wird in
/// `spiel_zauber_rules.dart` und `zauber_herleitung_rules.dart`; die
/// geschützten Langtexte (Wirkung, Varianten) zeigen der Probendialog und der
/// Beschreibungsknopf je Zauber, der die Zauberdetails der Magie-Seite
/// schreibgeschützt öffnet (`zauberDetailsOeffnen`).
class KartoZauberKachel extends ConsumerStatefulWidget {
  /// Kachel für den Helden [heroId] mit den gespeicherten [werte].
  const KartoZauberKachel({
    super.key,
    required this.heroId,
    required this.werte,
    required this.bestand,
    required this.aktion,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Abgeleitete Werte des Helden (Zauber, Eigenschaften, AsP).
  final HeroComputedSnapshot werte;

  /// Brücke zum Bestand; nur mit [KartoGefechtsAdapter] lässt sich würfeln.
  final KartoBestandsAdapter bestand;

  /// Geschützter Ausführungsweg für Dialoge (Re-Entrancy-Guard).
  final Future<void> Function(Future<void> Function() aktion) aktion;

  @override
  ConsumerState<KartoZauberKachel> createState() => _KartoZauberKachelState();
}

class _KartoZauberKachelState extends ConsumerState<KartoZauberKachel> {
  String _suche = '';
  String? _merkmal;
  SpielZauberSortierung _sortierung = SpielZauberSortierung.name;
  bool _aufsteigend = true;
  final Set<String> _offen = <String>{};

  KartoGefechtsAdapter? get _bruecke => switch (widget.bestand) {
    final KartoGefechtsAdapter b => b,
    _ => null,
  };

  void _sortiere(SpielZauberSortierung kriterium) {
    setState(() {
      if (_sortierung == kriterium) {
        _aufsteigend = !_aufsteigend;
      } else {
        _sortierung = kriterium;
        // ZfW* steht zuerst mit dem höchsten Wert, Namen von A bis Z.
        _aufsteigend = kriterium == SpielZauberSortierung.name;
      }
    });
  }

  Future<void> _wuerfeln(SpielZauberEintrag eintrag) async {
    final bruecke = _bruecke;
    if (bruecke == null) return;
    // Frisch lesen statt des beim Bauen erfassten Snapshots.
    final werte =
        ref.read(heroComputedProvider(widget.heroId)).asData?.value ??
        widget.werte;
    final wert = zauberProbenwertFuer(snapshot: werte, spell: eintrag.zauber);
    if (wert == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Zauber ist nicht aktiviert (kein ZfW).')),
      );
      return;
    }
    await widget.aktion(() async {
      await bruecke.gefechtsProbe(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        request: zauberprobeAus(
          wert: wert,
          titel: eintrag.zauber.name,
          zauberId: eintrag.zauber.id,
        ),
      );
    });
  }

  Future<void> _beschreibung(SpielZauberEintrag eintrag) => widget.aktion(
    () => widget.bestand.zauberDetailsOeffnen(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      zauberId: eintrag.zauber.id,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final katalog = ref
        .watch(heroRulesCatalogProvider(widget.heroId))
        .valueOrNull;
    final alle = katalog == null
        ? const <SpielZauberEintrag>[]
        : spielZauberListe(widget.werte, katalog);
    final merkmale = spielZauberMerkmale(alle);
    // Ein Merkmal, das kein Zauber mehr trägt, filtert nicht.
    final merkmal = merkmale.contains(_merkmal) ? _merkmal : null;
    final liste = katalog == null
        ? const <SpielZauberEintrag>[]
        : spielZauberListe(
            widget.werte,
            katalog,
            suche: _suche,
            merkmal: merkmal,
            sortierung: _sortierung,
            aufsteigend: _aufsteigend,
          );
    final kopf = spielZauberKopf(widget.werte);
    final groesse = KartoKachelSteuerung.groesseVon(context);
    final magie = widget.werte.resourceActivation.magic.isEnabled;

    return KartoAbschnitt(
      titel: 'Zauber',
      symbol: Icons.auto_fix_high_outlined,
      akzent: KartoAkzent.astral,
      aktion: magie
          ? _AspMarke(
              aktuell: widget.werte.state.currentAsp,
              maximum: widget.werte.derivedStats.maxAsp,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!kopf.leer) ...[
            _Kopf(kopf: kopf),
            const SizedBox(height: Abstand.weit),
          ],
          if (katalog == null)
            Text(
              'Der Katalog wird geladen …',
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            )
          else if (alle.isEmpty)
            Text(
              'Keine Zauber aktiviert. Zauber trägst du auf der Magie-Seite '
              'des Helden ein.',
              key: const ValueKey<String>('karto-zauber-leer'),
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            )
          else ...[
            _Werkzeugleiste(
              mitSuche: alle.length > kZauberSucheAb,
              suche: _suche,
              onSuche: (text) => setState(() => _suche = text),
              sortierung: _sortierung,
              aufsteigend: _aufsteigend,
              onSortieren: _sortiere,
              merkmale: merkmale,
              merkmal: merkmal,
              onMerkmal: (wert) => setState(() => _merkmal = wert),
            ),
            const SizedBox(height: Abstand.weit),
            if (liste.isEmpty)
              Text(
                merkmal == null
                    ? 'Kein Zauber passt zur Suche.'
                    : 'Kein Zauber mit Merkmal $merkmal passt zur Suche.',
                key: const ValueKey<String>('karto-zauber-keine-treffer'),
                style: texte.fliess.copyWith(color: karto.schriftLeise),
              )
            else
              for (final (i, eintrag) in liste.indexed) ...[
                if (i > 0) const SizedBox(height: Abstand.normal),
                _ZauberZeile(
                  eintrag: eintrag,
                  groesse: groesse,
                  offen: _offen.contains(eintrag.zauber.id),
                  onUmschalten: () => setState(() {
                    if (!_offen.remove(eintrag.zauber.id)) {
                      _offen.add(eintrag.zauber.id);
                    }
                  }),
                  onWuerfeln: _bruecke == null
                      ? null
                      : () => _wuerfeln(eintrag),
                  onBeschreibung: () => _beschreibung(eintrag),
                ),
              ],
          ],
        ],
      ),
    );
  }
}

/// Aktuelle und größte AsP im Kopf der Kachel.
class _AspMarke extends StatelessWidget {
  const _AspMarke({required this.aktuell, required this.maximum});

  final int aktuell;
  final int maximum;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Row(
      key: const ValueKey<String>('karto-zauber-asp'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_outlined, size: 16, color: karto.astralenergie),
        const SizedBox(width: Abstand.knapp),
        Flexible(
          child: Text(
            'AsP $aktuell / $maximum',
            style: texte.wert.copyWith(color: karto.astralenergie),
          ),
        ),
      ],
    );
  }
}

/// Repräsentation, Leiteigenschaft und Merkmalskenntnisse als leise Zeile.
class _Kopf extends StatelessWidget {
  const _Kopf({required this.kopf});

  final SpielZauberKopf kopf;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    Widget fakt(String etikett, String wert) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$etikett ',
            style: texte.marke.copyWith(color: karto.schriftLeise),
          ),
          TextSpan(text: wert, style: texte.etikett),
        ],
      ),
    );
    return Wrap(
      key: const ValueKey<String>('karto-zauber-kopf'),
      spacing: Abstand.block,
      runSpacing: Abstand.eng,
      children: [
        if (kopf.traditionen.isNotEmpty)
          fakt('Repräsentation', kopf.traditionen.join(', ')),
        if (kopf.leiteigenschaften.isNotEmpty)
          fakt('Leiteigenschaft', kopf.leiteigenschaften.join('/')),
        if (kopf.merkmalskenntnisse.isNotEmpty)
          fakt('Merkmalskenntnis', kopf.merkmalskenntnisse.join(', ')),
      ],
    );
  }
}

/// Suche, Sortierung und Merkmalsfilter.
class _Werkzeugleiste extends StatelessWidget {
  const _Werkzeugleiste({
    required this.mitSuche,
    required this.suche,
    required this.onSuche,
    required this.sortierung,
    required this.aufsteigend,
    required this.onSortieren,
    required this.merkmale,
    required this.merkmal,
    required this.onMerkmal,
  });

  final bool mitSuche;
  final String suche;
  final ValueChanged<String> onSuche;
  final SpielZauberSortierung sortierung;
  final bool aufsteigend;
  final ValueChanged<SpielZauberSortierung> onSortieren;
  final List<String> merkmale;
  final String? merkmal;
  final ValueChanged<String?> onMerkmal;

  // Flutter wertet `null` als Menüabbruch und ruft `onSelected` nicht auf;
  // „Alle Merkmale“ trägt deshalb den leeren Text.
  static const String _alle = '';

  Widget _sortierChip(
    BuildContext context,
    SpielZauberSortierung kriterium,
    String text,
  ) {
    final aktiv = sortierung == kriterium;
    return ChoiceChip(
      key: ValueKey<String>('karto-zauber-sort-${kriterium.name}'),
      label: Text(text),
      avatar: aktiv
          ? Icon(
              aufsteigend ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
            )
          : null,
      selected: aktiv,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onSortieren(kriterium),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mitSuche) ...[
          TextField(
            key: const ValueKey<String>('karto-zauber-suche'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Zauber suchen',
            ),
            onChanged: onSuche,
          ),
          const SizedBox(height: Abstand.normal),
        ],
        Wrap(
          spacing: Abstand.normal,
          runSpacing: Abstand.eng,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _sortierChip(context, SpielZauberSortierung.name, 'Name'),
            _sortierChip(context, SpielZauberSortierung.zfw, 'ZfW*'),
            if (merkmale.length > 1)
              PopupMenuButton<String>(
                key: const ValueKey<String>('karto-zauber-merkmal'),
                tooltip: 'Nach Merkmal filtern',
                onSelected: (wert) => onMerkmal(wert == _alle ? null : wert),
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    key: ValueKey<String>('karto-zauber-merkmal-alle'),
                    value: _alle,
                    child: Text('Alle Merkmale'),
                  ),
                  for (final m in merkmale)
                    PopupMenuItem<String>(value: m, child: Text(m)),
                ],
                child: Chip(
                  avatar: const Icon(Icons.filter_list, size: 16),
                  label: Text(merkmal ?? 'Merkmal'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Ein Zauber: Name, ZfW*, Probe und Kurzangaben; Tipp klappt die Details auf.
class _ZauberZeile extends StatelessWidget {
  const _ZauberZeile({
    required this.eintrag,
    required this.groesse,
    required this.offen,
    required this.onUmschalten,
    required this.onWuerfeln,
    required this.onBeschreibung,
  });

  final SpielZauberEintrag eintrag;
  final KartoKachelGroesse groesse;
  final bool offen;
  final VoidCallback onUmschalten;
  final VoidCallback? onWuerfeln;
  final VoidCallback onBeschreibung;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final zauber = eintrag.zauber;
    final id = zauber.id;
    final kompakt = groesse == KartoKachelGroesse.kompakt;
    final weit = groesse == KartoKachelGroesse.weit;

    final unterzeile = <String>[
      if (eintrag.eigenschaften.isNotEmpty) eintrag.eigenschaften,
      if (eintrag.repraesentation != null) eintrag.repraesentation!,
      if (eintrag.hauszauber) 'Hauszauber',
    ].join(' · ');

    // Kompakt nur Kosten und Zauberdauer; mit Platz kommen Reichweite und
    // Wirkungsdauer dazu, in der weiten Kachel auch die Merkmale.
    final kurz = <({IconData symbol, String text})>[
      if (zauber.aspCost.trim().isNotEmpty)
        (symbol: Icons.bolt_outlined, text: zauber.aspCost.trim()),
      if (zauber.castingTime.trim().isNotEmpty)
        (symbol: Icons.timer_outlined, text: zauber.castingTime.trim()),
      if (!kompakt && zauber.range.trim().isNotEmpty)
        (symbol: Icons.straighten_outlined, text: zauber.range.trim()),
      if (!kompakt && zauber.duration.trim().isNotEmpty)
        (symbol: Icons.hourglass_empty_outlined, text: zauber.duration.trim()),
      if (weit && eintrag.merkmale.isNotEmpty)
        (symbol: Icons.sell_outlined, text: eintrag.merkmale.join(', ')),
    ];

    final details = <({String etikett, String wert})>[
      if (kompakt && zauber.range.trim().isNotEmpty)
        (etikett: 'Reichweite', wert: zauber.range.trim()),
      if (kompakt && zauber.duration.trim().isNotEmpty)
        (etikett: 'Wirkungsdauer', wert: zauber.duration.trim()),
      if (zauber.targetObject.trim().isNotEmpty)
        (etikett: 'Zielobjekt', wert: zauber.targetObject.trim()),
      if (!weit && eintrag.merkmale.isNotEmpty)
        (etikett: 'Merkmale', wert: eintrag.merkmale.join(', ')),
      if (zauber.modifications.trim().isNotEmpty)
        (etikett: 'Modifikationen', wert: zauber.modifications.trim()),
      if (eintrag.spezialisierungen.isNotEmpty)
        (
          etikett: 'Spezialisierung',
          wert: eintrag.spezialisierungen.join(', '),
        ),
      if (zauber.steigerung.trim().isNotEmpty)
        (etikett: 'Komplexität', wert: zauber.steigerung.trim()),
    ];

    return KartoFlaeche(
      key: ValueKey<String>('karto-zauber-$id'),
      stufe: KartoFlaechenstufe.senke,
      klein: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: ValueKey<String>('karto-zauber-$id-oeffnen'),
            onTap: details.isEmpty ? null : onUmschalten,
            borderRadius: BorderRadius.circular(kKartoRadiusKlein),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Abstand.weit,
                Abstand.normal,
                Abstand.normal,
                Abstand.normal,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(zauber.name, style: texte.wert),
                        if (unterzeile.isNotEmpty) ...[
                          const SizedBox(height: Abstand.haar),
                          Text(
                            unterzeile,
                            style: texte.etikett.copyWith(
                              color: karto.schriftLeise,
                            ),
                          ),
                        ],
                        if (kurz.isNotEmpty) ...[
                          const SizedBox(height: Abstand.knapp),
                          Wrap(
                            spacing: Abstand.weit,
                            runSpacing: Abstand.eng,
                            children: [
                              for (final k in kurz)
                                _Kurzangabe(symbol: k.symbol, text: k.text),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Abstand.normal),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'ZfW*',
                        style: texte.marke.copyWith(color: karto.schriftLeise),
                      ),
                      Text(
                        '${eintrag.zfw}',
                        key: ValueKey<String>('karto-zauber-$id-zfw'),
                        style: texte.wertGross.copyWith(
                          color: karto.astralenergie,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    key: ValueKey<String>('karto-zauber-$id-beschreibung'),
                    tooltip: '${zauber.name}: ganze Beschreibung',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.menu_book_outlined),
                    onPressed: onBeschreibung,
                  ),
                  if (onWuerfeln != null)
                    IconButton(
                      key: ValueKey<String>('karto-zauber-$id-probe'),
                      tooltip: '${zauber.name} würfeln',
                      icon: const Icon(Icons.casino_outlined),
                      onPressed: onWuerfeln,
                    ),
                ],
              ),
            ),
          ),
          if (offen && details.isNotEmpty)
            Padding(
              key: ValueKey<String>('karto-zauber-$id-details'),
              padding: const EdgeInsets.fromLTRB(
                Abstand.weit,
                0,
                Abstand.weit,
                Abstand.weit,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(
                    height: Abstand.weit,
                    thickness: 0.5,
                    color: karto.messing.withValues(alpha: 0.32),
                  ),
                  for (final d in details)
                    Padding(
                      padding: const EdgeInsets.only(top: Abstand.eng),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${d.etikett}: ',
                              style: texte.marke.copyWith(
                                color: karto.schriftLeise,
                              ),
                            ),
                            TextSpan(text: d.wert, style: texte.fliess),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Kurzangabe extends StatelessWidget {
  const _Kurzangabe({required this.symbol, required this.text});

  final IconData symbol;
  final String text;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(symbol, size: 14, color: karto.schriftLeise),
        const SizedBox(width: Abstand.eng),
        Flexible(child: Text(text, style: texte.etikett)),
      ],
    );
  }
}
