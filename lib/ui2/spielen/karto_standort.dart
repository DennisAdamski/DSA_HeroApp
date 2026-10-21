import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_info_chip.dart';

/// Öffnet [uri] außerhalb der App; `false` meldet, dass nichts geöffnet wurde.
typedef KartoLinkOeffner = Future<bool> Function(Uri uri);

Future<bool> _oeffneExtern(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Standort des Helden als Marke samt Kartenlink, für den Abenteuerabschnitt.
///
/// Hält den aktuellen Aufenthaltsort fest und verlinkt ihn auf die
/// Avesmaps-Karte. Die Karte wird nicht eingebettet (die Seite verbietet das
/// per `X-Frame-Options`), sondern im Browser geöffnet. Gespeichert wird nur
/// der Ortsname; es werden keine Karten- oder Ortsdaten übernommen.
class KartoStandortZeile extends StatelessWidget {
  /// Erstellt die Zeile für den gespeicherten [standort].
  const KartoStandortZeile({
    super.key,
    required this.standort,
    required this.onSpeichern,
    this.oeffneLink = _oeffneExtern,
  });

  /// Gespeicherter Standort; leer, solange keiner festgehalten ist.
  final String standort;

  /// Speichert den bereinigten Standort; ein leerer Text entfernt ihn.
  final Future<void> Function(String standort) onSpeichern;

  /// Öffnet den Kartenlink; in Tests ersetzbar.
  final KartoLinkOeffner oeffneLink;

  @override
  Widget build(BuildContext context) {
    final link = avesmapsLink(standort);
    final belegt = link != null;

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
        if (belegt)
          IconButton(
            key: const ValueKey<String>('karto-spiel-standort-karte'),
            tooltip: 'Auf Avesmaps öffnen',
            onPressed: () => _oeffnen(context, link),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
      ],
    );
  }

  Future<void> _bearbeiten(BuildContext context) async {
    final neu = await showDialog<String>(
      context: context,
      builder: (_) => _StandortDialog(anfang: bereinigeStandort(standort)),
    );
    if (neu == null) return;
    await onSpeichern(bereinigeStandort(neu));
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
        const SnackBar(
          content: Text('Die Karte konnte nicht geöffnet werden.'),
        ),
      );
    }
  }
}

// Eingabe des Standorts. Gibt den Text zurück; „Entfernen“ gibt einen leeren
// Text zurück, Abbrechen gibt null zurück.
class _StandortDialog extends StatefulWidget {
  const _StandortDialog({required this.anfang});

  final String anfang;

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
      content: TextField(
        key: const ValueKey<String>('karto-spiel-standort-feld'),
        controller: _controller,
        autofocus: true,
        maxLength: kStandortMaxLaenge,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Ort',
          hintText: 'z. B. Gareth',
        ),
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
