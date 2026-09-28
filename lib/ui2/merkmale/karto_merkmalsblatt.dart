import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/hero_trait_choices.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmal_dialoge.dart';
import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmal_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_kartenraster.dart';

/// Öffnet das Merkmalsblatt eines Helden.
///
/// Modal wie das Abenteuerblatt: solange es offen ist, entsteht in der
/// Verwaltung kein Entwurf, der seine Änderungen später überschreiben könnte.
Future<void> zeigeMerkmalsblatt({
  required BuildContext context,
  required String heroId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Eigene Seite: Grund `blatt`, Karten darauf `feld`.
    backgroundColor: context.karto.blatt,
    constraints: const BoxConstraints(maxWidth: Breite.gross),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kKartoRadius)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: .9,
      child: KartoMerkmalsblatt(heroId: heroId),
    ),
  );
}

/// Vor- und Nachteile als Karten: lesen, anlegen, ändern, entfernen (ARCH-02).
///
/// UI2-eigen nach dem Muster des Abenteuerblatts: geschrieben werden gezielt
/// nur die Merkmalslisten, über `HeroActions.updateHero` (frisch laden, dann
/// ändern) und [aendereMerkmale]. Eine Abweichung, die eine ältere
/// App-Version am Text verursacht hat, wird angezeigt und nur auf ausdrückliche
/// Entscheidung aufgelöst. Während einer Steigerungsplanung ist das Blatt
/// schreibgeschützt, weil jede Heldenänderung den Inhalts-Hash der Runde
/// bräche. Gespeichert und Fehler angezeigt wird im Blatt selbst.
class KartoMerkmalsblatt extends ConsumerStatefulWidget {
  /// Bindet das Blatt an einen Helden.
  const KartoMerkmalsblatt({super.key, required this.heroId});

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  @override
  ConsumerState<KartoMerkmalsblatt> createState() => _KartoMerkmalsblattState();
}

class _KartoMerkmalsblattState extends ConsumerState<KartoMerkmalsblatt> {
  bool _schreibt = false;
  String? _fehler;

