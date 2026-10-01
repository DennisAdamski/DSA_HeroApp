import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';

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
                        : () => onAktion(() async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Ansage zu Rundenbeginn'),
                                content: const Text(
                                  'Zulässigen Ansagezeitpunkt prüfen: ohne globale '
                                  'Phasenuhr wird er nicht automatisch erkannt. Diese Ansage ist verbindlich.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Abbrechen'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Zeitpunkt geprüft'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              onAendern(wandleGefechtUm(s, u, werte: werte));
                            }
                          }),
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
                  width: 85,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey(s.dk),
                    initialValue: s.dk,
                    decoration: const InputDecoration(labelText: 'DK'),
                    hint: const Text('?'),
                    items: [
                      for (final dk in ['H', 'N', 'S', 'P'])
                        DropdownMenuItem(value: dk, child: Text(dk)),
                    ],
                    onChanged: gesperrt
                        ? null
                        : (dk) => onAendern(s.copyWith(dk: dk)),
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

  // Die Korrektur ist bewusst getrennt von der verbindlichen Ansage.
  Future<void> _korrigieren(BuildContext context) async {
    final verlust = TextEditingController(text: '${zustand.iniVerlust}');
    final wurf = TextEditingController(text: '${zustand.iniWurf}');
    var u = zustand.umwandlung;
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
                    korrigiereGefecht(
                      zustand,
                      iniVerlust: n,
                      umwandlung: u,
                      iniWurf: iw,
                    ),
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
