import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_lage_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_info_chip.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ort_feld.dart';

/// Öffnet [uri] außerhalb der App; `false` meldet, dass nichts geöffnet wurde.
typedef KartoLinkOeffner = Future<bool> Function(Uri uri);

/// Öffnet [uri] im Browser bzw. in der zuständigen App außerhalb der App.
Future<bool> oeffneExtern(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Ein neuer Standort: der bereinigte Text und, falls bekannt, die
/// Avesmaps-Kennung des gewählten Orts.
///
/// Die Kennung stammt aus einer ausdrücklichen Auswahl (Vorschlag der
/// Ortseingabe, Ort der Karte, Reiseziel); einen eindeutigen Namen ohne
/// Auswahl verknüpft der Schreibweg selbst. Ein leerer [standort] heißt
/// „Standort entfernen“.
@immutable
class KartoStandortWahl {
  /// Erstellt die Wahl.
  const KartoStandortWahl(this.standort, {this.ortId = ''});

  /// Bereinigter Ortsname; leer entfernt den Standort.
  final String standort;

  /// Avesmaps-Kennung des gewählten Orts; leer ohne Auswahl.
  final String ortId;

  @override
  bool operator ==(Object other) =>
      other is KartoStandortWahl &&
      other.standort == standort &&
      other.ortId == ortId;

  @override
  int get hashCode => Object.hash(standort, ortId);

  @override
  String toString() => 'KartoStandortWahl($standort, ortId: $ortId)';
}

/// Speichert einen neuen Standort des Helden (frischer Zustandsweg der
/// Spielansicht, legt bei Ortswechsel eine Station an).
typedef KartoStandortSetzer = Future<void> Function(KartoStandortWahl wahl);

/// Wiki-Adresse aus den Ortsdetails von [ortId], sofern sie in dieser
/// Sitzung schon geladen sind; leer sonst.
///
/// Löst bewusst keinen Abruf aus: Listen mit vielen Orten (Reiseroute) sollen
/// nicht je Ort bei Avesmaps anfragen. Ohne Details öffnet der Rücklink den
/// Ort über seine Kennung. Lädt eine andere Ansicht die Details später (etwa
/// die Standort-Kachel oder die Infotafel der Karte), baut der Aufrufer neu.
String kartoGeladeneWikiUrl(WidgetRef ref, String ortId) {
  if (ortId.isEmpty) return '';
  final details = avesmapsOrtsdetailsProvider(ortId);
  if (!ref.watch(details.exists)) return '';
  return ref.watch(details).asData?.value?.wikiUrl ?? '';
}

/// Standort des Helden als Marke samt Kartenlink, für den Abenteuerabschnitt.
///
/// Hält den aktuellen Aufenthaltsort fest und verlinkt ihn auf die
/// Avesmaps-Karte. Die Karte wird nicht eingebettet (die Seite verbietet das
/// per `X-Frame-Options`), sondern im Browser geöffnet. Gespeichert werden
/// der Ortsname und, bei Auswahl aus dem Verzeichnis, die Kennung des Orts
/// ([standortOrtId]); der Kartenlink öffnet dann genau diesen Ort. Die
/// Eingabe schlägt Orte aus dem Ortsverzeichnis vor ([orte]), bleibt aber
/// frei. Zu bekannten Orten führt ein zweiter Link in das Wiki Aventurica. Für Regionen, Flüsse und Straßen entfällt der Kartenlink, weil
/// Avesmaps nur Siedlungen öffnet.
class KartoStandortZeile extends ConsumerWidget {
  /// Erstellt die Zeile für den gespeicherten [standort].
  const KartoStandortZeile({
    super.key,
    required this.standort,
    this.standortOrtId = '',
    required this.onSpeichern,
    this.oeffneLink = oeffneExtern,
    this.orte = const <OrtEintrag>[],
    this.onBearbeiten,
    this.liveOrte = false,
  });

  /// Gespeicherter Standort; leer, solange keiner festgehalten ist.
  final String standort;

  /// Gespeicherter Verweis auf den Avesmaps-Ort; leer ohne Verweis.
  final String standortOrtId;

  /// Speichert den neuen Standort; ein leerer Text entfernt ihn.
  final KartoStandortSetzer onSpeichern;

  /// Öffnet den Kartenlink; in Tests ersetzbar.
  final KartoLinkOeffner oeffneLink;

  /// Ortsverzeichnis für die Vorschläge; leer, solange es nicht geladen ist.
  final List<OrtEintrag> orte;

  /// Wird gerufen, bevor sich der Eingabedialog öffnet (etwa um das
  /// Ortsverzeichnis von Avesmaps anzufordern).
  final VoidCallback? onBearbeiten;

  /// Ob der Dialog nachgeladene Orte aus der laufenden Auswahlliste liest.
  /// Ohne diese Option bleibt [orte] die feste Liste für eigenständige Felder.
  final bool liveOrte;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final belegt = bereinigeStandort(standort).isNotEmpty;
    // Der Verweis zählt nur, solange er zum Namen passt.
    final ortId = eintragZumVerweis(standort, standortOrtId, orte)?.ortId ?? '';
    final link = belegt
        ? ortsKartenLink(
            name: standort,
            ortId: ortId,
            wikiUrl: kartoGeladeneWikiUrl(ref, ortId),
            orte: orte,
          )
        : null;
    final wikiLink = wikiAventuricaLink(standort, orte);

    return Wrap(
      spacing: Abstand.knapp,
      runSpacing: Abstand.knapp,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        KartoInfoChip(
          key: const ValueKey<String>('karto-spiel-standort-aendern'),
          symbol: Icons.place_outlined,
          text: belegt ? bereinigeStandort(standort) : 'Standort festhalten',
          textKey: ValueKey<String>(
            belegt ? 'karto-spiel-standort-text' : 'karto-spiel-standort-leer',
          ),
          leer: !belegt,
          onTap: () => _bearbeiten(context),
        ),
        if (link != null)
          IconButton(
            key: const ValueKey<String>('karto-spiel-standort-karte'),
            tooltip: 'Auf Avesmaps öffnen',
            onPressed: () => _oeffnen(context, link),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
        if (wikiLink != null)
          IconButton(
            key: const ValueKey<String>('karto-spiel-standort-wiki'),
            tooltip: 'Im Wiki Aventurica lesen',
            onPressed: () => _oeffnen(context, wikiLink),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
          ),
      ],
    );
  }

  Future<void> _bearbeiten(BuildContext context) async {
    onBearbeiten?.call();
    final neu = await zeigeStandortDialog(
      context,
      standort: standort,
      orte: liveOrte ? null : orte,
    );
    if (neu == null) return;
    await onSpeichern(neu);
  }

  Future<void> _oeffnen(BuildContext context, Uri link) async {
    final bote = ScaffoldMessenger.maybeOf(context);
    var geoeffnet = false;
    try {
      geoeffnet = await oeffneLink(link);
    } catch (_) {
      geoeffnet = false;
    }
    if (!geoeffnet) {
      bote?.showSnackBar(
        const SnackBar(content: Text('Der Link konnte nicht geöffnet werden.')),
      );
    }
  }
}