  @override
  Widget build(BuildContext context) {
    final berechnet = ref.watch(heroComputedProvider(widget.heroId));
    final katalogWert = ref.watch(rulesCatalogProvider);
    final werte = berechnet.asData?.value;
    final catalog = katalogWert.valueOrNull;
    if (berechnet.hasError || katalogWert.hasError) {
      return _meldung('Vor- und Nachteile konnten nicht geladen werden.');
    }
    if (werte == null || catalog == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final katalog = MerkmalKatalog.von(catalog);
    final abgleich = werteMerkmaleAus(werte.hero, catalog: catalog).abgleich;
    final gesperrt =
        ref.watch(advancementSessionProvider(widget.heroId)) != null;
    final karto = context.karto;

    return LayoutBuilder(
      builder: (context, constraints) {
        final rand = constraints.maxWidth < Breite.klein
            ? Abstand.block
            : Abstand.bahn;
        return ListView(
          padding: EdgeInsets.fromLTRB(rand, 0, rand, Abstand.bahn),
          children: [
            Text(
              'Vor- und Nachteile',
              style: Theme.of(context).textTheme.titel,
            ),
            if (gesperrt) ...[
              const SizedBox(height: Abstand.block),
              _Hinweiszeile(
                key: const ValueKey<String>('karto-merkmal-gesperrt'),
                symbol: Icons.lock_outline,
                text:
                    'Während eine Entwicklung geplant wird, sind Vor- und '
                    'Nachteile schreibgeschützt.',
                farbe: karto.schriftLeise,
              ),
            ],
            if (_fehler != null) ...[
              const SizedBox(height: Abstand.block),
              _Hinweiszeile(
                key: const ValueKey<String>('karto-merkmal-fehler'),
                symbol: Icons.error_outline,
                text: _fehler!,
                farbe: karto.siegel,
              ),
            ],
            for (final vorteil in const [true, false]) ...[
              const SizedBox(height: Abstand.rand),
              ..._art(
                vorteil: vorteil,
                eintraege: vorteil ? abgleich.vorteile : abgleich.nachteile,
                abweichung: vorteil
                    ? abgleich.vorteilAbweichung
                    : abgleich.nachteilAbweichung,
                katalog: katalog,
                catalog: catalog,
                gesperrt: gesperrt,
              ),
            ],
          ],
        );
      },
    );
  }

  // Überschrift, Abweichungshinweis und Kartenraster einer Merkmalsart.
  List<Widget> _art({
    required bool vorteil,
    required List<HeroMerkmal> eintraege,
    required MerkmalAbweichung? abweichung,
    required MerkmalKatalog katalog,
    required RulesCatalog catalog,
    required bool gesperrt,
  }) {
    final schluessel = vorteil ? 'vorteile' : 'nachteile';
    final bearbeitbar = !gesperrt && abweichung == null && !_schreibt;
    return [
      _Kopfzeile(
        titel: vorteil ? 'Vorteile' : 'Nachteile',
        anzahl: eintraege.length,
      ),
      const SizedBox(height: Abstand.weit),
      if (abweichung != null) ...[
        _Abweichung(
          key: ValueKey<String>('karto-merkmal-abweichung-$schluessel'),
          schluessel: schluessel,
          abweichung: abweichung,
          entscheidbar: !gesperrt && !_schreibt,
          onEntscheiden: (textUebernehmen) => _schreibe(
            (held, katalog) => loeseMerkmalAbweichung(
              held,
              vorteil: vorteil,
              katalog: katalog,
              textUebernehmen: textUebernehmen,
            ),
          ),
        ),
        const SizedBox(height: Abstand.weit),
      ],
      if (eintraege.isEmpty && !bearbeitbar)
        Text(
          'Keine Einträge.',
          style: Theme.of(context).textTheme.fliess
              .copyWith(color: context.karto.schriftLeise),
        )
      else
        KartoKartenraster(
          mindestbreite: 220,
          kinder: [
            for (var i = 0; i < eintraege.length; i++)
              KartoMerkmalkarte(
                key: ValueKey<String>('karto-merkmal-$schluessel-$i'),
                anzeige: beschreibeMerkmal(
                  eintraege[i],
                  katalog,
                  vorteil: vorteil,
                ),
                onTap: bearbeitbar
                    ? () => _bearbeiten(
                        vorteil: vorteil,
                        eintrag: eintraege[i],
                        katalog: katalog,
                        catalog: catalog,
                      )
                    : null,
              ),
            if (bearbeitbar)
              KartoFreieKachel(
                key: ValueKey<String>('karto-merkmal-neu-$schluessel'),
                beschriftung: vorteil
                    ? 'Vorteil hinzufügen'
                    : 'Nachteil hinzufügen',
                symbol: Icons.add,
                onTap: () => _hinzufuegen(
                  vorteil: vorteil,
                  katalog: katalog,
                  catalog: catalog,
                ),
              ),
          ],
        ),
    ];
  }

  Future<void> _hinzufuegen({
    required bool vorteil,
    required MerkmalKatalog katalog,
    required RulesCatalog catalog,
  }) async {
    final defs = List<HeroTraitDef>.of(katalog.liste(vorteil: vorteil))
      ..sort((a, b) => a.name.compareTo(b.name));
    final wahl = await zeigeMerkmalKatalog(
      context: context,
      art: vorteil ? 'Vorteil' : 'Nachteil',
      defs: defs,
    );
    if (wahl == null || !mounted) return;
    final def = wahl.def;
    final HeroMerkmal neu;
    if (def == null) {
      final text = await zeigeMerkmalText(
        context: context,
        titel: vorteil ? 'Freier Vorteil' : 'Freier Nachteil',
      );
      if (text == null || text.isEmpty) return;
      neu = HeroMerkmal(text: text, zuordnung: HeroMerkmalZuordnung.frei);
    } else {
      final angaben = await _angaben(def, catalog);
      if (angaben == null) return;
      neu = HeroMerkmal(
        katalogId: def.id,
        text: merkmalTextFuer(
          def,
          auswahl: angaben.auswahl,
          wert: angaben.wert,
        ),
        wert: angaben.wert,
        auswahl: angaben.auswahl,
      );
    }
    await _schreibe(
      (held, katalog) => aendereMerkmale(
        held,
        vorteil: vorteil,
        katalog: katalog,
        aenderung: (liste) => fuegeMerkmalHinzu(liste, neu, def: def),
      ),
    );
  }

  // Auswahl und Wert erfragen, sofern der Eintrag welche trägt.
  Future<KartoMerkmalWerte?> _angaben(
    HeroTraitDef def,
    RulesCatalog catalog, {
    HeroMerkmal? bisher,
  }) async {
    if (!merkmalBrauchtAngaben(def)) {
      return (auswahl: '', wert: null);
    }
    return zeigeMerkmalWerte(
      context: context,
      def: def,
      auswahlen: merkmalBrauchtAuswahl(def)
          ? resolveTraitChoices(def, catalog)
          : const <String>[],
      auswahl: bisher?.auswahl ?? '',
      wert: bisher?.wert,
    );
  }

  Future<void> _bearbeiten({
    required bool vorteil,
    required HeroMerkmal eintrag,
    required MerkmalKatalog katalog,
    required RulesCatalog catalog,
  }) async {
    final def = eintrag.istKatalogisiert
        ? katalog.eintrag(eintrag.katalogId, vorteil: vorteil)
        : null;
    final anzeige = beschreibeMerkmal(eintrag, katalog, vorteil: vorteil);
    final aktion = await showDialog<_Aktion>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(anzeige.name),
        children: [
          if (def != null && merkmalBrauchtAngaben(def))
            _option(context, _Aktion.aendern, 'Stufe oder Auswahl ändern'),
          if (eintrag.brauchtPruefung)
            _option(context, _Aktion.zuordnen, 'Katalogeintrag zuordnen'),
          if (def == null) _option(context, _Aktion.text, 'Text bearbeiten'),
          _option(context, _Aktion.entfernen, 'Entfernen'),
        ],
      ),
    );
    if (aktion == null || !mounted) return;

