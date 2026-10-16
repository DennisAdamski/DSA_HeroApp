/// Gottheiten von Geweihten und ihre Bindung an karmale Sonderfertigkeiten.
///
/// Der Held traegt seine Gottheit in `HeroSheet.gottheit`. Karmale
/// Sonderfertigkeiten, die nur Geweihten einer bestimmten Gottheit offenstehen
/// (Pfade der Erleuchteten, Epische Stufen S. 57 ff.), nennen sie in der
/// strukturierten Voraussetzung `{"art": "gottheit", "namen": [...]}`. Der
/// Sammelname `Zwölfgötter` steht fuer jede Gottheit des Zwoelfgoetterkults
/// (Ausgleichssegen: „Zwölfgötterkult“).
library;

import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

/// Die Zwoelfgoetter in kanonischer Reihenfolge des Jahreslaufs.
const List<String> kZwoelfgoetter = <String>[
  'Praios',
  'Rondra',
  'Efferd',
  'Travia',
  'Boron',
  'Hesinde',
  'Firun',
  'Tsa',
  'Phex',
  'Peraine',
  'Ingerimm',
  'Rahja',
];

/// Sammelname fuer alle Zwoelfgoetter in Katalogvoraussetzungen.
const String kZwoelfgoetterSammelname = 'Zwölfgötter';

/// Vorschlaege fuer die Auswahl der Gottheit; freie Eingabe bleibt moeglich.
const List<String> kGottheitVorschlaege = <String>[
  ...kZwoelfgoetter,
  'Ifirn',
  'Swafnir',
  'Kor',
  'Nandus',
  'Aves',
  'Angrosch',
  'Rastullah',
  'Tairach',
  'Rur und Gror',
  'Zsahh',
];

String _norm(String name) {
  final text = normalizeSpecialAbilityName(name);
  // „Zwölfgötterkult“ und „Zwölfgötter“ meinen dasselbe.
  return text.endsWith('kult') ? text.substring(0, text.length - 4) : text;
}

/// Ob die Gottheit [heldGottheit] eine der [geforderte] erfuellt.
///
/// Eine leere Heldengottheit erfuellt nie; der Aufrufer entscheidet, ob er
/// das als Hinweis oder als Sperre behandelt.
bool gottheitPasst(String heldGottheit, Iterable<String> geforderte) {
  final held = _norm(heldGottheit);
  if (held.isEmpty) return false;
  final sammel = _norm(kZwoelfgoetterSammelname);
  final heldIstZwoelfgott =
      held == sammel || kZwoelfgoetter.any((gott) => _norm(gott) == held);
  for (final name in geforderte) {
    final gesucht = _norm(name);
    if (gesucht.isEmpty) continue;
    if (gesucht == held) return true;
    if (gesucht == sammel && heldIstZwoelfgott) return true;
  }
  return false;
}
