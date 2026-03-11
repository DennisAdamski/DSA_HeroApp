import 'package:flutter/material.dart';

/// Kompakte Chip-Reihe mit den wichtigsten Kampfwerten.
///
/// Rein read-only, kein Provider-Zugriff — nimmt pure Werte entgegen.
class CombatQuickStats extends StatelessWidget {
  const CombatQuickStats({
    super.key,
    required this.at,
    required this.tpExpression,
    required this.kampfInitiative,
    required this.ausweichen,
    required this.rs,
    required this.ebe,
    this.pa,
    this.isRanged = false,
    this.ladezeit,
    this.geschosse,
  });

  /// Angriffswert.
  final int at;

  /// Paradewert (null bei Fernkampf).
  final int? pa;

  /// Trefferpunkte-Ausdruck, z.B. '1W6+3'.
  final String tpExpression;

  /// Endgueltige Kampf-Initiative.
  final int kampfInitiative;

  /// Ausweichen-Wert.
  final int ausweichen;

  /// Ruestungsschutz gesamt.
  final int rs;

  /// Effektive Behinderung.
  final int ebe;

  /// Fernkampf-Modus: PA wird ausgeblendet, Ladezeit/Geschosse angezeigt.
  final bool isRanged;

  /// Ladezeit-Anzeige (nur Fernkampf), z.B. '3 Aktionen'.
  final String? ladezeit;

  /// Geschoss-Anzahl (nur Fernkampf).
  final int? geschosse;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text('AT: $at')),
        if (!isRanged && pa != null) Chip(label: Text('PA: $pa')),
        Chip(label: Text('TP: $tpExpression')),
        Chip(label: Text('Kampf INI: $kampfInitiative')),
        Chip(label: Text('Ausweichen: $ausweichen')),
        Chip(label: Text('RS: $rs')),
        Chip(label: Text('eBE: $ebe')),
        if (isRanged && ladezeit != null)
          Chip(label: Text('Ladezeit: $ladezeit')),
        if (isRanged && geschosse != null)
          Chip(label: Text('Geschosse: $geschosse')),
      ],
    );
  }
}
