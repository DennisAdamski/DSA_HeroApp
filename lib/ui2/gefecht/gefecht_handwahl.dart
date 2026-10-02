import 'package:flutter/material.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_hand_rules.dart';

/// Beide Handrollen verwenden dieselben Belegungsregeln wie der frische Abschluss.
class GefechtHandwahl extends StatelessWidget {
  /// Die Auswahl beginnt eine Dauerhandlung; sie speichert selbst keine Daten.
  const GefechtHandwahl({
    super.key,
    required this.config,
    required this.gesperrt,
    required this.onWahl,
  });
  final CombatConfig config;
  final bool gesperrt;
  final void Function(
    GefechtsHand,
    MainWeaponSlot?,
    OffhandEquipmentEntry?,
    int,
  )
  onWahl;

  @override
  Widget build(BuildContext context) => Column(
    children: [for (final hand in GefechtsHand.values) _hand(context, hand)],
  );

  // Nicht mögliche Kombinationen bleiben sichtbar und mit Grund deaktiviert.
  Widget _hand(BuildContext context, GefechtsHand hand) {
    final neben = hand == GefechtsHand.nebenhand;
    final n = config.offhandAssignment;
    final value = neben
        ? n.usesWeapon
              ? 'w${n.weaponIndex}'
              : n.usesEquipment
              ? 't${n.equipmentIndex}'
              : 'leer'
        : config.hasSelectedWeapon
        ? 'w${config.selectedWeaponIndex}'
        : 'leer';
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'leer', child: Text('Leer')),
    ];
    void eintrag(
      String key,
      String name,
      MainWeaponSlot? w,
      OffhandEquipmentEntry? t,
      int index,
    ) {
      String? grund;
      try {
        mitGefechtsHandbelegung(config, hand, waffe: w, teil: t, index: index);
      } catch (e) {
        grund = e.toString().replaceFirst('Bad state: ', '');
      }
      items.add(
        DropdownMenuItem(
          value: key,
          enabled: grund == null,
          child: Text(
            grund == null ? name : '$name · $grund',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    for (final e in config.weaponSlots.asMap().entries) {
      eintrag('w${e.key}', e.value.name, e.value, null, e.key);
    }
    if (neben) {
      for (final e in config.offhandEquipment.asMap().entries) {
        eintrag('t${e.key}', e.value.name, null, e.value, e.key);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('gefecht-hand-${hand.name}-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: neben ? 'Nebenhand' : 'Haupthand',
        ),
        items: items,
        onChanged: gesperrt
            ? null
            : (key) {
                if (key == null || key == value) return;
                if (key == 'leer') {
                  onWahl(hand, null, null, -1);
                  return;
                }
                final i = int.parse(key.substring(1));
                onWahl(
                  hand,
                  key.startsWith('w') ? config.weaponSlots[i] : null,
                  key.startsWith('t') ? config.offhandEquipment[i] : null,
                  i,
                );
              },
      ),
    );
  }
}

/// Unbelegte Wegsteck-/Wechseldauern werden ausdrücklich am Spieltisch bestätigt.
Future<int?> zeigeGefechtsWegstecken(BuildContext context) async {
  final c = TextEditingController();
  var ok = false;
  final result = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final dauer = int.tryParse(c.text);
        return AlertDialog(
          title: const Text('Hand freimachen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bestätigte Dauer in Aktionen',
                  ),
                  onChanged: (_) => update(() {
                    ok = false;
                  }),
                ),
                CheckboxListTile(
                  value: ok,
                  title: const Text('Wegstecken und Folgen geprüft'),
                  onChanged: (v) => update(() {
                    ok = v!;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: ok && dauer != null && dauer > 0
                  ? () => Navigator.pop(context, dauer)
                  : null,
              child: const Text('Beginnen'),
            ),
          ],
        );
      },
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  c.dispose();
  return result;
}
