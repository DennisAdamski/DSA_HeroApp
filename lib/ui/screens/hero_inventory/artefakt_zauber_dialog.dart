import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/spell_def.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/protected_content_helpers.dart';

/// Fragt einen in ein Artefakt gesprochenen Zauber ab.
///
/// Der Zauber lässt sich aus dem Katalog vorbelegen (Name, Reichweite,
/// Wirkungsdauer, AsP-Kosten nur bei eindeutiger Angabe); danach sind alle
/// Felder frei änderbar. Bei einem Katalogzauber wählt man die Repräsentation
/// des Sprechers aus den Verbreitungen des Zaubers (oder trägt eine andere
/// ein) und, wenn der Zauber Varianten hat, eine Variante (Standard: keine).
/// Ohne Katalogauswahl entsteht ein freier Zauber ohne `spellId`. [start] bearbeitet einen vorhandenen Zauber. Liefert `null` bei
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
  static const _andere = '__andere__';
  final _suche = TextEditingController();
  final _geschuetzt = ProtectedContentCache();
  bool _repFrei = false;
  late final _varianteFrei = TextEditingController(text: _zauber.variante);
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
  late final _pAsP = TextEditingController(
    text: _zauber.pAsP?.toString() ?? '',
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
    _geschuetzt.clear();
    for (final c in [
      _suche,
      _varianteFrei,
      _name,
      _repraesentation,
      _zfw,
      _zfp,
      _kosten,
      _pAsP,
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
      _zauber = _zauber.copyWith(spellId: def.id, variante: '');
      _varianteFrei.clear();
      _name.text = def.name;
      // Gibt es nur eine Repräsentation, ist sie die Vorgabe; sonst wählt der
      // Nutzer (eine frühere Wahl, die der Zauber nicht kennt, entfällt).
      final reps = extractLearnedRepresentations(def.availability);
      if (reps.length == 1) {
        _repraesentation.text = reps.single;
        _repFrei = false;
      } else if (!reps.contains(_repraesentation.text.trim())) {
        _repraesentation.text = '';
        _repFrei = false;
      }
      _reichweite.text = def.range;
      _dauer.text = def.duration;
      final kosten = gefechtsFesteKosten(def.aspCost);
      _kosten.text = kosten?.toString() ?? '';
      _suche.clear();
    });
  }

  int? _zahl(TextEditingController c) => int.tryParse(c.text.trim());

  ArtefaktZauber _ergebnis() => _zauber.copyWith(
    variante: _zauber.variante.trim(),
    name: _name.text.trim(),
    repraesentation: _repraesentation.text.trim(),
    zfw: _zahl(_zfw),
    zfpStern: _zahl(_zfp),
    kostenAsp: _zahl(_kosten),
    pAsP: _zahl(_pAsP),
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

  // Repräsentation: bei einem Katalogzauber Auswahl aus seinen Verbreitungen
  // (plus „Andere“), sonst ein freies Textfeld.
  Widget _repraesentationFeld(SpellDef? def) {
    final reps = def == null
        ? const <String>[]
        : extractLearnedRepresentations(def.availability);
    if (reps.isEmpty) {
      return _feld(
        'repraesentation',
        'Repräsentation des Sprechers',
        _repraesentation,
      );
    }
    final aktuell = _repraesentation.text.trim();
    final frei = _repFrei || (aktuell.isNotEmpty && !reps.contains(aktuell));
    final wert = frei ? _andere : (aktuell.isEmpty ? null : aktuell);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>('artefakt-zauber-repraesentation-wahl-$wert'),
            initialValue: wert,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Repräsentation des Sprechers',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final r in reps)
                DropdownMenuItem<String>(value: r, child: Text(r)),
              const DropdownMenuItem<String>(
                value: _andere,
                child: Text('Andere …'),
              ),
            ],
            onChanged: (v) => setState(() {
              if (v == _andere) {
                _repFrei = true;
              } else if (v != null) {
                _repFrei = false;
                _repraesentation.text = v;
              }
            }),
          ),
        ),
        if (frei)
          _feld('repraesentation', 'Andere Repräsentation', _repraesentation),
      ],
    );
  }

  // Variante: Auswahl aus den Varianten des Katalogzaubers (Standard: keine).
  // Sind sie gesperrt oder gibt es keinen Katalogzauber, bleibt ein freies
  // Textfeld.
  Widget _varianteFeld(SpellDef? def) {
    final freiesFeld = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: const ValueKey<String>('artefakt-zauber-variante-frei'),
        controller: _varianteFrei,
        onChanged: (t) => _zauber = _zauber.copyWith(variante: t),
        decoration: const InputDecoration(
          labelText: 'Variante (optional)',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
    if (def == null) {
      return freiesFeld;
    }
    final varianten = _geschuetzt.resolveList(
      raw: def.rawVariantsEncrypted ?? def.variants,
      unlocked: ref.watch(catalogContentVisibleProvider),
      password: ref.watch(catalogContentPasswordProvider),
    );
    if (varianten == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Die Varianten des Zaubers sind gesperrt. Zum Auswählen den '
              'Katalog in den Einstellungen freischalten; die Variante lässt '
              'sich auch von Hand eintragen.',
              key: const ValueKey<String>('artefakt-zauber-varianten-gesperrt'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          freiesFeld,
        ],
      );
    }
    if (varianten.isEmpty) {
      return const SizedBox.shrink();
    }
    final aktuell = _zauber.variante;
    final eintraege = <String>[
      ...varianten,
      // Eine gespeicherte Variante, die der Katalog nicht (mehr) kennt, bleibt
      // auswählbar.
      if (aktuell.isNotEmpty && !varianten.contains(aktuell)) aktuell,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>('artefakt-zauber-variante-wahl-$aktuell'),
        initialValue: aktuell,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Variante',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        selectedItemBuilder: (context) => [
          const Text('Keine Variante'),
          for (final v in eintraege)
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        items: [
          const DropdownMenuItem<String>(
            value: '',
            child: Text('Keine Variante'),
          ),
          for (final v in eintraege)
            DropdownMenuItem<String>(
              value: v,
              child: Text(v, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) =>
            setState(() => _zauber = _zauber.copyWith(variante: v ?? '')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final katalog = ref.watch(rulesCatalogProvider).asData?.value;
    final spellId = _zauber.spellId;
    final def = katalog == null || spellId == null
        ? null
        : katalog.spells.where((s) => s.id == spellId).firstOrNull;
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
              _repraesentationFeld(def),
              _varianteFeld(def),
              Row(
                children: [
                  Expanded(child: _feld('zfw', 'ZfW', _zfw, zahl: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _feld('zfp', 'ZfP*', _zfp, zahl: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _feld('kosten', 'AsP', _kosten, zahl: true)),
                ],
              ),
              _feld('pasp', 'Permanente AsP dieses Zaubers', _pAsP, zahl: true),
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
