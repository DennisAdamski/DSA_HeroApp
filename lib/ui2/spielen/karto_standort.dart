import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Öffnet [uri] außerhalb der App; `false` meldet, dass nichts geöffnet wurde.
typedef KartoLinkOeffner = Future<bool> Function(Uri uri);

Future<bool> _oeffneExtern(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Abschnitt „Standort“ der Spielansicht: hält den aktuellen Aufenthaltsort
/// des Helden fest und verlinkt ihn auf die Avesmaps-Karte.
///
/// Die Karte wird nicht eingebettet (die Seite verbietet das per
/// `X-Frame-Options`), sondern im Browser geöffnet. Gespeichert wird nur der
/// Ortsname; es werden keine Karten- oder Ortsdaten übernommen.
class KartoStandortAbschnitt extends StatelessWidget {
  /// Erstellt den Abschnitt für den gespeicherten [standort].
  const KartoStandortAbschnitt({
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
    final texte = Theme.of(context).textTheme;
    final karto = context.karto;
    final link = avesmapsLink(standort);
    final belegt = link != null;

    return KartoAbschnitt(
      titel: 'Standort',
      stufe: KartoFlaechenstufe.senke,
      symbol: Icons.place_outlined,
      aktion: TextButton(
        key: const ValueKey<String>('karto-spiel-standort-aendern'),
        onPressed: () => _bearbeiten(context),
        child: Text(belegt ? 'Ändern' : 'Festhalten'),
      ),
      child: belegt
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bereinigeStandort(standort),
                  key: const ValueKey<String>('karto-spiel-standort-text'),
                  style: texte.titleMedium,
                ),
                const SizedBox(height: Abstand.normal),
                TextButton.icon(
                  key: const ValueKey<String>('karto-spiel-standort-karte'),
                  onPressed: () => _oeffnen(context, link),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Auf Avesmaps öffnen'),
                ),
                const SizedBox(height: Abstand.eng),
                Text(
                  'Die Karte findet Orte mit eigener Seite im Wiki Aventurica.',
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                ),
              ],
            )
          : Text(
              'Noch kein Standort festgehalten.',
              key: const ValueKey<String>('karto-spiel-standort-leer'),
              style: texte.legende,
            ),
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