/// Fragt den Standort ab, vorbelegt mit [standort] und mit Vorschlägen aus
/// [orte].
/// Ohne feste Liste beobachtet der Dialog `ortsverzeichnisProvider` sowie
/// die Online-Suche, damit während der Eingabe geladene Orte verfügbar sind.
///
/// Liefert den bereinigten Text samt Kennung eines gewählten Vorschlags,
/// solange dessen Name noch im Feld steht; ein leerer Text heißt „Standort
/// entfernen“, `null` heißt abgebrochen. Gespeichert wird hier nichts.
Future<KartoStandortWahl?> zeigeStandortDialog(
  BuildContext context, {
  required String standort,
  List<OrtEintrag>? orte,
}) async {
  final neu = await showDialog<KartoStandortWahl>(
    context: context,
    builder: (_) {
      final anfang = bereinigeStandort(standort);
      if (orte != null) return _StandortDialog(anfang: anfang, orte: orte);
      return Consumer(
        builder: (context, ref, _) => _StandortDialog(
          anfang: anfang,
          orte: ref.watch(ortsverzeichnisProvider),
          onlineSuche: ref.watch(avesmapsOnlineSucheProvider),
        ),
      );
    },
  );
  if (neu == null) return null;
  return KartoStandortWahl(bereinigeStandort(neu.standort), ortId: neu.ortId);
}

// Eingabe des Standorts. Gibt die Wahl zurück; „Entfernen“ gibt einen leeren
// Text zurück, Abbrechen gibt null zurück.
class _StandortDialog extends StatefulWidget {
  const _StandortDialog({
    required this.anfang,
    required this.orte,
    this.onlineSuche,
  });

  final String anfang;
  final List<OrtEintrag> orte;
  final AvesmapsOnlineSuche? onlineSuche;

  @override
  State<_StandortDialog> createState() => _StandortDialogState();
}

class _StandortDialogState extends State<_StandortDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.anfang,
  );

  // Zuletzt gewählter Vorschlag; zählt nur, solange sein Name im Feld steht.
  OrtEintrag? _gewaehlt;

  KartoStandortWahl _wahl(String text) {
    final gewaehlt = _gewaehlt;
    final passt =
        gewaehlt != null &&
        gewaehlt.ortId.isNotEmpty &&
        bereinigeStandort(gewaehlt.name).toLowerCase() ==
            bereinigeStandort(text).toLowerCase();
    return KartoStandortWahl(text, ortId: passt ? gewaehlt.ortId : '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Standort festhalten'),
      content: KartoOrtFeld(
        feldSchluessel: const ValueKey<String>('karto-spiel-standort-feld'),
        controller: _controller,
        orte: widget.orte,
        onlineSuche: widget.onlineSuche,
        autofocus: true,
        maxLength: kStandortMaxLaenge,
        onOrtGewaehlt: (ort) => _gewaehlt = ort,
        onSubmitted: (text) => Navigator.of(context).pop(_wahl(text)),
      ),
      actions: [
        if (widget.anfang.isNotEmpty)
          TextButton(
            key: const ValueKey<String>('karto-spiel-standort-entfernen'),
            onPressed: () =>
                Navigator.of(context).pop(const KartoStandortWahl('')),
            child: const Text('Entfernen'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-spiel-standort-speichern'),
          onPressed: () => Navigator.of(context).pop(_wahl(_controller.text)),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
