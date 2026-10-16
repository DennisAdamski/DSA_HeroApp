import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/advancement_ability_groups.dart';

import 'advancement_talent_groups.dart';

/// Farbe und Symbol einer Fähigkeitengruppe für Sprungleiste und Kopf.
///
/// Die Gruppe selbst kennt als Regelwert keine Flutter-Typen; diese Hülle
/// ergänzt die Darstellung und ist über die Gruppe wertgleich.
class FaehigkeitenGruppenAnzeige implements GruppenAnzeige {
  /// Hüllt [gruppe] für die gemeinsamen Gruppenbausteine.
  const FaehigkeitenGruppenAnzeige(this.gruppe);

  final FaehigkeitenGruppe gruppe;

  @override
  String get schluessel => gruppe.name;

  @override
  String get label => gruppe.label;

  @override
  IconData get icon => _stil(gruppe).icon;

  @override
  Color akzent(Brightness helligkeit) {
    final stil = _stil(gruppe);
    return helligkeit == Brightness.dark ? stil.dunkel : stil.hell;
  }

  @override
  bool operator ==(Object other) =>
      other is FaehigkeitenGruppenAnzeige && other.gruppe == gruppe;

  @override
  int get hashCode => gruppe.hashCode;
}

class _Stil {
  const _Stil(this.icon, this.hell, this.dunkel);
  final IconData icon;
  final Color hell;
  final Color dunkel;
}

// Familien je Bereich: Kampf rot/orange, Allgemein grün/braun, Magie
// blau/violett, Karma gold. Das Symbol trägt die Unterscheidung innerhalb.
_Stil _stil(FaehigkeitenGruppe gruppe) => switch (gruppe) {
  FaehigkeitenGruppe.kampfGrundlagen => const _Stil(
    Icons.shield_outlined,
    Color(0xFFB3261E),
    Color(0xFFFFB4AB),
  ),
  FaehigkeitenGruppe.kampfKetten => const _Stil(
    Icons.security,
    Color(0xFF8C3B1F),
    Color(0xFFF0B49C),
  ),
  FaehigkeitenGruppe.kampfWaffenmanoever => const _Stil(
    Icons.sports_martial_arts,
    Color(0xFFC0392B),
    Color(0xFFFFA89E),
  ),
  FaehigkeitenGruppe.kampfWaffenlosManoever => const _Stil(
    Icons.sports_kabaddi,
    Color(0xFFB85C00),
    Color(0xFFFFC27A),
  ),
  FaehigkeitenGruppe.kampfStile => const _Stil(
    Icons.self_improvement,
    Color(0xFF9C2F5D),
    Color(0xFFFFB0CF),
  ),
  FaehigkeitenGruppe.kampfMeister => const _Stil(
    Icons.workspace_premium,
    Color(0xFF9A6100),
    Color(0xFFF0B84A),
  ),
  FaehigkeitenGruppe.kampfFernkampf => const _Stil(
    Icons.gps_fixed,
    Color(0xFF4C7A1F),
    Color(0xFF9ACD6A),
  ),
  FaehigkeitenGruppe.kampfSpezial => const _Stil(
    Icons.pets,
    Color(0xFF00796B),
    Color(0xFF6FD6C6),
  ),
  FaehigkeitenGruppe.kampfEpisch ||
  FaehigkeitenGruppe.allgemeinEpisch ||
  FaehigkeitenGruppe.magieEpisch ||
  FaehigkeitenGruppe.karmaEpisch => const _Stil(
    Icons.stars,
    Color(0xFF6D4C41),
    Color(0xFFD7B8A8),
  ),
  FaehigkeitenGruppe.allgemeinPraxis => const _Stil(
    Icons.handyman,
    Color(0xFF4C7A1F),
    Color(0xFF9ACD6A),
  ),
  FaehigkeitenGruppe.magieTraditionen => const _Stil(
    Icons.auto_stories,
    Color(0xFF5B4BC4),
    Color(0xFFC0B8FF),
  ),
  FaehigkeitenGruppe.magieWerkstatt => const _Stil(
    Icons.science,
    Color(0xFF1F5FA8),
    Color(0xFF9CC4F5),
  ),
  FaehigkeitenGruppe.magieBeschwoerung => const _Stil(
    Icons.whatshot,
    Color(0xFF7B3FA0),
    Color(0xFFE0B3F5),
  ),
  FaehigkeitenGruppe.magiePraxis => const _Stil(
    Icons.bolt,
    Color(0xFF00839A),
    Color(0xFF7FD6E6),
  ),
  FaehigkeitenGruppe.magieWeitere || FaehigkeitenGruppe.karmaGrundlagen =>
    const _Stil(Icons.more_horiz, Color(0xFF616161), Color(0xFFBDBDBD)),
  FaehigkeitenGruppe.karmaPfad => const _Stil(
    Icons.wb_sunny,
    Color(0xFF9A6100),
    Color(0xFFF0B84A),
  ),
  FaehigkeitenGruppe.karmaLiturgien => const _Stil(
    Icons.church,
    Color(0xFFA0522D),
    Color(0xFFFFC9A8),
  ),
};
