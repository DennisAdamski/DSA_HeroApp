import 'package:flutter/foundation.dart';

/// Ein gespeicherter Heldeneintrag, den diese App-Version nicht lesen kann.
///
/// Der Roheintrag bleibt unverändert im Speicher; die Oberfläche blendet ihn
/// aus und weist nur auf ihn hin.
@immutable
class UnlesbarerHeld {
  /// Beschreibt einen übersprungenen Eintrag.
  const UnlesbarerHeld({required this.schluessel, this.name});

  /// Schlüssel des Eintrags im Heldenspeicher.
  final String schluessel;

  /// Name aus dem Roheintrag, sofern er dort als Text vorliegt.
  final String? name;

  /// Name für die Anzeige; ohne lesbaren Namen der Speicherschlüssel.
  String get anzeigename {
    final kandidat = name?.trim() ?? '';
    return kandidat.isEmpty ? schluessel : kandidat;
  }

  @override
  bool operator ==(Object other) =>
      other is UnlesbarerHeld &&
      other.schluessel == schluessel &&
      other.name == name;

  @override
  int get hashCode => Object.hash(schluessel, name);
}

/// Repository, das übersprungene, unlesbare Heldeneinträge benennen kann.
///
/// Bewusst nicht Teil von `HeroRepository`: Speicher ohne Rohdaten (etwa
/// Testdoubles) liefern schlicht keinen Hinweis.
abstract interface class UnlesbareHeldenQuelle {
  /// Unlesbare Einträge, sortiert nach Schlüssel.
  List<UnlesbarerHeld> get unlesbareHeldenEintraege;
}
