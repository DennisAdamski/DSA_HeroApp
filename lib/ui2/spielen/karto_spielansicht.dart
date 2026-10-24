import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmalsblatt.dart';
import 'package:dsa_heldenverwaltung/ui2/merkmale/karto_merkmal_karten.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_breakpoints.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_bestands_adapter.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuerblatt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_begleiterkarte.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_laufendes_abenteuer.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ressourcenleiste.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielaktionen.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_wuerfelprotokoll.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_zuletzt_gewuerfelt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_seitenkopf.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_einstieg.dart';

/// Führt eine Laufzeitaktion aus und meldet Fehler sichtbar.
///
/// Der Workspace reicht seinen vorhandenen Re-Entrancy-Guard herein, damit ein
/// Doppelklick keine zwei Dialoge öffnet und die Spielansicht keinen zweiten
/// Fehlerweg aufmacht.
typedef KartoLaufzeitAktion = Future<void> Function(
  Future<void> Function() aktion,
);

/// Breite der Spielansicht, ab der Kampf, Effekte und Zustand daneben stehen.
///
/// Gemessen wird die Fläche der Ansicht, nicht das Fenster: im Workspace
/// nimmt die Bereichsnavigation 248 dp weg. Mit der Fensterschwelle
/// `kSchwelleBreit` (1024) erschien die Spalte deshalb erst ab rund 1270 dp
/// Fensterbreite, und auf üblichen Laptops standen Kampf und Zustand
/// zweieinhalb Bildschirme tief. Bei 840 bleiben der Hauptspalte neben der
/// 280 dp breiten Seitenspalte noch knapp 500 dp: drei Ressourcen in einer
/// Reihe und die Eigenschaften in zwei.
const double kSeitenspalteAb = 840;

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
    required this.vorHeldenbearbeitung,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Übergangsbrücke zu den vorhandenen Fachansichten und Dialogen.
  final KartoBestandsAdapter bestand;

  /// Geschützter Ausführungsweg für Dialoge und Bestandsaktionen.
  final KartoLaufzeitAktion aktion;

  /// Prüft vor Abenteuer- und Merkmalsblatt einen offenen Verwaltungsentwurf.
  ///
  /// Notizen- und Übersichts-Tab speichern ihren ganzen Entwurf über den
  /// Helden; ohne diese Prüfung überschriebe ein späteres Speichern dort die
  /// Einträge aus dem Blatt. `false` bricht das Öffnen ab.
  final Future<bool> Function() vorHeldenbearbeitung;

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
        final oben = _spielabschnitte(context, ref, werte);
        final unten = _nachschlagabschnitte(context, ref, werte);
        final seite = _seitenabschnitte(context, ref, werte);
        final protokoll = _protokoll(context, werte);
        final rand = EdgeInsets.all(breite.seitenrand);
        final kopf = _kopf(context, kompakt: breite == KartoBreite.schmal);

        // Ohne Seiteninhalt gäbe eine zweite Spalte nur leere Fläche. Einspaltig
        // rücken Kampf, Effekte und Zustand vor das Abenteuer: am Tisch werden
        // sie öfter gebraucht als Notizen und Personen.
        if (constraints.maxWidth < kSeitenspalteAb || seite.isEmpty) {
          return SingleChildScrollView(
            padding: rand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                kopf,
                ..._mitLuecken([...oben, ...seite, ...unten, protokoll]),
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
                      children: _mitLuecken([...oben, ...unten, protokoll]),
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

  // Titel, Datum und Kurzbeschreibung des Abenteuers stehen im Abenteuer-
  // abschnitt; der Kopf bleibt schlicht, damit sie nicht doppelt erscheinen.
  KartoSeitenkopf _kopf(BuildContext context, {required bool kompakt}) =>
      KartoSeitenkopf(titel: 'Am Spieltisch', kompakt: kompakt);

  // Der Abschnittskopf öffnet das Blatt auf einem geschützten Weg.
  Future<void> _abenteuerOeffnen(BuildContext context, String abenteuerId) =>
      aktion(() async {
        if (!await vorHeldenbearbeitung() || !context.mounted) return;
        await zeigeAbenteuerblatt(
          context: context,
          heroId: heroId,
          abenteuerId: abenteuerId,
        );
      });

  // Was am Tisch ständig gebraucht wird: Schnellaktionen, Ressourcen und die
  // Eigenschaften als schmale Würfelleiste.
  List<Widget> _spielabschnitte(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    return <Widget>[
      _schnellaktionen(context, ref, werte),
      KartoAbschnitt(
        titel: 'Ressourcen',
        dicht: true,
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
        titel: 'Eigenschaften',
        dicht: true,
        child: bestand.spielEigenschaftsproben(heroId: heroId, werte: werte),
      ),
    ];
  }

  // Die farbigen Schnellaktionen; darunter die zuletzt gewürfelten Proben, die
  // sich mit einem Tipp wiederholen lassen (SPIEL-01).
  Widget _schnellaktionen(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    return KartoAbschnitt(
      titel: 'Schnellaktionen',
      dicht: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KartoSpielaktionen(
            kuerzelHinweis: 'Strg K',
            gefecht: GefechtEinstieg(
              heroId: heroId,
              werte: werte,
              bestand: bestand,
              aktion: aktion,
              vorBearbeitung: vorHeldenbearbeitung,
              hervorgehoben: true,
              stil: kartoSchnellaktionStil(context, context.karto.messing),
              knopfKey: const ValueKey('karto-spiel-gefecht'),
            ),
            onProbeSuchen: () => aktion(
              () => bestand.probeSuchen(
                context: context,
                ref: ref,
                heroId: heroId,
              ),
            ),
            // Der Regelindex läuft nur auf Desktop und im Web und wird erst
            // angeboten, wenn die Katalog-Inhalte entsperrt sind (SPIEL-04).
            onRegeln:
                bestand.regelnNachschlagenVerfuegbar &&
                    ref.watch(catalogContentVisibleProvider)
                ? () =>
                      aktion(() => bestand.regelnNachschlagen(context: context))
                : null,
            onRast: () =>
                aktion(() => bestand.rast(context: context, heroId: heroId)),
            onSchaden: () => aktion(
              () => bestand.schadenErhalten(
                context: context,
                ref: ref,
                heroId: heroId,
              ),
            ),
          ),
          KartoZuletztGewuerfelt(
            protokoll: werte.state.diceLog,
            onWiederholen: (eintrag) => aktion(
              () => bestand.probeWiederholen(
                context: context,
                ref: ref,
                heroId: heroId,
                eintrag: eintrag,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Was man nachschlägt statt würfelt: das laufende Abenteuer mit Standort,
  // Personen und Notizen, dann die Vor- und Nachteile.
  List<Widget> _nachschlagabschnitte(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    return <Widget>[
      KartoAbenteuerAbschnitt(
        heroId: heroId,
        abenteuer: laufendesAbenteuer(werte.hero),
        standort: werte.state.standort,
        sortierung: ref.watch(abenteuerSortierungProvider),
        // Bewusst ohne `aktion`-Guard: der Dialog schließt sich selbst, und
        // das Speichern läuft über den eingereihten Zustandsweg.
        onStandortSpeichern: (standort) => bestand.standortSetzen(
          context: context,
          ref: ref,
          heroId: heroId,
          standort: standort,
        ),
        onOeffnen: () {
          final abenteuer = laufendesAbenteuer(werte.hero);
          if (abenteuer != null) _abenteuerOeffnen(context, abenteuer.id);
        },
        // Suchtreffer in anderen Abenteuern öffnen deren Blatt, auf demselben
        // geschützten Weg wie der Abschnittskopf.
        onAbenteuerOeffnen: (abenteuerId) =>
            _abenteuerOeffnen(context, abenteuerId),
      ),
      _merkmale(context, ref, werte),
    ];
  }

  // Vor- und Nachteile kompakt; bearbeitet wird im Merkmalsblatt, nach
  // derselben Editorprüfung wie beim Abenteuerblatt.
  Widget _merkmale(
    BuildContext context,
    WidgetRef ref,
    HeroComputedSnapshot werte,
  ) {
    final catalog = ref.watch(heroRulesCatalogProvider(heroId)).valueOrNull;
    // Ohne geladenen Katalog zeigt die Übersicht die gespeicherten Texte;
    // bearbeitet werden kann erst mit Katalog.
    final katalog = catalog == null
        ? MerkmalKatalog(vorteile: const [], nachteile: const [])
        : MerkmalKatalog.von(catalog);
    final abgleich = werteMerkmaleAus(werte.hero, catalog: catalog).abgleich;
    List<MerkmalAnzeige> aufbereiten(List<HeroMerkmal> liste, bool vorteil) {
      return [
        for (final eintrag in liste)
          beschreibeMerkmal(eintrag, katalog, vorteil: vorteil),
      ];
    }

    return KartoAbschnitt(
      titel: 'Vor- und Nachteile',
      aktion: TextButton(
        key: const ValueKey<String>('karto-spiel-merkmale'),
        onPressed: catalog == null
            ? null
            : () => aktion(() async {
                if (!await vorHeldenbearbeitung() || !context.mounted) return;
                await zeigeMerkmalsblatt(context: context, heroId: heroId);
              }),
        child: const Text('Bearbeiten'),
      ),
      child: KartoMerkmalsuebersicht(
        vorteile: aufbereiten(abgleich.vorteile, true),
        nachteile: aufbereiten(abgleich.nachteile, false),
      ),
    );
  }

  // Ab [kSeitenspalteAb] steht diese Spalte neben den Spielaktionen; darunter
  // folgt sie ihnen, noch vor dem Abenteuer. Sie sitzt eine
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
        aktion: GefechtEinstieg(
          heroId: heroId,
          werte: werte,
          bestand: bestand,
          aktion: aktion,
          vorBearbeitung: vorHeldenbearbeitung,
        ),
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
      // Nach „Zustand“: laufende Werte wie dort; ohne Begleiter entfällt er.
      if (werte.hero.companions.isNotEmpty)
        KartoBegleiterAbschnitt(
          begleiter: werte.hero.companions,
          zustaende: werte.state.begleiterZustaende,
          // Bewusst ohne `aktion`-Guard: jeder schnelle Klick zählt.
          onWert: (begleiter, pool, aenderung) => bestand.begleiterWertAendern(
            context: context,
            ref: ref,
            heroId: heroId,
            begleiterId: begleiter.id,
            pool: pool,
            aenderung: aenderung,
          ),
          onVertrautenAktionen: (vertrauter) => aktion(() async {
            if (!await vorHeldenbearbeitung() || !context.mounted) return;
            await bestand.vertrautenAktionen(
              context: context,
              heroId: heroId,
              begleiterId: vertrauter.id,
            );
          }),
        ),
    ];
  }

  // Am Tisch zählen die letzten Würfe; die ganze Historie samt Filtern
  // öffnet „Alle anzeigen“ in einem eigenen Blatt.
  Widget _protokoll(BuildContext context, HeroComputedSnapshot werte) {
    final anzahl = werte.state.diceLog.length;
    return KartoAbschnitt(
      titel: 'Würfelprotokoll',
      aktion: anzahl > kProtokollKurz
          ? TextButton(
              key: const ValueKey<String>('karto-spiel-protokoll-alle'),
              onPressed: () => zeigeWuerfelprotokoll(
                context: context,
                heroId: heroId,
                bestand: bestand,
              ),
              child: Text('Alle anzeigen ($anzahl)'),
            )
          : null,
      child: bestand.spielProtokoll(werte, hoechstens: kProtokollKurz),
    );
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
