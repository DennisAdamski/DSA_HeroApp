import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';

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
    this.onRollAt,
    this.onRollPa,
    this.onRollDamage,
    this.onRollInitiative,
    this.onRollAusweichen,
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

  /// Oeffnet die Probe fuer den Angriffswert.
  final VoidCallback? onRollAt;

  /// Oeffnet die Probe fuer den Paradewert.
  final VoidCallback? onRollPa;

  /// Oeffnet den Schadenswurf.
  final VoidCallback? onRollDamage;

  /// Oeffnet den Initiativwurf.
  final VoidCallback? onRollInitiative;

  /// Oeffnet die Probe fuer Ausweichen.
  final VoidCallback? onRollAusweichen;

  @override
  Widget build(BuildContext context) {
    UiRebuildObserver.bump('combat_quick_stats');
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildRollChip(label: 'AT: $at', onPressed: onRollAt),
        if (!isRanged && pa != null)
          _buildRollChip(label: 'PA: $pa', onPressed: onRollPa),
        _buildRollChip(label: 'TP: $tpExpression', onPressed: onRollDamage),
        _buildRollChip(
          label: 'Kampf INI: $kampfInitiative',
          onPressed: onRollInitiative,
        ),
        _buildRollChip(
          label: 'Ausweichen: $ausweichen',
          onPressed: onRollAusweichen,
        ),
        Chip(label: Text('RS: $rs')),
        Chip(label: Text('eBE: $ebe')),
        if (isRanged && ladezeit != null)
          Chip(label: Text('Ladezeit: $ladezeit')),
        if (isRanged && geschosse != null)
          Chip(label: Text('Geschosse: $geschosse')),
      ],
    );
  }

  Widget _buildRollChip({
    required String label,
    required VoidCallback? onPressed,
  }) {
    final chip = Chip(
      avatar: onPressed == null
          ? null
          : const Icon(Icons.casino_outlined, size: 18),
      label: Text(label),
    );
    if (onPressed == null) {
      return chip;
    }
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: chip,
    );
  }
}
