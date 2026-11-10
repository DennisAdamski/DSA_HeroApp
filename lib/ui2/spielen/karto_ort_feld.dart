import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/standort_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';

/// Eingabefeld für einen Ort mit Vorschlägen aus dem Ortsverzeichnis.
///
/// Der Text bleibt frei: Wer „Auf der Reichsstraße“ tippt, speichert genau
/// das. Die Vorschläge (Siedlungen, Regionen, Staaten, Flüsse, Straßen)
/// ergänzen nur; die Suche selbst liegt in `sucheOrte`. Ein Tipp auf einen
/// Vorschlag setzt dessen Namen in [controller].
///
/// Mit Eingabetaste übernimmt das Feld einen noch offenen Vorschlag; erst wenn
/// keiner mehr offen ist, ruft es [onSubmitted] mit dem getippten Text auf.
class KartoOrtFeld extends StatefulWidget {
  /// Erstellt das Feld über [controller] mit den Vorschlägen aus [orte].
  const KartoOrtFeld({
    super.key,
    required this.controller,
    required this.orte,
    this.feldSchluessel,
    this.autofocus = false,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
  });

  /// Text des Felds; gehört dem Aufrufer.
  final TextEditingController controller;

  /// Ortsverzeichnis für die Vorschläge; leer ohne Vorschläge.
  final List<OrtEintrag> orte;

  /// Schlüssel des eigentlichen Textfelds (für Tests und Zuordnung).
  final Key? feldSchluessel;

  /// Ob das Feld beim Öffnen den Fokus nimmt.
  final bool autofocus;

  /// Höchstlänge des Texts, oder `null` ohne Begrenzung.
  final int? maxLength;

  /// Wird bei jeder Änderung gerufen, auch bei Übernahme eines Vorschlags.
  final ValueChanged<String>? onChanged;

  /// Eingabetaste ohne offenen Vorschlag.
  final ValueChanged<String>? onSubmitted;

  @override
  State<KartoOrtFeld> createState() => _KartoOrtFeldState();
}

class _KartoOrtFeldState extends State<KartoOrtFeld> {
  final FocusNode _fokus = FocusNode();
  final GlobalKey _feldKey = GlobalKey();

  @override
  void dispose() {
    _fokus.dispose();
    super.dispose();
  }

  // Breite des Felds für die Vorschlagsliste; vor dem ersten Layout ein
  // Richtwert.
  double _feldBreite() {
    final box = _feldKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size.width : 320;
  }

  Iterable<OrtEintrag> _vorschlaege(TextEditingValue wert) =>
      sucheOrte(wert.text, widget.orte);

  // Offen ist ein Vorschlag, solange er sich vom getippten Text unterscheidet.
  bool _vorschlagOffen(String text) {
    final treffer = _vorschlaege(TextEditingValue(text: text));
    if (treffer.isEmpty) return false;
    return treffer.first.name != bereinigeStandort(text);
  }

  @override
  Widget build(BuildContext context) {
    // Kein LayoutBuilder: Dialoge messen ihren Inhalt über IntrinsicWidth.
    return KeyedSubtree(
      key: _feldKey,
      child: RawAutocomplete<OrtEintrag>(
        textEditingController: widget.controller,
        focusNode: _fokus,
        optionsBuilder: _vorschlaege,
        displayStringForOption: (ort) => ort.name,
        onSelected: (ort) => widget.onChanged?.call(ort.name),
        fieldViewBuilder: (context, controller, fokus, onFieldSubmitted) {
          return TextField(
            key: widget.feldSchluessel,
            controller: controller,
            focusNode: fokus,
            autofocus: widget.autofocus,
            maxLength: widget.maxLength,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Ort',
              hintText: 'z. B. Gareth, Albernia oder Reichsstraße',
            ),
            onChanged: widget.onChanged,
            // Der Fokus bleibt, solange die Eingabetaste einen Vorschlag
            // übernimmt; sonst gibt ihn der Zweig unten ab.
            onEditingComplete: () {},
            onSubmitted: (text) {
              if (_vorschlagOffen(text)) {
                onFieldSubmitted();
                widget.onChanged?.call(controller.text);
              } else {
                fokus.unfocus();
                widget.onSubmitted?.call(text);
              }
            },
          );
        },
        optionsViewBuilder: (context, onSelected, optionen) => _Vorschlagsliste(
          breite: _feldBreite(),
          optionen: optionen.toList(growable: false),
          onSelected: onSelected,
        ),
      ),
    );
  }
}

class _Vorschlagsliste extends StatelessWidget {
  const _Vorschlagsliste({
    required this.breite,
    required this.optionen,
    required this.onSelected,
  });

  final double breite;
  final List<OrtEintrag> optionen;
  final AutocompleteOnSelected<OrtEintrag> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hervorgehoben = AutocompleteHighlightedOption.of(context);
    // Eigene Material-Schicht: die Zeilen sind ListTiles auf einer Fläche.
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        key: const ValueKey<String>('karto-ort-vorschlaege'),
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 320, maxWidth: breite),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: optionen.length,
            itemBuilder: (context, index) {
              final ort = optionen[index];
              return ListTile(
                key: ValueKey<String>('karto-ort-vorschlag-$index'),
                dense: true,
                selected: index == hervorgehoben,
                title: Text(ort.name, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  ort.untertitel,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Abstand.weit,
                ),
                onTap: () => onSelected(ort),
              );
            },
          ),
        ),
      ),
    );
  }
}
