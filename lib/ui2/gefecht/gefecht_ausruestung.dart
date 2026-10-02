import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_orientieren.dart';
import 'gefecht_schuss.dart';

/// Waffen und Rüstungsteile erscheinen ausschließlich in diesem Wechselpopup.
Future<void> zeigeGefechtsausruestung({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) => showDialog<void>(
  context: context,
  builder: (_) => _Ausruestung(heroId: heroId, bestand: bestand),
);

class _Ausruestung extends ConsumerStatefulWidget {
  const _Ausruestung({required this.heroId, required this.bestand});
  final String heroId;
  final KartoGefechtsAdapter bestand;
  @override
  ConsumerState<_Ausruestung> createState() => _AusruestungState();
}

class _AusruestungState extends ConsumerState<_Ausruestung> {
  bool _busy = false;
  String? _fehler;
  // Speichervorgang und Aktionsbuchung teilen sich denselben Guard.
  Future<void> _run(Future<bool> Function() aktion) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _fehler = null;
    });
    try {
      if (!await aktion() && mounted) {
        setState(() {
          _fehler =
              'Änderung nicht abgeschlossen. Ausrüstung und Aktion prüfen.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fehler = '$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref
        .watch(heroComputedProvider(widget.heroId))
        .asData
        ?.value;
    final s = ref.watch(gefechtProvider(widget.heroId));
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Ausrüstung wechseln'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_fehler != null)
                  Text(
                    _fehler!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Text(
                  'Waffen ziehen verbraucht bestätigte Aktionen. Der Wechsel wirkt erst nach Abschluss. '
                  'Schnellziehen, Scheide und Griffbereitschaft prüfen.',
                ),
                const SizedBox(height: 12),
                Text('Waffen', style: Theme.of(context).textTheme.titleMedium),
                if (snapshot == null)
                  const CircularProgressIndicator()
                else
                  for (final eintrag
                      in snapshot.hero.combatConfig.weaponSlots.asMap().entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(eintrag.value.name),
                      subtitle: Text(
                        '${eintrag.value.distanceClass} · ${eintrag.value.talentId}',
                      ),
                      trailing:
                          snapshot.hero.combatConfig.selectedWeaponIndex ==
                              eintrag.key
                          ? const Text('Geführt')
                          : TextButton(
                              onPressed: _busy || s?.handlung != null
                                  ? null
                                  : () => _run(() async {
                                      final dauer = await _ziehdauer(context);
                                      if (dauer == null || !context.mounted) {
                                        return true;
                                      }
                                      return starteGefechtswaffenwechsel(
                                        context: context,
                                        ref: ref,
                                        heroId: widget.heroId,
                                        bestand: widget.bestand,
                                        waffe: eintrag.value,
                                        index: eintrag.key,
                                        dauer: dauer,
                                      );
                                    }),
                              child: const Text('Ziehen'),
                            ),
                    ),
                const Divider(),
                Text(
                  'Rüstungsteile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Anlegestatus korrigieren; An- und Ablegedauer wird manuell außerhalb dieser Buchung berücksichtigt.',
                ),
                if (snapshot != null)
                  for (final eintrag
                      in snapshot.hero.combatConfig.armor.pieces
                          .asMap()
                          .entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(eintrag.value.name),
                      subtitle: Text(
                        'RS ${eintrag.value.rs} · BE ${eintrag.value.be}',
                      ),
                      value: eintrag.value.isActive,
                      onChanged: _busy
                          ? null
                          : (aktiv) => _run(() async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Anlegestatus korrigieren'),
                                  content: const Text(
                                    'Die erforderliche Dauer wurde am Spieltisch berücksichtigt?',
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
                                      child: const Text('Dauer berücksichtigt'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true || !context.mounted) return true;
                              return widget.bestand.gefechtsAusruestung(
                                context: context,
                                ref: ref,
                                heroId: widget.heroId,
                                aenderung: (aktuell) => mitRuestungsteil(
                                  aktuell,
                                  eintrag.value.copyWith(isActive: aktiv),
                                  ausgang: eintrag.value,
                                  index: eintrag.key,
                                ),
                              );
                            }),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  // Kein ungespeicherter Scheidenkontext wird als sichere Ziehregel angenommen.
  Future<int?> _ziehdauer(BuildContext context) async {
    final dauer = TextEditingController(text: '1');
    var bestaetigt = false;
    final ergebnis = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Waffe ziehen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: dauer,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Bestätigte Ziehdauer in Aktionen (0 erlaubt)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              CheckboxListTile(
                value: bestaetigt,
                title: const Text(
                  'Sonderfertigkeit, Scheide und Griffbereitschaft geprüft',
                ),
                onChanged: (v) => setState(() {
                  bestaetigt = v!;
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
              onPressed: bestaetigt && (int.tryParse(dauer.text) ?? -1) >= 0
                  ? () => Navigator.pop(context, int.parse(dauer.text))
                  : null,
              child: const Text('Wechsel beginnen'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    dauer.dispose();
    return ergebnis;
  }
}

/// Buchung beginnt erst nach Dauerprüfung; eine lange Ziehhandlung wirkt später.
Future<bool> starteGefechtswaffenwechsel({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  required MainWeaponSlot waffe,
  required int index,
  required int dauer,
}) async {
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final s = ref.read(gefechtProvider(heroId));
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (s == null || snapshot == null || s.handlung != null || dauer < 0) {
    return false;
  }
  final w = gefechtswerteFuer(snapshot);
  final p = pruefeManuelleGefechtsaktion(s, w, kosten: dauer == 0 ? 0 : 1);
  if (p.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(p.gruende.join(' '));
  }
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return false;
  try {
    if (dauer <= 1) {
      final gespeichert = await bestand.gefechtsAusruestung(
        context: context,
        ref: ref,
        heroId: heroId,
        aenderung: (config) => mitAktiverWaffe(config, waffe, index: index),
      );
      if (!gespeichert) return false;
    }
    if (!controller.abschliessen(id, w, p)) return false;
    final h = beginneGefechtsHandlung(
      titel: '${waffe.name} ziehen',
      dauer: dauer,
      waffenId: waffe.id,
      waffenIndex: index,
      waffe: waffe,
    );
    if (h != null) {
      controller.setzen(
        ref.read(gefechtProvider(heroId))!.copyWith(handlung: h),
      );
    }
    return true;
  } finally {
    controller.abbrechen(id);
  }
}

/// Fortsetzen bucht eine Aktion; Speicherfehler erhalten die offene Resthandlung.
Future<void> setzeGefechtsausruestungFort({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final s = ref.read(gefechtProvider(heroId));
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final h = s?.handlung;
  if (s == null || h == null || snapshot == null) return;
  if (h.art == Gefechtshandlungsart.fernkampf) {
    await uebernimmGefechtsSchuss(
      context: context,
      ref: ref,
      heroId: heroId,
      bestand: bestand,
    );
    return;
  }
  if (h.art == Gefechtshandlungsart.orientieren ||
      h.art == Gefechtshandlungsart.positionOrientieren) {
    await fuehreOrientierungFort(
      context: context,
      ref: ref,
      heroId: heroId,
      bestand: bestand,
    );
    return;
  }
  final w = gefechtswerteFuer(snapshot);
  final p = pruefeManuelleGefechtsaktion(
    s,
    w,
    kosten: 1,
    handlungFortsetzen: true,
  );
  if (p.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(p.gruende.join(' '));
  }
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return;
  void buchen() {
    if (!controller.abschliessen(id, w, p)) return;
    final neu = setzeGefechtsHandlungFort(h);
    controller.setzen(
      ref
          .read(gefechtProvider(heroId))!
          .copyWith(handlung: neu, ohneHandlung: neu == null),
    );
  }

  try {
    if (h.verbleibend == 1 && h.waffe != null) {
      final ok = await bestand.gefechtsAusruestung(
        context: context,
        ref: ref,
        heroId: heroId,
        aenderung: (config) =>
            mitAktiverWaffe(config, h.waffe, index: h.waffenIndex),
      );
      if (!ok) {
        throw StateError(
          'Waffenwechsel nicht gespeichert; Handlung bleibt offen.',
        );
      }
    }
    if (!context.mounted) return;
    if (h.verbleibend == 1 && h.probe != null) {
      await bestand.gefechtsProbe(
        context: context,
        ref: ref,
        heroId: heroId,
        request: h.probe!,
        onResolved: (_) => buchen(),
      );
    } else {
      buchen();
    }
  } finally {
    controller.abbrechen(id);
  }
}
