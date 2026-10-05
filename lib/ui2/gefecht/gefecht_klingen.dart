import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_klingen.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_klingen_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_dkwahl.dart';
import 'gefecht_patzer.dart';
import 'gefecht_zahlfeld.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';

import 'gefecht_fehlertext.dart';

/// Erfasst vollständige Ziele und Poolverteilung vor der ersten Teilprobe.
Future<void> zeigeGefechtsKlingenbeginn({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required RulesCatalog katalog,
  required ManeuverDef manoever,
  required HeroComputedSnapshot snapshot,
  GefechtsKampfmittelwahl? kampfmittel,
}) async {
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  if (s == null) return;
  final parade = manoever.id == 'man_klingenwand';
  final wahl =
      kampfmittel ??
      gefechtsStandardKampfmittel(
        snapshot,
        parade ? Gefechtsaktion.parade : Gefechtsaktion.angriff,
      );
  if (wahl == null) throw StateError('Kein geeignetes Kampfmittel.');
  final p = pruefeGefechtsKlingenbeginn(
    s,
    snapshot,
    katalog,
    manoever,
    kampfmittel: wahl,
  );
  if (!p.ausfuehrbar) throw StateError(p.gruende.join(' '));
  final w = gefechtswerteFuer(snapshot, katalog: katalog, kampfmittel: wahl);
  final gegner = ref.read(gefechtBegegnungProvider).gegner;
  if (gegner.length < 2) throw StateError('Mindestens zwei Gegner erfassen.');
  final vorgaben = gefechtsKlingenVorgaben(s, gegner.keys.toList());
  final ids = vorgaben.gegner;
  final dk = vorgaben.dk;
  // Gewöhnlicher Nahkampfangriff ist der Regelfall; sichtbar und abwählbar.
  final normaleAbwehr = [true, true, true];
  final finte = List.generate(3, (_) => TextEditingController(text: '0'));
  final pool = TextEditingController();
  final erschwernis = TextEditingController(text: '0');
  var anzahl = 2;
  String? fehler;
  try {
    final teile = await showDialog<List<GefechtsKlingenteil>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            parade ? 'Klingenwand aufteilen' : 'Klingensturm aufteilen',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Getrennte Würfe gegen verschiedene Gegner. Jeder Gegner muss in idealer Waffen-Distanz stehen. Abwehr und Folgen bleiben pro Gegner getrennt.',
                  ),
                  if (w.klingentaenzerAktiv)
                    DropdownButtonFormField<int>(
                      initialValue: anzahl,
                      decoration: const InputDecoration(
                        labelText: 'Teilproben',
                      ),
                      items: const [
                        DropdownMenuItem(value: 2, child: Text('Zwei')),
                        DropdownMenuItem(value: 3, child: Text('Drei')),
                      ],
                      onChanged: (v) => setState(() => anzahl = v ?? 2),
                    ),
                  if (w.kampfgespuer || w.klingentaenzerAktiv)
                    TextField(
                      controller: pool,
                      decoration: const InputDecoration(
                        labelText: 'Verteilung, z. B. 10, 8',
                        helperText:
                            'Mindestens 6 je Teilprobe; Summe Ausgangswert +4.',
                      ),
                    ),
                  for (var i = 0; i < anzahl; i++) ...[
                    DropdownButtonFormField<String>(
                      initialValue: ids[i],
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Gegner ${i + 1}'),
                      items: [
                        for (final g in gegner.values)
                          DropdownMenuItem(
                            value: g.id,
                            child: Text(
                              g.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => ids[i] = v,
                    ),
                    GefechtDkWahl(
                      key: ValueKey('gefecht-klingen-dk-$i'),
                      wert: dk[i],
                      onChanged: (v) => setState(() => dk[i] = v),
                    ),
                    if (parade)
                      TextField(
                        controller: finte[i],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Gegnerische Finte',
                        ),
                      ),
                    if (parade)
                      CheckboxListTile(
                        value: normaleAbwehr[i],
                        title: const Text(
                          'Parierbarer gewöhnlicher Nahkampfangriff; keine Aufhebung des Schild-WM',
                        ),
                        onChanged: (v) =>
                            setState(() => normaleAbwehr[i] = v ?? false),
                      ),
                  ],
                  GefechtZahlfeld(
                    controller: erschwernis,
                    feldKey: const ValueKey('gefecht-klingen-erschwernis'),
                    label: 'Weitere Erschwernis',
                    minimum: null,
                    hilfe: 'Gilt für jede Teilprobe.',
                    onChanged: () => setState(() {}),
                  ),
                  if (fehler != null) Text(fehler!),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final verteilung = pool.text.trim().isEmpty
                      ? null
                      : pool.text
                            .split(',')
                            .map((v) => int.parse(v.trim()))
                            .toList();
                  final werte = gefechtsKlingenwerte(
                    p.zielwert!,
                    kampfgespuer: w.kampfgespuer,
                    klingentaenzer: w.klingentaenzerAktiv,
                    verteilung: verteilung,
                  );
                  if (werte.length != anzahl ||
                      ids.take(anzahl).contains(null) ||
                      dk.take(anzahl).contains(null) ||
                      parade && normaleAbwehr.take(anzahl).contains(false)) {
                    throw ArgumentError(
                      'Alle Ziele, Distanzklassen und konkrete Abwehrart bestätigen. Sonderangriffe am Tisch abwickeln.',
                    );
                  }
                  final t = [
                    for (var i = 0; i < anzahl; i++)
                      GefechtsKlingenteil(
                        gegnerId: ids[i]!,
                        dk: dk[i]!,
                        zielwert: werte[i],
                        finte: parade ? int.parse(finte[i].text) : 0,
                        erschwernis: int.parse(erschwernis.text.trim()),
                      ),
                  ];
                  pruefeGefechtsKlingenteile(t, w, parade: parade);
                  Navigator.pop(dialogContext, t);
                } catch (e) {
                  setState(() => fehler = gefechtsFehlertext(e));
                }
              },
              child: const Text('Aufteilung bestätigen'),
            ),
          ],
        ),
      ),
    );
    if (teile == null || !context.mounted) return;
    final frisch = ref.read(heroComputedProvider(heroId)).asData?.value;
    final aktuell = ref.read(gefechtMitInitiativeProvider(heroId));
    if (frisch == null || aktuell == null) return;
    final neu = pruefeGefechtsKlingenbeginn(
      aktuell,
      frisch,
      katalog,
      manoever,
      kampfmittel: wahl,
    );
    final aktuellW = gefechtswerteFuer(
      frisch,
      katalog: katalog,
      kampfmittel: wahl,
    );
    if (!neu.ausfuehrbar ||
        gefechtsKlingenprofilKey(aktuellW) != gefechtsKlingenprofilKey(w) ||
        neu.zielwert != p.zielwert) {
      throw StateError('Spielwerte geändert; Aufteilung erneut bestätigen.');
    }
    ref
        .read(gefechtProvider(heroId).notifier)
        .setzen(
          aktuell.copyWith(
            klingen: GefechtsKlingenstand(
              id: UniqueKey().toString(),
              parade: parade,
              kampfmittel: wahl,
              profilKey: gefechtsKlingenprofilKey(w),
              teile: teile,
              basisPruefung: p,
              schaden: gefechtsKlingenschaden(frisch, wahl),
            ),
          ),
        );
  } finally {
    // Erst nach dem Ende der Dialoganimation werden die Controller freigegeben.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    pool.dispose();
    erschwernis.dispose();
    for (final c in finte) {
      c.dispose();
    }
  }
}

