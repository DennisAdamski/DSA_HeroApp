import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

/// Kurztexte aller wirksamen Wundabzüge für Zusammenfassungen.
///
/// Reihenfolge: allgemeine Kampfwerte, armgebundene Abzüge, zuletzt die
/// Eigenschaftsverluste für Proben in einem Eintrag, z. B.
/// `['AT −3', 'PA −3', 'FK −2', 'INI-Basis −2', 'GS −1',
/// 'Schildarm AT/PA −2', 'Proben: GE −2, FF −2, KK −2']`. Leer, wenn nichts
/// wirkt. Der Inspector und der Wundendialog zeigen dieselben Texte.
List<String> beschreibeWundAbzuege(WundEffekte effekte) {
  final teile = <String>[];
  void wert(String label, int betrag) {
    if (betrag != 0) {
      teile.add('$label ${_mitVorzeichen(betrag)}');
    }
  }

  wert('AT', effekte.atMalus);
  wert('PA', effekte.paMalus);
  wert('FK', effekte.fkMalus);
  wert('INI-Basis', effekte.iniBasisMalus);
  wert('GS', effekte.gsMalus);
  wert('Schwertarm AT/PA', effekte.schwertarmAtPaMalus);
  wert('Schildarm AT/PA', effekte.schildarmAtPaMalus);
  final eigenschaften = _eigenschaftsTexte(effekte.eigenschaftsVerluste);
  if (eigenschaften.isNotEmpty) {
    teile.add('Proben: ${eigenschaften.join(', ')}');
  }
  return teile;
}

/// Herleitung der SB-Erschwernis beim Unterdrücken von Wunden (WdS S. 83).
///
/// Einzelwunde: `4 × 3 = 12`; mehrere aus einem Treffer:
/// `8 (2 Wunden aus einem Treffer)`. Mit [halbiert] (epische KO) folgt
/// `, halbiert 6`. Der Wert entspricht `computeSbUnterdrueckungErschwernis`.
String sbUnterdrueckungHerleitung({
  required int gesamtWunden,
  int neueWunden = 1,
  bool halbiert = false,
}) {
  final voll = computeSbUnterdrueckungErschwernis(
    gesamtWunden: gesamtWunden,
    neueWunden: neueWunden,
  );
  final basis = neueWunden == 1
      ? '4 × $gesamtWunden = $voll'
      : '$voll ($neueWunden Wunden aus einem Treffer)';
  if (!halbiert) {
    return basis;
  }
  final effektiv = computeSbUnterdrueckungErschwernis(
    gesamtWunden: gesamtWunden,
    neueWunden: neueWunden,
    halbiert: true,
  );
  return '$basis, halbiert $effektiv';
}

// Eigenschaftsverluste in Charakterbogen-Reihenfolge, z. B. `GE −2`.
List<String> _eigenschaftsTexte(AttributeModifiers mods) {
  final werte = <(String, int)>[
    ('MU', mods.mu),
    ('KL', mods.kl),
    ('IN', mods.inn),
    ('CH', mods.ch),
    ('FF', mods.ff),
    ('GE', mods.ge),
    ('KO', mods.ko),
    ('KK', mods.kk),
  ];
  return <String>[
    for (final (label, betrag) in werte)
      if (betrag != 0) '$label ${_mitVorzeichen(betrag)}',
  ];
}

// Betrag mit echtem Minuszeichen bzw. Plus.
String _mitVorzeichen(int betrag) => betrag < 0 ? '−${-betrag}' : '+$betrag';
