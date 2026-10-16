import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/ablaeufe/auxiliator_einsetzen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_auxiliator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_ladung_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/state/ablauf_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/artefakt_zauber_karte.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Öffnet den Einsatzdialog eines Zaubertalismans (Auxiliators).
///
/// Der Anwender spricht den Zauber selbst, mit Zauberdauer und eigener Probe;
/// diese Probe liefert der Aufrufer ([zfpStern], [gelungen]) oder der Nutzer
/// trägt sie ein. Der Dialog rechnet den Bonus (höchstens der ZfW des
/// Anwenders, bei fremder Repräsentation die Hälfte, nur bei einem Spruch, der
/// auch ohne Auxiliator gelungen wäre), bucht die AsP (Zauberkosten plus 1W3)
/// samt Protokoll in einem Zustandsdokument (Ablauf `AuxiliatorEinsetzen`) und
/// würfelt den Ausfallwurf der Matrix (+2 bei misslungenem Spruch). Eine dabei
/// irreparabel beschädigte Matrix wird erst über die ausdrückliche Aktion „Als
/// beschädigt markieren“ am Bogen vermerkt.
///
/// [zauberId] wählt den gesprochenen Zauber vor, [repraesentation] ist die
/// Repräsentation des Anwenders. [zauberkostenGebucht] sagt, dass der Aufrufer
/// die Zauberkosten schon (oder noch) selbst bucht – der Dialog bucht dann nur
/// die zusätzlichen 1W3 AsP.
Future<void> zeigeAuxiliator({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
  String? zauberId,
  int? zfpStern,
  bool? gelungen,
  String repraesentation = '',
  bool zauberkostenGebucht = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AuxiliatorDialog(
      heroId: heroId,
      eintrag: eintrag,
      zauberId: zauberId,
      zfpStern: zfpStern,
      gelungen: gelungen,
      repraesentation: repraesentation,
      zauberkostenGebucht: zauberkostenGebucht,
    ),
  );
}

class _AuxiliatorDialog extends ConsumerStatefulWidget {
  const _AuxiliatorDialog({
    required this.heroId,
    required this.eintrag,
    required this.zauberId,
    required this.zfpStern,
    required this.gelungen,
    required this.repraesentation,
    required this.zauberkostenGebucht,
  });

  final String heroId;
  final HeroInventoryEntry eintrag;
  final String? zauberId;
  final int? zfpStern;
  final bool? gelungen;
  final String repraesentation;
  final bool zauberkostenGebucht;

  @override
  ConsumerState<_AuxiliatorDialog> createState() => _AuxiliatorDialogState();
}

class _AuxiliatorDialogState extends ConsumerState<_AuxiliatorDialog> {
  static final math.Random _zufall = math.Random();

  late final _zfp = TextEditingController(
    text: widget.zfpStern?.toString() ?? '',
  );
  final _zfw = TextEditingController();
  late final _rep = TextEditingController(text: widget.repraesentation);
  final _bonusFeld = TextEditingController();
  final _kosten = TextEditingController();
  final _ziel = TextEditingController();
  final _w3 = TextEditingController();
  final _w20 = TextEditingController();
  final _w20Zusatz = TextEditingController();
  final _w6Hemmung = TextEditingController();

  late int _index = _startIndex();
  // Ohne Ergebnis der Probe (Handeingabe) gilt der Spruch als gelungen.
  late bool _gelungen =
      widget.gelungen ?? (widget.zfpStern == null || widget.zfpStern! > 0);
  bool? _gleichUeberschrieben;
  bool _kostenGesetzt = false;
  bool _vonHand = false;
  bool _laeuft = false;
  String? _fehler;
  AuxiliatorAnwendung? _ergebnis;
  HeroInventoryEntry? _gespeichert;
  bool _alsDefektVermerkt = false;