/// Erhält offene Teilwürfe bei Abbruch; die erste Auswertung zahlt einmal.
class GefechtKlingenkarte extends ConsumerWidget {
  /// Verwendet denselben Probenadapter und Dialogguard wie reguläre Aktionen.
  const GefechtKlingenkarte({
    super.key,
    required this.heroId,
    required this.bestand,
    required this.gesperrt,
    required this.onAktion,
  });
  final String heroId;

  /// Löst die Gefechtsbrücke erst beim Bedienen auf; die Anzeige braucht sie nicht.
  final KartoGefechtsAdapter Function() bestand;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gefechtMitInitiativeProvider(heroId));
    final stand = s?.klingen;
    if (stand == null) return const SizedBox.shrink();
    final gegner = ref.watch(gefechtBegegnungProvider).gegner;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stand.parade
                  ? 'Klingenwand · Teilparaden'
                  : 'Klingensturm · Teilattacken',
            ),
            for (var i = 0; i < stand.teile.length; i++)
              ListTile(
                title: Text(
                  gegner[stand.teile[i].gegnerId]?.name ??
                      'Ziel nicht mehr vorhanden',
                ),
                subtitle: Text(
                  'Zielwert ${stand.teile[i].zielwert} · ${stand.teile[i].dk} · Finte ${stand.teile[i].finte}',
                ),
                trailing: stand.teile[i].ergebnis == null
                    ? FilledButton(
                        onPressed: gesperrt
                            ? null
                            : () => onAktion(() => _probe(context, ref, i)),
                        child: const Text('Teilprobe'),
                      )
                    : Text(
                        stand.teile[i].ergebnis!.success
                            ? 'Erfolg'
                            : 'Misslungen',
                      ),
              ),
            TextButton(
              onPressed: gesperrt
                  ? null
                  : () => ref
                        .read(gefechtProvider(heroId).notifier)
                        .setzen(s!.copyWith(ohneKlingen: true)),
              child: Text(
                stand.bezahlt
                    ? 'Ablauf beenden · keine Erstattung'
                    : 'Aufteilung abbrechen',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Der reservierte Auftrag schützt den ersten Wurf und jeden Doppelcallback.
  Future<void> _probe(BuildContext context, WidgetRef ref, int index) async {
    final s = ref.read(gefechtMitInitiativeProvider(heroId));
    final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
    final k = ref.read(rulesCatalogProvider).asData?.value;
    if (s == null || snapshot == null || k == null) return;
    final stand = s.klingen;
    if (stand == null) return;
    final w = gefechtswerteFuer(
      snapshot,
      katalog: k,
      kampfmittel: stand.kampfmittel,
    );
    pruefeGefechtsKlingenfortsetzung(s, w, index);
    final ziel = ref
        .read(gefechtBegegnungProvider)
        .gegner[stand.teile[index].gegnerId];
    if (ziel == null) throw StateError('Ursprüngliches Ziel fehlt.');
    final c = ref.read(gefechtProvider(heroId).notifier);
    final id = '${stand.id}:probe:$index';
    final basisRequest = gefechtsKlingenrequest(
      stand,
      stand.teile[index],
      ziel.name,
      meisterparadeBonus: stand.bezahlt ? 0 : s.meisterparadeBonus,
      ansageFolgemalus: s.ansageFolgemalus,
    );
    final request = gefechtsProbeMitBonus(basisRequest, s.mirakelbonus);
    if (!c.reservieren(id)) return;
    void buchen(ProbeResult result) {
      final raw = ref.read(gefechtProvider(heroId));
      if (raw?.auftrag != id) return;
      final neu = bucheGefechtsKlingenteil(raw!, w, index, result);
      c.abbrechen(id);
      c.setzen(neu.copyWith(ohneAuftrag: true));
      if (gefechtsBonusPasst(request, s.mirakelbonus)) {
        c.setzen(
          ref.read(gefechtProvider(heroId))!.copyWith(ohneMirakelbonus: true),
        );
      }
      starteGefechtsPatzer(
        ref: ref,
        heroId: heroId,
        auftragId: id,
        result: result,
        kampfmittel: stand.kampfmittel,
      );
    }

    try {
      final ergebnis = await bestand().gefechtsProbe(
        context: context,
        ref: ref,
        heroId: heroId,
        request: request,
        onResolved: buchen,
      );
      if (ergebnis != null) buchen(ergebnis);
    } finally {
      c.abbrechen(id);
    }
  }
}
