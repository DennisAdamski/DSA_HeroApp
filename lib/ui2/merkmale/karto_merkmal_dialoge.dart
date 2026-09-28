import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Auswahl im Katalogdialog: ein Katalogeintrag oder ein freier Eintrag.
class KartoMerkmalWahl {
  /// Ein Katalogeintrag wurde gewaehlt.
  const KartoMerkmalWahl.katalog(HeroTraitDef this.def);

  /// Der Nutzer moechte einen freien Eintrag anlegen.
  const KartoMerkmalWahl.frei() : def = null;

  /// Gewaehlter Katalogeintrag; `null` beim freien Eintrag.
  final HeroTraitDef? def;
}

/// Auswahl und Wert eines katalogisierten Merkmals.
typedef KartoMerkmalWerte = ({String auswahl, int? wert});

/// Ob ein Katalogeintrag Auswahl oder Wert braucht.
bool merkmalBrauchtAngaben(HeroTraitDef def) {
  return merkmalBrauchtAuswahl(def) || merkmalBrauchtWert(def);
}

/// Ob das Template eine Auswahl (`{choice}`) enthaelt.
bool merkmalBrauchtAuswahl(HeroTraitDef def) =>
    def.selectionTemplate.contains('{choice}');

/// Ob das Merkmal einen Zahlenwert traegt.
bool merkmalBrauchtWert(HeroTraitDef def) =>
    def.selectionTemplate.contains('{value}') ||
    def.valueKind == 'level' ||
    def.valueKind == 'points';

/// Zeigt die Katalogsuche fuer Vor- oder Nachteile.
Future<KartoMerkmalWahl?> zeigeMerkmalKatalog({
  required BuildContext context,
  required String art,
  required List<HeroTraitDef> defs,
}) {
  return showDialog<KartoMerkmalWahl>(
    context: context,
    builder: (_) => _KatalogDialog(art: art, defs: defs),
  );
}

/// Erfasst Auswahl und Wert eines Katalogeintrags, beim Aendern vorbelegt.
Future<KartoMerkmalWerte?> zeigeMerkmalWerte({
  required BuildContext context,
  required HeroTraitDef def,
  required List<String> auswahlen,
  String auswahl = '',
  int? wert,
}) {
  return showDialog<KartoMerkmalWerte>(
    context: context,
    builder: (_) => _WerteDialog(
      def: def,
      auswahlen: auswahlen,
      auswahl: auswahl,
      wert: wert,
    ),
  );
}

/// Erfasst oder aendert den Text eines freien Eintrags.
Future<String?> zeigeMerkmalText({
  required BuildContext context,
  required String titel,
  String text = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(titel: titel, text: text),
  );
}

/// Waehlt fuer einen mehrdeutigen Alttext einen der [kandidaten].
///
/// Liefert den Katalogeintrag, [KartoMerkmalWahl.frei] fuer „als freien
/// Eintrag behalten“ oder `null` bei Abbruch.
Future<KartoMerkmalWahl?> zeigeMerkmalKandidaten({
  required BuildContext context,
  required String text,
  required List<HeroTraitDef> kandidaten,
}) {
  return showDialog<KartoMerkmalWahl>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('„$text“ zuordnen'),
      children: [
        for (final def in kandidaten)
          SimpleDialogOption(
            key: ValueKey<String>('karto-merkmal-kandidat-${def.id}'),
            onPressed: () =>
                Navigator.of(context).pop(KartoMerkmalWahl.katalog(def)),
            child: Text(def.name),
          ),
        SimpleDialogOption(
          key: const ValueKey<String>('karto-merkmal-kandidat-frei'),
          onPressed: () =>
              Navigator.of(context).pop(const KartoMerkmalWahl.frei()),
          child: const Text('Als freien Eintrag behalten'),
        ),
      ],
    ),
  );
}

/// Fragt vor dem Entfernen eines Eintrags nach.
Future<bool> bestaetigeMerkmalEntfernen(BuildContext context, String name) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('„$name“ entfernen?'),
      content: const Text('Der Eintrag wird aus der Liste gelöscht.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-merkmal-entfernen-bestaetigen'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Entfernen'),
        ),
      ],
    ),
  ).then((ja) => ja ?? false);
}

/// Suche im Katalog; der freie Eintrag steht immer oben.
class _KatalogDialog extends StatefulWidget {
  const _KatalogDialog({required this.art, required this.defs});

  final String art;
  final List<HeroTraitDef> defs;

  @override
  State<_KatalogDialog> createState() => _KatalogDialogState();
}

class _KatalogDialogState extends State<_KatalogDialog> {
  final TextEditingController _suche = TextEditingController();

