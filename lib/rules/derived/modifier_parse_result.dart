import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';

/// Parserergebnis fuer freie Modifikatortexte aus den Basisdaten.
///
/// Nicht erkannte Fragmente werden gesammelt, damit die UI sie sichtbar machen
/// kann (`HeroSheet.unknownModifierFragments`).
class ModifierParseResult {
  const ModifierParseResult({
    this.attributeMods = const AttributeModifiers(),
    this.startAttributeMods = const AttributeModifiers(),
    this.statMods = const StatModifiers(),
    this.hasFlinkFromVorteile = false,
    this.hasBehaebigFromNachteile = false,
    this.hasLinkshaenderFromVorteile = false,
    this.unknownFragments = const <String>[],
  });

  final AttributeModifiers attributeMods;

  /// Modifikatoren, die zusaetzlich den *Startwert* einer Eigenschaft anheben
  /// und damit ueber `ceil(start * 1.5)` auch das Maximum: Rasse, Kultur und
  /// Profession sowie startwerterhoehende Vorteile wie `Herausragende
  /// Eigenschaft`.
  ///
  /// Freie `KK+2`-Fragmente in Vor-/Nachteilen bleiben bewusst draussen: die
  /// beschreiben laufende Effekte, keine Generierungswerte.
  final AttributeModifiers startAttributeMods;

  final StatModifiers statMods;
  final bool hasFlinkFromVorteile;
  final bool hasBehaebigFromNachteile;

  /// Vorteil Linkshaender: der linke Arm ist der Schwertarm (Armwunden).
  final bool hasLinkshaenderFromVorteile;
  final List<String> unknownFragments;
}
