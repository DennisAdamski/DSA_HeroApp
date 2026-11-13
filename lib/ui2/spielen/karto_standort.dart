import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_info_chip.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_ort_feld.dart';

/// Öffnet [uri] außerhalb der App; `false` meldet, dass nichts geöffnet wurde.
typedef KartoLinkOeffner = Future<bool> Function(Uri uri);

/// Öffnet [uri] im Browser bzw. in der zuständigen App außerhalb der App.
Future<bool> oeffneExtern(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Standort des Helden als Marke samt Kartenlink, für den Abenteuerabschnitt.
///
/// Hält den aktuellen Aufenthaltsort fest und verlinkt ihn auf die
/// Avesmaps-Karte. Die Karte wird nicht eingebettet (die Seite verbietet das
/// per `X-Frame-Options`), sondern im Browser geöffnet. Gespeichert wird nur
/// der Ortsname; es werden keine Karten- oder Ortsdaten übernommen. Die
/// Eingabe schlägt Orte aus dem Ortsverzeichnis vor ([orte]), bleibt aber
/// frei. Zu bekannten Orten führt ein zweiter Link in das Wiki Aventurica. Für Regionen, Flüsse und Straßen entfällt der Kartenlink, weil
/// Avesmaps nur Siedlungen öffnet.
class KartoStandortZeile extends StatelessWidget {
  /// Erstellt die Zeile für den gespeicherten [standort].
  const KartoStandortZeile({
    super.key,
    required this.standort,
    required this.onSpeichern,
    this.oeffneLink = oeffneExtern,
    this.orte = const <OrtEintrag>[],
    this.onBearbeiten,
  });

  /// Gespeicherter Standort; leer, solange keiner festgehalten ist.
  final String standort;

  /// Speichert den bereinigten Standort; ein leerer Text entfernt ihn.
  final Future<void> Function(String standort) onSpeichern;

  /// Öffnet den Kartenlink; in Tests ersetzbar.
  final KartoLinkOeffner oeffneLink;

  /// Ortsverzeichnis für die Vorschläge; leer, solange es nicht geladen ist.
  final List<OrtEintrag> orte;

  /// Wird gerufen, bevor sich der Eingabedialog öffnet (etwa um das
  /// Ortsverzeichnis von Avesmaps anzufordern).
  final VoidCallback? onBearbeiten;

  @override
  Widget build(BuildContext context) {
    final belegt = bereinigeStandort(standort).isNotEmpty;
    final link = belegt && kartenlinkSinnvoll(standort, orte)
        ? avesmapsLink(standort)
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
      orte: orte,
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
///
/// Liefert den bereinigten Text; ein leerer Text heißt „Standort entfernen“,
/// `null` heißt abgebrochen. Gespeichert wird hier nichts.
Future<String?> zeigeStandortDialog(
  BuildContext context, {
  required String standort,
  required List<OrtEintrag> orte,
}) async {
  final neu = await showDialog<String>(
    context: context,
    builder: (_) =>
        _StandortDialog(anfang: bereinigeStandort(standort), orte: orte),
  );
  return neu == null ? null : bereinigeStandort(neu);
}

// Eingabe des Standorts. Gibt den Text zurück; „Entfernen“ gibt einen leeren
// Text zurück, Abbrechen gibt null zurück.
class _StandortDialog extends StatefulWidget {
  const _StandortDialog({required this.anfang, required this.orte});

  final String anfang;
  final List<OrtEintrag> orte;

  @override
  State<_StandortDialog> createState() => _StandortDialogState();
}

class _StandortDialogState extends State<_StandortDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.anfang,
  );

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
        autofocus: true,
        maxLength: kStandortMaxLaenge,
        onSubmitted: (text) => Navigator.of(context).pop(text),
      ),
      actions: [
        if (widget.anfang.isNotEmpty)
          TextButton(
            key: const ValueKey<String>('karto-spiel-standort-entfernen'),
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Entfernen'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-spiel-standort-speichern'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