  @override
  void dispose() {
    _suche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final begriff = _suche.text.trim().toLowerCase();
    final treffer = widget.defs
        .where((def) => def.active)
        .where(
          (def) =>
              begriff.isEmpty ||
              '${def.name} ${def.costText} ${def.markers.join(' ')}'
                  .toLowerCase()
                  .contains(begriff),
        )
        .take(80)
        .toList(growable: false);
    return AlertDialog(
      title: Text('${widget.art} auswählen'),
      content: SizedBox(
        width: Breite.mittel,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const ValueKey<String>('karto-merkmal-suche'),
              controller: _suche,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Suche',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Abstand.weit),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    key: const ValueKey<String>('karto-merkmal-frei'),
                    leading: Icon(Icons.edit_note, color: karto.meer),
                    title: const Text('Freier Eintrag'),
                    subtitle: const Text('Eigenes Merkmal ohne Katalogbezug'),
                    onTap: () =>
                        Navigator.of(context)
                            .pop(const KartoMerkmalWahl.frei()),
                  ),
                  for (final def in treffer)
                    ListTile(
                      key: ValueKey<String>('karto-merkmal-katalog-${def.id}'),
                      title: Text(def.name),
                      subtitle: def.costText.isEmpty
                          ? null
                          : Text(def.costText),
                      onTap: () =>
                          Navigator.of(context)
                              .pop(KartoMerkmalWahl.katalog(def)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}

/// Wert und Auswahl eines Katalogeintrags.
///
/// Eigener State, damit die Controller erst mit der Route entsorgt werden.
class _WerteDialog extends StatefulWidget {
  const _WerteDialog({
    required this.def,
    required this.auswahlen,
    required this.auswahl,
    required this.wert,
  });

  final HeroTraitDef def;
  final List<String> auswahlen;
  final String auswahl;
  final int? wert;

  @override
  State<_WerteDialog> createState() => _WerteDialogState();
}

class _WerteDialogState extends State<_WerteDialog> {
  static const String _eigene = '__eigene__';

  late final TextEditingController _freieAuswahl = TextEditingController(
    text: widget.auswahl,
  );
  late final TextEditingController _wert = TextEditingController(
    text: (widget.wert ?? widget.def.minValue ?? 1).toString(),
  );
  late String _gewaehlt = _startAuswahl();

  bool get _mitListe => widget.auswahlen.isNotEmpty;

  String get _auswahl => !_mitListe || _gewaehlt == _eigene
      ? _freieAuswahl.text.trim()
      : _gewaehlt;

  // Vorbelegung: bestehende Auswahl aus der Liste, sonst „Eigene Eingabe“;
  // ohne freie Eingabe die erste Option.
  String _startAuswahl() {
    final bisher = widget.auswahl.trim();
    if (!_mitListe) return '';
    if (bisher.isNotEmpty) {
      if (widget.auswahlen.contains(bisher)) return bisher;
      if (widget.def.choiceFreeText) return _eigene;
    }
    return widget.def.choiceFreeText ? '' : widget.auswahlen.first;
  }

  @override
  void dispose() {
    _freieAuswahl.dispose();
    _wert.dispose();
    super.dispose();
  }

  // Klemmt den Wert gegen `minValue`/`maxValue` des Katalogeintrags.
  int _geklemmterWert() {
    final minimum = widget.def.minValue ?? 1;
    final maximum = widget.def.maxValue;
    var wert = int.tryParse(_wert.text.trim()) ?? minimum;
    if (wert < minimum) wert = minimum;
    if (maximum != null && wert > maximum) wert = maximum;
    return wert;
  }

  @override
  Widget build(BuildContext context) {
    final brauchtAuswahl = merkmalBrauchtAuswahl(widget.def);
    final brauchtWert = merkmalBrauchtWert(widget.def);
    final beschriftung = widget.def.choiceLabel.trim().isEmpty
        ? 'Auswahl'
        : widget.def.choiceLabel.trim();
    final freiesFeld = TextField(
      key: const ValueKey<String>('karto-merkmal-auswahl-frei'),
      controller: _freieAuswahl,
      decoration: InputDecoration(labelText: beschriftung),
      onChanged: (_) => setState(() {}),
    );
    final bereit = !brauchtAuswahl || _auswahl.isNotEmpty;
    return AlertDialog(
      title: Text(widget.def.name),
      content: SizedBox(
        width: Breite.klein,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.def.costText.isNotEmpty) ...[
              Text(
                widget.def.costText,
                style: Theme.of(context).textTheme.fliess
                    .copyWith(color: context.karto.schriftLeise),
              ),
              const SizedBox(height: Abstand.weit),
            ],
            if (brauchtAuswahl && _mitListe)
              DropdownButtonFormField<String>(
                key: const ValueKey<String>('karto-merkmal-auswahl'),
                initialValue: _gewaehlt.isEmpty ? null : _gewaehlt,
                isExpanded: true,
                decoration: InputDecoration(labelText: beschriftung),
                items: [
                  for (final auswahl in widget.auswahlen)
                    DropdownMenuItem<String>(
                      value: auswahl,
                      child: Text(auswahl, overflow: TextOverflow.ellipsis),
                    ),
                  if (widget.def.choiceFreeText)
                    const DropdownMenuItem<String>(
                      value: _eigene,
                      child: Text('Eigene Eingabe …'),
                    ),
                ],
                onChanged: (wert) => setState(() => _gewaehlt = wert ?? ''),
              ),
            if (brauchtAuswahl && !_mitListe) freiesFeld,
            if (brauchtAuswahl && _mitListe && _gewaehlt == _eigene) ...[
              const SizedBox(height: Abstand.weit),
              freiesFeld,
            ],
            if (brauchtAuswahl && brauchtWert)
              const SizedBox(height: Abstand.weit),
            if (brauchtWert)
              TextField(
                key: const ValueKey<String>('karto-merkmal-wert'),
                controller: _wert,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: widget.def.unit.isEmpty ? 'Wert' : widget.def.unit,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-merkmal-uebernehmen'),
          onPressed: bereit
              ? () {
                  final KartoMerkmalWerte ergebnis = (
                    auswahl: brauchtAuswahl ? _auswahl : '',
                    wert: brauchtWert ? _geklemmterWert() : null,
                  );
                  Navigator.of(context).pop(ergebnis);
                }
              : null,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}

/// Text eines freien Eintrags.
class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.titel, required this.text});

  final String titel;
  final String text;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.text,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titel),
      content: SizedBox(
        width: Breite.klein,
        child: TextField(
          key: const ValueKey<String>('karto-merkmal-text'),
          controller: _text,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Eintrag'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-merkmal-text-uebernehmen'),
          onPressed: () => Navigator.of(context).pop(_text.text.trim()),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
