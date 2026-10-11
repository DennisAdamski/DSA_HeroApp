import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';

/// Fragt einen in ein Artefakt gesprochenen Zauber ab.
///
/// Der Zauber lässt sich aus dem Katalog vorbelegen (Name, Reichweite,
/// Wirkungsdauer, AsP-Kosten nur bei eindeutiger Angabe); danach sind alle
/// Felder frei änderbar. Ohne Katalogauswahl entsteht ein freier Zauber ohne
/// `spellId`. [start] bearbeitet einen vorhandenen Zauber. Liefert `null` bei
/// Abbruch.
Future<ArtefaktZauber?> zeigeArtefaktZauberDialog(
  BuildContext context, {
  ArtefaktZauber? start,
}) {
  return showDialog<ArtefaktZauber>(
    context: context,
    builder: (_) => _ArtefaktZauberDialog(start: start),
  );
}

class _ArtefaktZauberDialog extends ConsumerStatefulWidget {
  const _ArtefaktZauberDialog({this.start});

  final ArtefaktZauber? start;

  @override
  ConsumerState<_ArtefaktZauberDialog> createState() =>
      _ArtefaktZauberDialogState();
}

class _ArtefaktZauberDialogState extends ConsumerState<_ArtefaktZauberDialog> {
  late ArtefaktZauber _zauber = widget.start ?? const ArtefaktZauber();
  final _suche = TextEditingController();
  late final _name = TextEditingController(text: _zauber.name);
  late final _repraesentation = TextEditingController(
    text: _zauber.repraesentation,
  );
  late final _zfw = TextEditingController(text: _zauber.zfw?.toString() ?? '');
  late final _zfp = TextEditingController(
    text: _zauber.zfpStern?.toString() ?? '',
  );
  late final _kosten = TextEditingController(
    text: _zauber.kostenAsp?.toString() ?? '',
  );
  late final _reichweite = TextEditingController(text: _zauber.reichweite);
  late final _dauer = TextEditingController(text: _zauber.wirkungsdauer);
  late final _ziel = TextEditingController(text: _zauber.zielHinweis);
  late final _modifikation = TextEditingController(
    text: _zauber.spontaneModifikation,
  );
  late final _notiz = TextEditingController(text: _zauber.notiz);

  @override
  void dispose() {
    for (final c in [
      _suche,
      _name,
      _repraesentation,
      _zfw,
      _zfp,
      _kosten,
      _reichweite,
      _dauer,
      _ziel,
      _modifikation,
      _notiz,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Übernimmt die Katalogwerte als Vorschlag; alles bleibt änderbar.
  void _uebernehmeKatalog(SpellDef def) {
    setState(() {
      _zauber = _zauber.copyWith(spellId: def.id);
      _name.text = def.name;
      _reichweite.text = def.range;
      _dauer.text = def.duration;
      final kosten = gefechtsFesteKosten(def.aspCost);
      _kosten.text = kosten?.toString() ?? '';
      _suche.clear();
    });
  }

  int? _zahl(TextEditingController c) => int.tryParse(c.text.trim());

  ArtefaktZauber _ergebnis() => _zauber.copyWith(
    name: _name.text.trim(),
    repraesentation: _repraesentation.text.trim(),
    zfw: _zahl(_zfw),
    zfpStern: _zahl(_zfp),
    kostenAsp: _zahl(_kosten),
    reichweite: _reichweite.text.trim(),
    wirkungsdauer: _dauer.text.trim(),
    zielHinweis: _ziel.text.trim(),
    spontaneModifikation: _modifikation.text.trim(),
    notiz: _notiz.text.trim(),
  );

  Widget _feld(
    String schluessel,
    String label,
    TextEditingController controller, {
    bool zahl = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      key: ValueKey<String>('artefakt-zauber-$schluessel'),
      controller: controller,
      maxLines: maxLines,
      keyboardType: zahl ? TextInputType.number : null,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final katalog = ref.watch(rulesCatalogProvider).asData?.value;
    final suchtext = _suche.text.trim().toLowerCase();
    final treffer = katalog == null || suchtext.isEmpty
        ? const <SpellDef>[]
        : katalog.spells
              .where((s) => s.name.toLowerCase().contains(suchtext))
              .take(6)
              .toList(growable: false);
    return AlertDialog(
      title: Text(widget.start == null ? 'Zauber hinzufügen' : 'Zauber ändern'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey<String>('artefakt-zauber-suche'),
                controller: _suche,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Aus Katalog übernehmen',
                  hintText: katalog == null
                      ? 'Katalog nicht geladen'
                      : 'Zaubername suchen',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              for (final def in treffer)
                ListTile(
                  key: ValueKey<String>('artefakt-zauber-treffer-${def.id}'),
                  dense: true,
                  title: Text(def.name),
                  subtitle: Text(def.aspCost),
                  onTap: () => _uebernehmeKatalog(def),
                ),
              if (_zauber.spellId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Katalogzauber verknüpft. Die Werte unten gehören dem '
                    'Artefakt und lassen sich frei ändern.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              _feld('name', 'Zaubername', _name),
              _feld(
                'repraesentation',
                'Repräsentation des Sprechers',
                _repraesentation,
              ),
              Row(
                children: [
                  Expanded(child: _feld('zfw', 'ZfW', _zfw, zahl: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _feld('zfp', 'ZfP*', _zfp, zahl: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _feld('kosten', 'AsP', _kosten, zahl: true)),
                ],
              ),
              _feld('reichweite', 'Reichweite', _reichweite),
              _feld('dauer', 'Wirkungsdauer', _dauer),
              _feld('ziel', 'Zielvorgabe', _ziel),
              _feld(
                'modifikation',
                'Spontane Modifikation',
                _modifikation,
                maxLines: 2,
              ),
              _feld('notiz', 'Notiz', _notiz, maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('artefakt-zauber-uebernehmen'),
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _ergebnis()),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
