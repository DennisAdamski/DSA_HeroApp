import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_orientieren_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kontext_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_vorgaben_rules.dart';

/// Platzsparende Rundensteuerung mit direkter, verbindlicher Umwandlungsansage.
class GefechtRundenleiste extends StatelessWidget {
  /// Bekommt nur bereits berechnete Werte und geprüfte Änderungswege.
  const GefechtRundenleiste({
    super.key,
    required this.zustand,
    required this.werte,
    required this.onAendern,
    required this.onRunde,
    required this.gesperrt,
    required this.onAktion,
  });
  final Gefechtszustand zustand;
  final Gefechtswerte werte;
  final ValueChanged<Gefechtszustand> onAendern;
  final VoidCallback onRunde;
  final bool gesperrt;
  final Future<void> Function(Future<void> Function()) onAktion;
  @override
  Widget build(BuildContext context) {
    final s = zustand;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Runde ${s.runde}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Chip(label: Text('INI ${gefechtsInitiative(s, werte)}')),
                Chip(
                  label: Text(
                    'AT ${gefechtsAngriffe(s)} · PA ${gefechtsParaden(s, werte)}',
                  ),
                ),
                Chip(label: Text('Frei ${gefechtFreieMarken(s, werte)}')),
                Chip(label: Text('Zusatz ${gefechtZusatzMarken(s, werte)}')),
                FilledButton.tonal(
                  onPressed: gesperrt ? null : onRunde,
                  child: const Text('Nächste Runde'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (werte.klingentaenzerAktiv)
              const Text(
                'Klingentänzer-Fähigkeiten aktiv (BE höchstens 2). Spontane Umwandlung benötigt Kampfgespür.',
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Ansage'),
                for (final u in Gefechtsumwandlung.values)
                  OutlinedButton(
                    onPressed:
                        gesperrt ||
                            !gefechtUmwandlungMoeglich(s, u, werte: werte)
                        ? null
                        : () => onAktion(() => _umwandeln(context, u)),
                    child: Text(
                      '${s.umwandlung == u ? '✓ ' : ''}${switch (u) {
                        Gefechtsumwandlung.normal => 'AT + PA',
                        Gefechtsumwandlung.zweiteAttacke => '2 AT',
                        Gefechtsumwandlung.zweiteParade => '2 PA',
                      }}',
                    ),
                  ),
                SizedBox(
                  width: 125,
                  child: DropdownButtonFormField<Gefechtshaltung>(
                    isExpanded: true,
                    key: ValueKey(s.haltung),
                    initialValue: s.haltung,
                    decoration: const InputDecoration(labelText: 'Haltung'),
                    items: [
                      for (final h in Gefechtshaltung.values)
                        DropdownMenuItem(
                          value: h,
                          child: Text(switch (h) {
                            Gefechtshaltung.stehend => 'Stehend',
                            Gefechtshaltung.kniend => 'Kniend',
                            Gefechtshaltung.liegend => 'Liegend',
                          }),
                        ),
                    ],
                    onChanged: gesperrt
                        ? null
                        : (h) => onAendern(s.copyWith(haltung: h)),
                  ),
                ),
                SizedBox(
                  width: 95,
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    key: ValueKey(s.gegner),
                    initialValue: s.gegner,
                    decoration: const InputDecoration(labelText: 'Gegner'),
                    items: [
                      for (final n in [1, 2, 3, 4, 5, 6])
                        DropdownMenuItem(
                          value: n,
                          child: Text(n == 6 ? '6+' : '$n'),
                        ),
                    ],
                    onChanged: gesperrt
                        ? null
                        : (n) => onAendern(s.copyWith(gegner: n)),
                  ),
                ),
                SizedBox(
                  width: 205,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey(s.dk),
                    initialValue: s.dk,
                    decoration: const InputDecoration(
                      labelText: 'Distanzklasse',
                    ),
                    hint: const Text('?'),
                    items: [
                      for (final dk in ['H', 'N', 'S', 'P'])
                        DropdownMenuItem(
                          value: dk,
                          child: Text(gefechtsDistanzname(dk)),
                        ),
                    ],
                    onChanged: gesperrt
                        ? null
                        : (dk) => onAendern(s.copyWith(dk: dk)),
                  ),
                ),
                TextButton(
                  onPressed: gesperrt
                      ? null
                      : () => onAktion(() => _kontakt(context)),
                  child: Text(
                    zustand.kontext.kontakt.isEmpty
                        ? 'Gegnerkontakt'
                        : zustand.kontext.kontakt,
                  ),
                ),
                TextButton(
                  onPressed: gesperrt
                      ? null
                      : () => onAktion(() => _korrigieren(context)),
                  child: const Text('Manuelle Korrektur'),
                ),
              ],
            ),
            if (s.fixierterIniBonus != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'INI-Bonus dieser Runde fixiert: +${s.fixierterIniBonus}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Kampfgespür benötigt keinen pauschalen Zeitpunktdialog; andere Wege benennen ihn.
  Future<void> _umwandeln(BuildContext context, Gefechtsumwandlung u) async {
    final s = zustand;
    final unbenutzt =
        s.angriffeVerbraucht == 0 &&
        s.paradenVerbraucht == 0 &&
        s.freieVerbraucht == 0 &&
        s.zusatzVerbraucht == 0;
    final stil =
        werte.defensiverKampfstil &&
        u == Gefechtsumwandlung.zweiteParade &&
        unbenutzt;
    if (werte.kampfgespuer && !stil) {
      onAendern(wandleGefechtUm(s, u, werte: werte, rundenbeginn: false));
      return;
    }
    final rundenbeginn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Umwandlung ansagen'),
        content: Text(
          stil
              ? 'Defensiver Kampfstil gilt nur bei Ansage zu Rundenbeginn. Eine spätere Umwandlung erhält keine Stil-Erleichterung.'
              : werte.aufmerksamkeit
              ? 'Aufmerksamkeit erlaubt die Ansage bis zur eigenen ersten INI-Phase. Der konkrete Zeitpunkt wird am Spieltisch geführt.'
              : 'Ohne Aufmerksamkeit oder Kampfgespür ist die Ansage nur zu Rundenbeginn zulässig.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          if (unbenutzt)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                stil
                    ? 'Rundenbeginn · Defensiver Kampfstil'
                    : 'Zu Rundenbeginn',
              ),
            ),
          if (werte.kampfgespuer || werte.aufmerksamkeit)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                werte.kampfgespuer
                    ? 'Spontan umwandeln'
                    : 'Vor eigener erster INI-Phase',
              ),
            ),
        ],
      ),
    );
    if (rundenbeginn != null) {
      onAendern(
        wandleGefechtUm(s, u, werte: werte, rundenbeginn: rundenbeginn),
      );
    }
  }

  // Die Korrektur ist bewusst getrennt von der verbindlichen Ansage.
  Future<void> _kontakt(BuildContext context) async {
    final text = TextEditingController(text: zustand.kontext.kontakt);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktiver Gegnerkontakt'),
        content: TextField(
          controller: text,
          decoration: const InputDecoration(labelText: 'Name / Beschreibung'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text),
            child: const Text('Kontakt wechseln'),
          ),
        ],
      ),
    );
    if (name != null && name.trim() != zustand.kontext.kontakt) {
      onAendern(
        wechsleGefechtskontakt(
          zustand,
          name,
          startDk: gefechtsStartDk(werte.waffenDk, fernkampf: werte.fernkampf),
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    text.dispose();
  }

  // Die Korrektur ist bewusst getrennt von der verbindlichen Ansage.
  Future<void> _korrigieren(BuildContext context) async {
    final verlust = TextEditingController(
      text: '${zustand.ungeklaerterIniVerlust}',
    );
    final wurf = TextEditingController(text: '${zustand.iniWurf}');
    var u = zustand.umwandlung;
    var art = IniVerlustart.ungeklaert;
    final neu = await showDialog<Gefechtszustand>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Manuelle Korrektur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Korrigiert eine Fehleingabe; ersetzt keine zulässige neue Ansage.',
              ),
              Text(
                'Kampfverluste: ${zustand.iniVerlust}; geschützt: ${zustand.geschuetzterIniVerlust}',
              ),
              DropdownButton<IniVerlustart>(
                value: art,
                items: [
                  for (final a in IniVerlustart.values)
                    DropdownMenuItem(
                      value: a,
                      child: Text(switch (a) {
                        IniVerlustart.kampf => 'Kampfverlust (rückgewinnbar)',
                        IniVerlustart.geschuetzt => 'Geschützter Verlust',
                        IniVerlustart.ungeklaert => 'Ungeklärter Verlust',
                      }),
                    ),
                ],
                onChanged: (v) => setState(() {
                  art = v!;
                }),
              ),
              TextField(
                controller: wurf,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'INI-Wurf einschließlich Orientierungsbonus',
                ),
              ),
              TextField(
                controller: verlust,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'INI-Verlust'),
              ),
              DropdownButton<Gefechtsumwandlung>(
                value: u,
                items: [
                  for (final v in Gefechtsumwandlung.values)
                    DropdownMenuItem(
                      value: v,
                      child: Text(switch (v) {
                        Gefechtsumwandlung.normal => 'AT + PA',
                        Gefechtsumwandlung.zweiteAttacke => '2 AT',
                        Gefechtsumwandlung.zweiteParade => '2 PA',
                      }),
                    ),
                ],
                onChanged: (v) => setState(() {
                  u = v!;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(verlust.text);
                final iw = int.tryParse(wurf.text);
                if (n != null && n >= 0 && iw != null && iw >= 0) {
                  Navigator.pop(
                    context,
                    korrigiereIniVerlust(
                      zustand,
                      n,
                      art,
                    ).copyWith(umwandlung: u, iniWurf: iw),
                  );
                }
              },
              child: const Text('Korrektur übernehmen'),
            ),
          ],
        ),
      ),
    );
    // Erst nach dem Ende der Dialoganimation werden die Controller freigegeben.
    if (neu != null) onAendern(neu);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    verlust.dispose();
    wurf.dispose();
  }
}