    HeroMerkmal? ersatz;
    switch (aktion) {
      case _Aktion.aendern:
        final angaben = await _angaben(def!, catalog, bisher: eintrag);
        if (angaben == null) return;
        ersatz = eintrag.copyWith(
          text: merkmalTextFuer(
            def,
            auswahl: angaben.auswahl,
            wert: angaben.wert,
          ),
          wert: angaben.wert,
          auswahl: angaben.auswahl,
          zuordnung: HeroMerkmalZuordnung.katalog,
        );
      case _Aktion.zuordnen:
        final kandidaten = <HeroTraitDef>[
          for (final id in eintrag.kandidatenIds)
            ?katalog.eintrag(id, vorteil: vorteil),
        ];
        final wahl = await zeigeMerkmalKandidaten(
          context: context,
          text: eintrag.text,
          kandidaten: kandidaten,
        );
        if (wahl == null) return;
        final gewaehlt = wahl.def;
        if (gewaehlt == null) {
          ersatz = eintrag.copyWith(
            kandidatenIds: const <String>[],
            zuordnung: HeroMerkmalZuordnung.frei,
          );
        } else {
          final teile = ordneMerkmalZu(eintrag.text, [gewaehlt]);
          ersatz = eintrag.copyWith(
            katalogId: gewaehlt.id,
            wert: teile.wert,
            auswahl: teile.auswahl,
            kandidatenIds: const <String>[],
            zuordnung: HeroMerkmalZuordnung.katalog,
          );
        }
      case _Aktion.text:
        final text = await zeigeMerkmalText(
          context: context,
          titel: 'Eintrag bearbeiten',
          text: eintrag.text,
        );
        if (text == null || text.isEmpty) return;
        // Ein getippter Katalogname wird zugeordnet, alles andere bleibt frei.
        final teile = ordneMerkmalZu(text, katalog.liste(vorteil: vorteil));
        ersatz = eintrag.copyWith(
          katalogId: teile.katalogId,
          text: teile.text,
          wert: teile.wert,
          auswahl: teile.auswahl,
          kandidatenIds: teile.kandidatenIds,
          zuordnung: teile.istKatalogisiert
              ? HeroMerkmalZuordnung.katalog
              : teile.zuordnung,
        );
      case _Aktion.entfernen:
        if (!await bestaetigeMerkmalEntfernen(context, anzeige.name)) return;
        ersatz = null;
    }
    await _schreibe(
      (held, katalog) => aendereMerkmale(
        held,
        vorteil: vorteil,
        katalog: katalog,
        aenderung: (liste) => _ersetze(liste, eintrag, ersatz),
      ),
    );
  }

  Widget _option(BuildContext context, _Aktion aktion, String text) {
    return SimpleDialogOption(
      key: ValueKey<String>('karto-merkmal-aktion-${aktion.name}'),
      onPressed: () => Navigator.of(context).pop(aktion),
      child: Text(text),
    );
  }

  // Einziger Schreibweg des Blatts: frisch laden, gezielt ändern, speichern.
  // Doppelte Auslösung verhindert [_schreibt].
  Future<void> _schreibe(
    HeroSheet Function(HeroSheet held, MerkmalKatalog katalog) aenderung,
  ) async {
    if (_schreibt) return;
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      if (ref.read(advancementSessionProvider(widget.heroId)) != null) {
        throw StateError(
          'Während einer Planung sind Vor- und Nachteile gesperrt.',
        );
      }
      final catalog = ref.read(rulesCatalogProvider).valueOrNull;
      if (catalog == null) {
        throw StateError('Der Regelkatalog ist noch nicht geladen.');
      }
      final katalog = MerkmalKatalog.von(catalog);
      await ref
          .read(heroActionsProvider)
          .updateHero(widget.heroId, (held) => aenderung(held, katalog));
    } catch (error) {
      if (mounted) {
        setState(() => _fehler = 'Speichern fehlgeschlagen: ${_text(error)}');
      }
    } finally {
      if (mounted) setState(() => _schreibt = false);
    }
  }

  String _text(Object error) =>
      error is StateError ? error.message : error.toString();

  Widget _meldung(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Abstand.bahn),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// Ersetzt [bisher] in der frisch geladenen [liste] durch [ersatz] (oder
