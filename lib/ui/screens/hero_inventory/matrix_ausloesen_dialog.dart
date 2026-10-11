import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Öffnet den Auslösedialog eines Matrixgebers.
///
/// Der Träger wählt nur das Ziel; Wirkung, ZfP*, Reichweite und Dauer stehen
/// im Artefakt fest, und eine Zauberprobe gibt es nicht. Der Dialog zeigt die
/// gespeicherten Werte, würfelt auf Bestätigung den Stabilitätstest der Matrix
/// und bucht die AsP des Trägers (Ablauf `MatrixAusloesen`). Eine dabei
/// irreparabel beschädigte Matrix wird erst über die ausdrückliche Aktion
/// „Als beschädigt markieren“ am Bogen vermerkt. Der Dialog verbraucht nichts
/// vom Inventar.
Future<void> zeigeMatrixAusloesen({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MatrixAusloesenDialog(heroId: heroId, eintrag: eintrag),
  );
}

class _MatrixAusloesenDialog extends ConsumerStatefulWidget {
  const _MatrixAusloesenDialog({required this.heroId, required this.eintrag});

  final String heroId;
  final HeroInventoryEntry eintrag;

  @override
  ConsumerState<_MatrixAusloesenDialog> createState() =>
      _MatrixAusloesenDialogState();
}

