import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuerblatt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_laufendes_abenteuer.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenleiste.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielaktionen.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';

/// Führt eine Laufzeitaktion aus und meldet Fehler sichtbar.
///
/// Der Workspace reicht seinen vorhandenen Re-Entrancy-Guard herein, damit ein
/// Doppelklick keine zwei Dialoge öffnet und die Spielansicht keinen zweiten
/// Fehlerweg aufmacht.
typedef KartoLaufzeitAktion = Future<void> Function(
  Future<void> Function() aktion,
);

/// Spielansicht: Ressourcen, Schnellaktionen, Kampf, Effekte und Protokoll.
///
/// Liest `heroComputedProvider(heroId)` **einmal** und reicht den Snapshot an
/// die darstellenden Abschnitte weiter; dessen vier Ableitungen werden nicht
/// zusätzlich beobachtet. Gezeigt werden ausschließlich gespeicherte Werte,
/// nie der Entwurf einer offenen Steigerungssitzung.
class KartoSpielansicht extends ConsumerWidget {
  /// Bindet die Ansicht an einen Helden und die Bestandsbrücke.
  const KartoSpielansicht({
    super.key,
    required this.heroId,
    required this.bestand,
    required this.aktion,
    required this.vorAbenteuerbearbeitung,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Übergangsbrücke zu den vorhandenen Fachansichten und Dialogen.
  final KartoBestandsAdapter bestand;

  /// Geschützter Ausführungsweg für Dialoge und Bestandsaktionen.
  final KartoLaufzeitAktion aktion;

  /// Prüft vor dem Abenteuerblatt einen offenen Verwaltungsentwurf.
  ///
  /// Der Notizen-Tab speichert seinen ganzen Entwurf über den Helden; ohne
  /// diese Prüfung überschriebe ein späteres Speichern dort die Einträge aus
  /// dem Blatt. `false` bricht das Öffnen ab.
  final Future<bool> Function() vorAbenteuerbearbeitung;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final berechnet = ref.watch(heroComputedProvider(heroId));
    if (berechnet.hasError) {
      return _meldung(
        context,
        'Spielwerte konnten nicht geladen werden: ${berechnet.error}',
        wiederholen: () => ref.invalidate(heroStateProvider(heroId)),
      );
    }
    final werte = berechnet.asData?.value;
    if (werte == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final breite = kartoBreiteFuer(constraints.maxWidth);
        final haupt = _hauptabschnitte(context, ref, werte);
        final seite = _seitenabschnitte(context, ref, werte);
        final protokoll = KartoAbschnitt(
          titel: 'Würfelprotokoll',
          child: bestand.spielProtokoll(werte),
        );
        final rand = EdgeInsets.all(breite.seitenrand);
        final kopf = _kopf(
          context,
          werte,
          kompakt: breite == KartoBreite.schmal,
        );

        // Ohne Seiteninhalt gäbe eine zweite Spalte nur leere Fläche.
        if (!breite.hatDetailspalte || seite.isEmpty) {
          return SingleChildScrollView(
            padding: rand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kopf,
                ..._mitLuecken([...haupt, ...seite, protokoll]),
                const _Abschluss(),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: rand,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              kopf,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _mitLuecken([...haupt, protokoll]),
                    ),
                  ),
                  const SizedBox(width: Abstand.bahn),
                  SizedBox(
                    width: breite.hatDreiSpalten ? 320 : 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _mitLuecken(seite),
                    ),
                  ),
                ],
              ),
              const _Abschluss(),
            ],
          ),
        );
      },
    );
  }

  // Das laufende Abenteuer traegt den Seitentitel, die Ansicht rueckt in die
  // Kontextzeile, und der ganze Kopf oeffnet das Abenteuerblatt. Ohne
  // gepflegtes Abenteuer bleibt der Kopf schlicht — ein erfundener Titel waere
  // schlimmer als gar keiner.
  KartoSeitenkopf _kopf(
    BuildContext context,
    HeroComputedSnapshot werte, {
    required bool kompakt,
  }) {
    final abenteuer = laufendesAbenteuer(werte.hero);
    if (abenteuer == null) {
      return KartoSeitenkopf(titel: 'Am Spieltisch', kompakt: kompakt);
    }
    return KartoSeitenkopf(
      titel: abenteuer.title.trim(),
      kontext: 'Am Spieltisch',
      unterzeile: abenteuerDatum(abenteuer),
      beschreibung: abenteuer.summary,
      kompakt: kompakt,
      tippHinweis: 'Abenteuer öffnen',
      tippSchluessel: const ValueKey<String>('karto-spiel-abenteuer'),
      onTap: () => aktion(() async {
        if (!await vorAbenteuerbearbeitung() || !context.mounted) return;
        await zeigeAbenteuerblatt(
          context: context,
          heroId: heroId,
          abenteuerId: abenteuer.id,
        );
      }),
    );
  }

  // Reihenfolge laut Spezifikation: Ressourcen zuerst, dann Aktionen.
  List<Widget> _hauptabschnitte(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    return <Widget>[
      KartoAbschnitt(
        titel: 'Ressourcen',
        child: KartoRessourcenleiste(
          werte: werte,
          onBearbeiten: (ressource) => aktion(
            () => bestand.ressourceBearbeiten(
              context: context,
              heroId: heroId,
              ressource: ressource,
            ),
          ),
        ),
      ),
      KartoAbschnitt(
        titel: 'Schnellaktionen',
        child: KartoSpielaktionen(
          kuerzelHinweis: 'Strg K',
          onProbeSuchen: () => aktion(
            () =>
                bestand.probeSuchen(context: context, ref: ref, heroId: heroId),
          ),
          onRast: () =>
              aktion(() => bestand.rast(context: context, heroId: heroId)),
        ),
      ),
      KartoAbschnitt(
        titel: 'Eigenschaften',
        hinweis: 'Ein Tippen würfelt die Probe',
        child: bestand.spielEigenschaftsproben(heroId: heroId, werte: werte),
      ),
    ];
  }

  // Auf breiten Fenstern steht diese Spalte neben den Spielaktionen; auf
  // schmalen folgt sie ihnen in derselben Reihenfolge. Sie sitzt eine
  // Flächenstufe tiefer, damit sie als Begleitspalte lesbar bleibt und nicht
  // mit der Hauptspalte um dieselbe Aufmerksamkeit konkurriert.
  List<Widget> _seitenabschnitte(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    return <Widget>[
      KartoAbschnitt(
        titel: 'Kampf',
        stufe: KartoFlaechenstufe.senke,
        symbol: Icons.shield_outlined,
        akzent: KartoAkzent.messing,
        child: bestand.spielKampfproben(heroId: heroId, werte: werte),
      ),
      KartoAbschnitt(
        titel: 'Aktive Effekte',
        stufe: KartoFlaechenstufe.senke,
        symbol: Icons.auto_awesome_outlined,
        akzent: KartoAkzent.astral,
        aktion: TextButton(
          key: const ValueKey<String>('karto-spiel-effekte'),
          onPressed: () =>
              aktion(() => bestand.effekte(context: context, heroId: heroId)),
          child: const Text('Effekte verwalten'),
        ),
        child: bestand.spielEffekte(heroId: heroId, werte: werte),
      ),
      KartoAbschnitt(
        titel: 'Zustand',
        stufe: KartoFlaechenstufe.senke,
        symbol: Icons.monitor_heart_outlined,
        child: bestand.spielZustand(heroId: heroId, werte: werte),
      ),
    ];
  }

  // Abschnitte bekommen einen gleichmäßigen Abstand statt eigener Ränder.
  List<Widget> _mitLuecken(List<Widget> abschnitte) {
    final ergebnis = <Widget>[];
    for (var i = 0; i < abschnitte.length; i++) {
      if (i > 0) ergebnis.add(const SizedBox(height: Abstand.bahn));
      ergebnis.add(abschnitte[i]);
    }
    return ergebnis;
  }

  // Fehlertexte bleiben auch bei großer Schrift erreichbar.
  Widget _meldung(
    BuildContext context,
    String text, {
    required VoidCallback wiederholen,
  }) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(Abstand.bahn),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          TextButton(onPressed: wiederholen, child: const Text('Wiederholen')),
        ],
      ),
    ),
  );
}

/// Leiser Schluss der Spielansicht: Zierlinie und ein Satz.
///
/// Rein dekorativ; er schliesst die Seite ab, damit sie nicht mitten im
/// Protokoll aufhoert. Kein Knopf, keine Angabe — siehe die Negativpruefungen
/// in `test/ui2/spielen/karto_spielverlauf_test.dart`.
class _Abschluss extends StatelessWidget {
  const _Abschluss();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Abstand.rand, bottom: Abstand.block),
      child: Column(
        children: [
          const KartoZierlinie(maxBreite: 360),
          const SizedBox(height: Abstand.normal),
          Text(
            'Jeder Held hat eine Geschichte.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.legende,
          ),
        ],
      ),
    );
  }
}