/// entfernt es bei `null`). Fehlt der Eintrag inzwischen, wird nicht geraten.
List<HeroMerkmal> _ersetze(
  List<HeroMerkmal> liste,
  HeroMerkmal bisher,
  HeroMerkmal? ersatz,
) {
  final index = liste.indexOf(bisher);
  if (index < 0) {
    throw StateError('Der Eintrag wurde inzwischen geändert.');
  }
  final neu = List<HeroMerkmal>.of(liste);
  if (ersatz == null) {
    neu.removeAt(index);
  } else {
    neu[index] = ersatz;
  }
  return neu;
}

/// Aktionen an einer Merkmalskarte.
enum _Aktion { aendern, zuordnen, text, entfernen }

/// Abschnittsüberschrift mit leiser Anzahl, wie im Abenteuerblatt.
class _Kopfzeile extends StatelessWidget {
  const _Kopfzeile({required this.titel, required this.anzahl});

  final String titel;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(child: Text(titel, style: texte.abschnitt)),
        if (anzahl > 0) ...[
          const SizedBox(width: Abstand.normal),
          Text('$anzahl', style: texte.etikett),
        ],
      ],
    );
  }
}

/// Hinweis auf eine Textänderung durch eine ältere App-Version.
class _Abweichung extends StatelessWidget {
  const _Abweichung({
    super.key,
    required this.schluessel,
    required this.abweichung,
    required this.entscheidbar,
    required this.onEntscheiden,
  });

  final String schluessel;
  final MerkmalAbweichung abweichung;
  final bool entscheidbar;
  final ValueChanged<bool> onEntscheiden;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return KartoFlaeche(
      stufe: KartoFlaechenstufe.senke,
      innen: const EdgeInsets.all(Abstand.weit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sync_problem_outlined, size: 18, color: karto.siegel),
              const SizedBox(width: Abstand.normal),
              Expanded(
                child: Text(
                  'Eine ältere App-Version hat diese Einträge geändert. '
                  'Wirksam bleibt die Liste, bis du entscheidest.',
                  style: texte.fliess,
                ),
              ),
            ],
          ),
          if (abweichung.hinzugefuegt.isNotEmpty) ...[
            const SizedBox(height: Abstand.normal),
            Text(
              'Neu im Text: ${abweichung.hinzugefuegt.join(', ')}',
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            ),
          ],
          if (abweichung.entfernt.isNotEmpty) ...[
            const SizedBox(height: Abstand.eng),
            Text(
              'Im Text entfernt: ${abweichung.entfernt.join(', ')}',
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            ),
          ],
          const SizedBox(height: Abstand.weit),
          Wrap(
            spacing: Abstand.normal,
            runSpacing: Abstand.normal,
            children: [
              FilledButton(
                key: ValueKey<String>('karto-merkmal-text-$schluessel'),
                onPressed: entscheidbar ? () => onEntscheiden(true) : null,
                child: const Text('Geänderten Text übernehmen'),
              ),
              OutlinedButton(
                key: ValueKey<String>('karto-merkmal-liste-$schluessel'),
                onPressed: entscheidbar ? () => onEntscheiden(false) : null,
                child: const Text('Liste behalten'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Meldung mit Symbol, etwa Schreibschutz oder Fehler.
class _Hinweiszeile extends StatelessWidget {
  const _Hinweiszeile({
    super.key,
    required this.symbol,
    required this.text,
    required this.farbe,
  });

  final IconData symbol;
  final String text;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return KartoFlaeche(
      stufe: KartoFlaechenstufe.senke,
      innen: const EdgeInsets.all(Abstand.weit),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(symbol, size: 18, color: farbe),
          const SizedBox(width: Abstand.normal),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.fliess.copyWith(color: farbe),
            ),
          ),
        ],
      ),
    );
  }
}