class _MatrixAusloesenDialogState
    extends ConsumerState<_MatrixAusloesenDialog> {
  static final math.Random _zufall = math.Random();

  final _ziel = TextEditingController();
  final _w20 = TextEditingController();
  final _w20Zusatz = TextEditingController();
  final _w6Hemmung = TextEditingController();
  final _w6Kosten = TextEditingController();

  bool _vonHand = false;
  bool _laeuft = false;
  String? _fehler;
  MatrixAnwendung? _ergebnis;
  // Der zum Zeitpunkt der Auslösung gespeicherte Eintrag.
  HeroInventoryEntry? _gespeichert;
  bool _alsDefektVermerkt = false;

  @override
  void dispose() {
    for (final c in [_ziel, _w20, _w20Zusatz, _w6Hemmung, _w6Kosten]) {
      c.dispose();
    }
    super.dispose();
  }

  int _wurf(int seiten) => _zufall.nextInt(seiten) + 1;

  // Von Hand eingetragene Würfe müssen im Würfelbereich liegen.
  int? _eintrag(TextEditingController c, int seiten) {
    final wert = int.tryParse(c.text.trim());
    return wert != null && wert >= 1 && wert <= seiten ? wert : null;
  }

  MatrixWuerfe? _wuerfe(ArtefaktDaten daten) {
    if (!_vonHand) {
      return MatrixWuerfe(
        w20: _wurf(20),
        w20Zusatz: _wurf(20),
        w6Hemmung: _wurf(6),
        w6Kosten: _wurf(6),
      );
    }
    final w20 = _eintrag(_w20, 20);
    final zusatz = matrixBrauchtZusatzwurf(daten.stabilitaet, w20 ?? 0)
        ? _eintrag(_w20Zusatz, 20)
        : 1;
    final hemmung = _eintrag(_w6Hemmung, 6) ?? 1;
    final kosten = matrixKostenMitDifferenz(daten) ? _eintrag(_w6Kosten, 6) : 1;
    if (w20 == null || zusatz == null || kosten == null) {
      return null;
    }
    return MatrixWuerfe(
      w20: w20,
      w20Zusatz: zusatz,
      w6Hemmung: hemmung,
      w6Kosten: kosten,
    );
  }

  Future<void> _ausloesen() async {
    if (_laeuft) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
      // Der Dialog zeigt einen älteren Stand; ausgelöst wird, was jetzt im
      // Bogen steht.
      final snapshot = ref
          .read(heroComputedProvider(widget.heroId))
          .asData
          ?.value;
      if (snapshot == null) {
        throw StateError('Der Held ist nicht geladen.');
      }
      final index = findeInventarEintragZurAenderung(
        snapshot.hero.inventoryEntries,
        widget.eintrag,
      );
      if (index < 0) {
        throw StateError('Der Gegenstand wurde inzwischen geändert.');
      }
      final gespeichert = snapshot.hero.inventoryEntries[index];
      final daten = gespeichert.artefaktDaten;
      if (daten == null) {
        throw StateError('Der Gegenstand ist kein Artefakt mehr.');
      }
      final wuerfe = _wuerfe(daten);
      if (wuerfe == null) {
        throw StateError(
          'Die eingetragenen Würfelwürfe liegen außerhalb des Bereichs.',
        );
      }
      final anwendung = await ref
          .read(matrixAusloesenProvider)
          .loeseAus(
            heroId: widget.heroId,
            artefaktName: gespeichert.gegenstand,
            daten: daten,
            wuerfe: wuerfe,
            ziel: _ziel.text,
          );
      if (!mounted) return;
      setState(() {
        _gespeichert = gespeichert;
        _ergebnis = anwendung;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _fehler = error is StateError ? error.message : '$error',
        );
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Future<void> _alsDefektMarkieren() async {
    final gespeichert = _gespeichert;
    final daten = gespeichert?.artefaktDaten;
    if (gespeichert == null || daten == null || _laeuft) return;
    setState(() => _laeuft = true);
    try {
      final held = await aendereHeldMitMeldung(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        was: 'Beschädigung der Matrix',
        aenderung: (aktuell) => mitGeaendertemInventarEintrag(
          aktuell,
          gespeichert,
          gespeichert.copyWith(artefaktDaten: daten.copyWith(defekt: true)),
        ),
      );
      if (held != null && mounted) {
        setState(() => _alsDefektVermerkt = true);
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Widget _zauberKarte(BuildContext context, ArtefaktZauber z) {
    final texte = Theme.of(context).textTheme;
    final zeilen = [
      [
        if (z.repraesentation.isNotEmpty) 'Repräsentation ${z.repraesentation}',
        if (z.zfw != null) 'ZfW ${z.zfw}',
        if (z.zfpStern != null) 'ZfP* ${z.zfpStern}',
        if (z.kostenAsp != null) '${z.kostenAsp} AsP',
      ].join(' · '),
      if (z.variante.isNotEmpty) 'Variante: ${z.variante}',
      if (z.reichweite.isNotEmpty) 'Reichweite: ${z.reichweite}',
      if (z.wirkungsdauer.isNotEmpty) 'Wirkungsdauer: ${z.wirkungsdauer}',
      if (z.zielHinweis.isNotEmpty) 'Zielvorgabe: ${z.zielHinweis}',
      if (z.spontaneModifikation.isNotEmpty)
        'Spontane Modifikation: ${z.spontaneModifikation}',
      if (z.notiz.isNotEmpty) z.notiz,
    ].where((t) => t.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(z.name.isEmpty ? 'Unbenannt' : z.name, style: texte.titleSmall),
          for (final zeile in zeilen) Text(zeile, style: texte.bodySmall),
        ],
      ),
    );
  }

  Widget _zahlFeld(
    String schluessel,
    String label,
    TextEditingController controller,
  ) => SizedBox(
    width: 120,
    child: TextField(
      key: ValueKey<String>('matrix-ausloesen-$schluessel'),
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final snapshot = ref
        .watch(heroComputedProvider(widget.heroId))
        .asData
        ?.value;
    final daten = widget.eintrag.artefaktDaten;
    if (daten == null) {
      return AlertDialog(
        title: Text(widget.eintrag.gegenstand),
        content: const Text('Der Gegenstand hat keine Artefaktdaten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      );
    }
    final ergebnis = _ergebnis;
    return AlertDialog(
      title: Text(
        '${widget.eintrag.gegenstand.isEmpty ? 'Matrixgeber' : widget.eintrag.gegenstand} auslösen',
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: ergebnis == null
              ? _buildEingabe(context, daten, snapshot)
              : _buildErgebnis(context, ergebnis),
        ),
      ),
      actions: ergebnis == null
          ? [
              TextButton(
                onPressed: _laeuft ? null : () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                key: const ValueKey<String>('matrix-ausloesen-bestaetigen'),
                onPressed: _laeuft || snapshot == null || daten.defekt
                    ? null
                    : _ausloesen,
                child: const Text('Auslösen'),
              ),
            ]
          : [
              if (ergebnis.stabilitaet.ausgang == MatrixAusgang.irreparabel &&
                  !_alsDefektVermerkt)
                OutlinedButton(
                  key: const ValueKey<String>('matrix-ausloesen-defekt'),
                  onPressed: _laeuft ? null : _alsDefektMarkieren,
                  child: const Text('Als beschädigt markieren'),
                ),
              FilledButton(
                key: const ValueKey<String>('matrix-ausloesen-schliessen'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ],
    );
  }

  Widget _buildEingabe(
    BuildContext context,
    ArtefaktDaten daten,
    HeroComputedSnapshot? snapshot,
  ) {
    final texte = Theme.of(context).textTheme;
    final maxAsp = snapshot?.derivedStats.maxAsp ?? 0;
    final aktuellAsp = snapshot?.state.currentAsp ?? 0;
    final pruefung = pruefeMatrixAusloesung(daten: daten, maxAsp: maxAsp);
    final grundkosten = matrixGrundkosten(daten);
    final mitDifferenz = matrixKostenMitDifferenz(daten);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Die gespeicherte Wirkung lässt sich nicht ändern. Der Träger '
          'wählt nur das Ziel und lässt die Zauber-AsP einfließen; eine '
          'Zauberprobe gibt es nicht.',
          style: texte.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final z in daten.zauber) _zauberKarte(context, z),
        if (daten.zauber.isEmpty) const Text('Kein Zauber hinterlegt.'),
        const Divider(),
        Text(
          mitDifferenz
              ? 'Kosten: $grundkosten AsP ± W6 (Fassung 2011)'
              : 'Kosten: $grundkosten AsP',
          key: const ValueKey<String>('matrix-ausloesen-kosten'),
          style: texte.titleSmall,
        ),
        Text('AsP des Trägers: $aktuellAsp / $maxAsp'),
        Text(
          'Matrix ${matrixStabilitaetLabel(daten.stabilitaet)} · '
          '${matrixRegelfassungLabel(daten.regelfassung)}',
          style: texte.bodySmall,
        ),
        if (daten.ausloeser.isNotEmpty)
          Text(
            'Auslöser: ${daten.ausloeser} (${daten.ausloeserAktionen} '
            'Aktion${daten.ausloeserAktionen == 1 ? '' : 'en'})',
            style: texte.bodySmall,
          ),
        for (final hinweis in [
          if (pruefung.sperrgrund != null) pruefung.sperrgrund!,
          ...pruefung.hinweise,
        ])
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hinweis,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('matrix-ausloesen-ziel'),
          controller: _ziel,
          decoration: const InputDecoration(
            labelText: 'Ziel (nur fürs Protokoll)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        SwitchListTile.adaptive(
          key: const ValueKey<String>('matrix-ausloesen-von-hand'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _vonHand,
          onChanged: (v) => setState(() => _vonHand = v),
          title: const Text('Würfelwürfe von Hand eintragen'),
        ),
        if (_vonHand)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _zahlFeld('w20', 'W20 Stabilität', _w20),
              _zahlFeld('w20-zusatz', 'W20 Zusatz', _w20Zusatz),
              _zahlFeld('w6-hemmung', 'W6 Hemmung', _w6Hemmung),
              if (mitDifferenz) _zahlFeld('w6-kosten', 'W6 AsP', _w6Kosten),
            ],
          ),
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('matrix-ausloesen-fehler'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildErgebnis(BuildContext context, MatrixAnwendung ergebnis) {
    final texte = Theme.of(context).textTheme;
    final ausgang = ergebnis.stabilitaet;
    final meldung = switch (ausgang.ausgang) {
      MatrixAusgang.ok => 'Die Auslösung gelingt ohne Zwischenfall.',
      MatrixAusgang.gehemmt =>
        'Die Auslösung ist für ${ausgang.hemmungSr} Spielrunden gehemmt.',
      MatrixAusgang.irreparabel => 'Die Matrix ist irreparabel beschädigt.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${ergebnis.kosten} AsP abgezogen.',
          key: const ValueKey<String>('matrix-ausloesen-gebucht'),
          style: texte.titleSmall,
        ),
        Text(
          'Verbleibende AsP: ${ergebnis.zustand.currentAsp}',
          style: texte.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(meldung, key: const ValueKey<String>('matrix-ausloesen-ausgang')),
        if (ausgang.ausgang == MatrixAusgang.irreparabel)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _alsDefektVermerkt
                  ? 'Der Gegenstand ist als beschädigt vermerkt.'
                  : 'Vermerke die Beschädigung am Gegenstand, damit er nicht '
                        'erneut ausgelöst wird.',
              style: texte.bodySmall,
            ),
          ),
        if (ausgang.ausgang != MatrixAusgang.gehemmt)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Die Wirkung gilt mit den gespeicherten Werten. Laufende '
              'Zaubereffekte pflegst du bei Bedarf im Magie-Tab.',
              style: texte.bodySmall,
            ),
          ),
        if (_fehler != null)
          Text(
            _fehler!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}