  int _startIndex() {
    final zauber = widget.eintrag.artefaktDaten?.zauber ?? const [];
    final id = widget.zauberId;
    if (id == null) return 0;
    final i = zauber.indexWhere((z) => z.spellId == id);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    for (final c in [
      _zfp,
      _zfw,
      _rep,
      _bonusFeld,
      _kosten,
      _ziel,
      _w3,
      _w20,
      _w20Zusatz,
      _w6Hemmung,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _wurf(int seiten) => _zufall.nextInt(seiten) + 1;

  int? _eintrag(TextEditingController c, int seiten) {
    final wert = int.tryParse(c.text.trim());
    return wert != null && wert >= 1 && wert <= seiten ? wert : null;
  }

  ArtefaktZauber? get _zauber {
    final liste = widget.eintrag.artefaktDaten?.zauber ?? const [];
    return _index >= 0 && _index < liste.length ? liste[_index] : null;
  }

  // Grundkosten laut Eingabe; sonst die gespeicherten Kosten des Zaubers,
  // außer der Aufrufer bucht die Zauberkosten selbst.
  int _grundkosten() {
    final eingabe = int.tryParse(_kosten.text.trim());
    if (_kostenGesetzt && eingabe != null) return eingabe < 0 ? 0 : eingabe;
    if (widget.zauberkostenGebucht) return 0;
    return _zauber?.kostenAsp ?? 0;
  }

  AuxiliatorBerechnung _berechnung(int? vorgabeZfw) {
    final z = _zauber;
    final gleich =
        _gleichUeberschrieben ??
        gleicheRepraesentation(_rep.text, z?.repraesentation ?? '') ??
        true;
    return berechneAuxiliatorBonus(
      gespeicherteZfp: z?.zfpStern,
      anwenderZfw: int.tryParse(_zfw.text.trim()) ?? vorgabeZfw,
      gleicheRepraesentation: gleich,
      spruchGelungen: _gelungen,
    );
  }

  Future<void> _einsetzen(int? vorgabeZfw) async {
    if (_laeuft) return;
    setState(() {
      _laeuft = true;
      _fehler = null;
    });
    try {
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
      final zauber = _zauber;
      final zfp = int.tryParse(_zfp.text.trim());
      if (zauber == null || zfp == null || zfp < 0) {
        throw StateError('Zauber und ZfP* der Probe müssen angegeben sein.');
      }
      final berechnung = _berechnung(vorgabeZfw);
      final bonusEingabe = int.tryParse(_bonusFeld.text.trim());
      final bonus = _gelungen
          ? (bonusEingabe != null && bonusEingabe >= 0
                ? bonusEingabe
                : berechnung.bonus)
          : 0;
      final aufschlag = auxiliatorAusfallAufschlag(spruchGelungen: _gelungen);
      final wuerfe = _wuerfe(daten, aufschlag);
      if (wuerfe == null) {
        throw StateError(
          'Die eingetragenen Würfelwürfe liegen außerhalb des Bereichs.',
        );
      }
      final w3 = _vonHand ? _eintrag(_w3, 3) : _wurf(3);
      if (w3 == null) {
        throw StateError('Der W3 liegt außerhalb des Bereichs 1–3.');
      }
      final anwendung = await ref
          .read(auxiliatorEinsetzenProvider)
          .setzeEin(
            heroId: widget.heroId,
            artefaktName: gespeichert.gegenstand,
            daten: daten,
            einsatz: AuxiliatorEinsatz(
              zauberName: zauber.name,
              zfpProbe: zfp,
              bonus: bonus,
              spruchGelungen: _gelungen,
              grundkosten: _grundkosten(),
              w3: w3,
              ziel: _ziel.text,
            ),
            wuerfe: wuerfe.$1,
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

  // Würfe des Ausfalltests; `null` bei Handwerten außerhalb des Bereichs.
  (MatrixWuerfe, int)? _wuerfe(ArtefaktDaten daten, int aufschlag) {
    if (!_vonHand) {
      return (
        MatrixWuerfe(w20: _wurf(20), w20Zusatz: _wurf(20), w6Hemmung: _wurf(6)),
        aufschlag,
      );
    }
    final w20 = _eintrag(_w20, 20);
    final zusatz =
        matrixBrauchtZusatzwurf(
          daten.stabilitaet,
          w20 ?? 0,
          aufschlag: aufschlag,
        )
        ? _eintrag(_w20Zusatz, 20)
        : 1;
    final hemmung = _eintrag(_w6Hemmung, 6) ?? 1;
    if (w20 == null || zusatz == null) return null;
    return (
      MatrixWuerfe(w20: w20, w20Zusatz: zusatz, w6Hemmung: hemmung),
      aufschlag,
    );
  }

  Future<void> _alsDefektMarkieren() async {
    final gespeichert = _gespeichert;
    if (gespeichert == null || _laeuft) return;
    setState(() => _laeuft = true);
    try {
      final held = await aendereHeldMitMeldung(
        context: context,
        ref: ref,
        heroId: widget.heroId,
        was: 'Beschädigung der Matrix',
        aenderung: (aktuell) => mitBeschaedigtemArtefakt(aktuell, gespeichert),
      );
      if (held != null && mounted) {
        setState(() => _alsDefektVermerkt = true);
      }
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daten = widget.eintrag.artefaktDaten;
    final name = widget.eintrag.gegenstand.isEmpty
        ? 'Zaubertalisman'
        : widget.eintrag.gegenstand;
    if (daten == null) {
      return AlertDialog(
        title: Text(name),
        content: const Text('Der Gegenstand hat keine Artefaktdaten.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      );
    }
    final snapshot = ref
        .watch(heroComputedProvider(widget.heroId))
        .asData
        ?.value;
    final ergebnis = _ergebnis;
    final spellId = _zauber?.spellId;
    final vorgabeZfw = spellId == null
        ? null
        : snapshot?.hero.spells[spellId]?.spellValue;
    final pruefung = pruefeAuxiliator(
      daten: daten,
      maxAsp: snapshot?.derivedStats.maxAsp ?? 0,
    );
    return AlertDialog(
      title: Text('$name – Auxiliator einsetzen'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: ergebnis == null
              ? _buildEingabe(context, daten, snapshot, vorgabeZfw, pruefung)
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
                key: const ValueKey<String>('auxiliator-bestaetigen'),
                onPressed: _laeuft || snapshot == null || !pruefung.moeglich
                    ? null
                    : () => _einsetzen(vorgabeZfw),
                child: const Text('Einsetzen'),
              ),
            ]
          : [
              if (ergebnis.stabilitaet.ausgang == MatrixAusgang.irreparabel &&
                  !_alsDefektVermerkt)
                OutlinedButton(
                  key: const ValueKey<String>('auxiliator-defekt'),
                  onPressed: _laeuft ? null : _alsDefektMarkieren,
                  child: const Text('Als beschädigt markieren'),
                ),
              FilledButton(
                key: const ValueKey<String>('auxiliator-schliessen'),
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ],
    );
  }

  Widget _zahlFeld(
    String schluessel,
    String label,
    TextEditingController controller, {
    String? hinweis,
    double breite = 140,
    bool neuBerechnen = true,
  }) => SizedBox(
    width: breite,
    child: TextField(
      key: ValueKey<String>('auxiliator-$schluessel'),
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: neuBerechnen ? (_) => setState(() {}) : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hinweis,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );

  Widget _buildEingabe(
    BuildContext context,
    ArtefaktDaten daten,
    dynamic snapshot,
    int? vorgabeZfw,
    AuxiliatorPruefung pruefung,
  ) {
    final texte = Theme.of(context).textTheme;
    final z = _zauber;
    final berechnung = _berechnung(vorgabeZfw);
    final probe = int.tryParse(_zfp.text.trim());
    final bonusEingabe = int.tryParse(_bonusFeld.text.trim());
    final bonus = _gelungen
        ? (bonusEingabe != null && bonusEingabe >= 0
              ? bonusEingabe
              : berechnung.bonus)
        : 0;
    final gleichAuto =
        gleicheRepraesentation(_rep.text, z?.repraesentation ?? '') ?? true;
    final gleich = _gleichUeberschrieben ?? gleichAuto;
    final aufschlag = auxiliatorAusfallAufschlag(spruchGelungen: _gelungen);
    final grund = _grundkosten();
    final maxAsp = snapshot?.derivedStats.maxAsp as int? ?? 0;
    final aktuellAsp = snapshot?.state.currentAsp as int? ?? 0;
    final erklaerung = [
      if (berechnung.nichtGelungen)
        'Ein Spruch, der ohne den Auxiliator misslungen wäre, bekommt '
            'keinen Bonus.',
      if (berechnung.ohneGespeicherteZfp)
        'Im Artefakt sind keine ZfP* für den Zauber gespeichert.',
      if (berechnung.halbiert) 'Fremde Repräsentation: nur die Hälfte.',
      if (berechnung.gedeckelt) 'Begrenzt durch den ZfW des Anwenders.',
      if (berechnung.zfwFehlt)
        'ZfW des Anwenders unbekannt: keine Begrenzung angewendet.',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Der Anwender spricht den Zauber selbst, mit Zauberdauer und '
          'eigener Probe, und lässt zusätzlich Astralenergie in den '
          'Talisman fließen: die Zauberkosten plus 1W3 AsP. Der Auxiliator '
          'liefert zusätzliche ZfP*, höchstens so viele wie der ZfW des '
          'Anwenders, und nur, wenn der Spruch auch ohne ihn gelungen wäre.',
          style: texte.bodySmall,
        ),
        const SizedBox(height: 12),
        if (daten.zauber.length > 1)
          DropdownButtonFormField<int>(
            key: const ValueKey<String>('auxiliator-zauber'),
            initialValue: _index,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Gesprochener Zauber',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (var i = 0; i < daten.zauber.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(
                    daten.zauber[i].name.isEmpty
                        ? 'Unbenannt'
                        : daten.zauber[i].name,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _index = v ?? 0),
          ),
        if (z != null) ArtefaktZauberKarte(zauber: z),
        if (z == null) const Text('Kein Zauber hinterlegt.'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _zahlFeld('zfp', 'ZfP* der Probe', _zfp),
            _zahlFeld(
              'zfw',
              'ZfW des Anwenders',
              _zfw,
              hinweis: vorgabeZfw?.toString(),
            ),
            SizedBox(
              width: 200,
              child: TextField(
                key: const ValueKey<String>('auxiliator-rep'),
                controller: _rep,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Repräsentation des Anwenders',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        SwitchListTile.adaptive(
          key: const ValueKey<String>('auxiliator-gelungen'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: _gelungen,
          onChanged: (v) => setState(() => _gelungen = v),
          title: const Text('Der Spruch wäre auch ohne Auxiliator gelungen'),
        ),
        SwitchListTile.adaptive(
          key: const ValueKey<String>('auxiliator-gleich'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: gleich,
          onChanged: (v) => setState(() => _gleichUeberschrieben = v),
          title: const Text(
            'Gleiche Repräsentation wie der gespeicherte Spruch',
          ),
          subtitle: Text(
            z == null || z.repraesentation.isEmpty
                ? 'Im Artefakt ist keine Repräsentation hinterlegt.'
                : 'Gespeichert: ${z.repraesentation}',
          ),
        ),
        const Divider(),
        Text(
          'Bonus: $bonus ZfP*'
          '${probe == null ? '' : ' · Gesamt: ${probe + bonus} ZfP*'}',
          key: const ValueKey<String>('auxiliator-bonus'),
          style: texte.titleSmall,
        ),
        for (final zeile in erklaerung) Text(zeile, style: texte.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _zahlFeld(
              'bonus-feld',
              'Bonus überschreiben',
              _bonusFeld,
              hinweis: '${berechnung.bonus}',
            ),
            SizedBox(
              width: 220,
              child: TextField(
                key: const ValueKey<String>('auxiliator-kosten'),
                controller: _kosten,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => _kostenGesetzt = true),
                decoration: InputDecoration(
                  labelText: 'Zauberkosten in AsP (ohne 1W3)',
                  hintText: '$grund',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        if (widget.zauberkostenGebucht)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Die Zauberkosten bucht der Abschluss des Zaubers; hier fallen '
              'nur die zusätzlichen 1W3 AsP an.',
              key: const ValueKey<String>('auxiliator-kosten-hinweis'),
              style: texte.bodySmall,
            ),
          ),
        Text(
          'AsP des Anwenders: $aktuellAsp / $maxAsp',
          style: texte.bodySmall,
        ),
        Text(
          'Matrix ${matrixStabilitaetLabel(daten.stabilitaet)} · '
          '${matrixRegelfassungLabel(daten.regelfassung)}'
          '${aufschlag == 0 ? '' : ' · Ausfallwurf +$aufschlag (misslungener Spruch)'}',
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
          key: const ValueKey<String>('auxiliator-ziel'),
          controller: _ziel,
          decoration: const InputDecoration(
            labelText: 'Ziel (nur fürs Protokoll)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        SwitchListTile.adaptive(
          key: const ValueKey<String>('auxiliator-von-hand'),
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
              _zahlFeld('w3', 'W3 AsP', _w3, neuBerechnen: false),
              _zahlFeld('w20', 'W20 Ausfall', _w20, neuBerechnen: false),
              _zahlFeld(
                'w20-zusatz',
                'W20 Zusatz',
                _w20Zusatz,
                neuBerechnen: false,
              ),
              _zahlFeld(
                'w6-hemmung',
                'W6 Hemmung',
                _w6Hemmung,
                neuBerechnen: false,
              ),
            ],
          ),
        if (_fehler != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _fehler!,
              key: const ValueKey<String>('auxiliator-fehler'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildErgebnis(BuildContext context, AuxiliatorAnwendung ergebnis) {
    final texte = Theme.of(context).textTheme;
    final einsatz = ergebnis.einsatz;
    final ausgang = ergebnis.stabilitaet;
    final meldung = switch (ausgang.ausgang) {
      MatrixAusgang.ok => 'Die Matrix hält ohne Zwischenfall.',
      MatrixAusgang.gehemmt =>
        'Der Auxiliator ist für ${ausgang.hemmungSr} Spielrunden gehemmt.',
      MatrixAusgang.irreparabel => 'Die Matrix ist irreparabel beschädigt.',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          einsatz.spruchGelungen
              ? 'ZfP* ${einsatz.zfpProbe} + ${einsatz.bonus} = '
                    '${einsatz.zfpGesamt}'
              : 'Spruch misslungen, kein Bonus.',
          key: const ValueKey<String>('auxiliator-ergebnis-zfp'),
          style: texte.titleSmall,
        ),
        Text(
          '${einsatz.kosten} AsP abgezogen.',
          key: const ValueKey<String>('auxiliator-gebucht'),
        ),
        Text(
          'Verbleibende AsP: ${ergebnis.zustand.currentAsp}',
          style: texte.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(meldung, key: const ValueKey<String>('auxiliator-ausgang')),
        if (ausgang.ausgang == MatrixAusgang.irreparabel)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _alsDefektVermerkt
                  ? 'Der Gegenstand ist als beschädigt vermerkt.'
                  : 'Vermerke die Beschädigung am Gegenstand, damit er nicht '
                        'erneut eingesetzt wird.',
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
