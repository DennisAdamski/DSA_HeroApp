import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Ergebnis des Vergleichs zwischen AvatarSnapshot und aktuellem Helden.
class AvatarSnapshotDiff {
  const AvatarSnapshotDiff({
    this.attributeChanges = const {},
    this.alterChange,
    this.neueVorteile = const [],
    this.entfernteVorteile = const [],
    this.neueNachteile = const [],
    this.entfernteNachteile = const [],
    this.rasseChange,
    this.haarfarbeChange,
    this.augenfarbeChange,
  });

  /// Geaenderte Eigenschaftswerte: Schluessel → (alter Wert, neuer Wert).
  final Map<String, ({int alt, int neu})> attributeChanges;

  /// Alteraenderung als String (z.B. '25 → 30'), null wenn unveraendert.
  final String? alterChange;

  /// Seit dem Snapshot hinzugekommene Vorteile.
  final List<String> neueVorteile;

  /// Seit dem Snapshot entfernte Vorteile.
  final List<String> entfernteVorteile;

  /// Seit dem Snapshot hinzugekommene Nachteile.
  final List<String> neueNachteile;

  /// Seit dem Snapshot entfernte Nachteile.
  final List<String> entfernteNachteile;

  /// Rasseaenderung (z.B. 'Mensch → Halbelf'), null wenn unveraendert.
  final String? rasseChange;

  /// Haarfarbeaenderung, null wenn unveraendert.
  final String? haarfarbeChange;

  /// Augenfarbeaenderung, null wenn unveraendert.
  final String? augenfarbeChange;

  /// Ob sich mindestens ein Wert geaendert hat.
  bool get hatAenderungen =>
      attributeChanges.isNotEmpty ||
      alterChange != null ||
      neueVorteile.isNotEmpty ||
      entfernteVorteile.isNotEmpty ||
      neueNachteile.isNotEmpty ||
      entfernteNachteile.isNotEmpty ||
      rasseChange != null ||
      haarfarbeChange != null ||
      augenfarbeChange != null;
}

/// Berechnet den Diff zwischen dem gespeicherten Snapshot und dem
/// aktuellen Heldenzustand.
AvatarSnapshotDiff computeAvatarSnapshotDiff(
  AvatarSnapshot snapshot,
  HeroSheet current,
) {
  // --- Eigenschafts-Diff ---
  final attributeChanges = <String, ({int alt, int neu})>{};
  final currentAttrs = <String, int>{
    'MU': current.attributes.mu,
    'KL': current.attributes.kl,
    'IN': current.attributes.inn,
    'CH': current.attributes.ch,
    'FF': current.attributes.ff,
    'GE': current.attributes.ge,
    'KO': current.attributes.ko,
    'KK': current.attributes.kk,
  };
  final allKeys = {...snapshot.attributes.keys, ...currentAttrs.keys};
  for (final key in allKeys) {
    final alt = snapshot.attributes[key] ?? 0;
    final neu = currentAttrs[key] ?? 0;
    if (alt != neu) {
      attributeChanges[key] = (alt: alt, neu: neu);
    }
  }

  // --- Alter-Diff ---
  final alterCurrent = current.appearance.alter.trim();
  final alterSnapshot = snapshot.alter.trim();
  String? alterChange;
  if (alterSnapshot.isNotEmpty &&
      alterCurrent.isNotEmpty &&
      alterSnapshot != alterCurrent) {
    alterChange = '$alterSnapshot \u2192 $alterCurrent';
  }

  // --- Vor-/Nachteile-Diff ---
  final snapshotVorteile = _splitEntries(snapshot.vorteileText);
  final currentVorteile = _splitEntries(current.vorteileText);
  final snapshotNachteile = _splitEntries(snapshot.nachteileText);
  final currentNachteile = _splitEntries(current.nachteileText);

  final neueVorteile =
      currentVorteile.where((v) => !snapshotVorteile.contains(v)).toList();
  final entfernteVorteile =
      snapshotVorteile.where((v) => !currentVorteile.contains(v)).toList();
  final neueNachteile =
      currentNachteile.where((v) => !snapshotNachteile.contains(v)).toList();
  final entfernteNachteile =
      snapshotNachteile.where((v) => !currentNachteile.contains(v)).toList();

  // --- Optische Aenderungen ---
  String? rasseChange;
  if (snapshot.rasse.isNotEmpty &&
      current.background.rasse.isNotEmpty &&
      snapshot.rasse != current.background.rasse) {
    rasseChange = '${snapshot.rasse} \u2192 ${current.background.rasse}';
  }

  String? haarfarbeChange;
  if (snapshot.haarfarbe.isNotEmpty &&
      current.appearance.haarfarbe.isNotEmpty &&
      snapshot.haarfarbe != current.appearance.haarfarbe) {
    haarfarbeChange =
        '${snapshot.haarfarbe} \u2192 ${current.appearance.haarfarbe}';
  }

  String? augenfarbeChange;
  if (snapshot.augenfarbe.isNotEmpty &&
      current.appearance.augenfarbe.isNotEmpty &&
      snapshot.augenfarbe != current.appearance.augenfarbe) {
    augenfarbeChange =
        '${snapshot.augenfarbe} \u2192 ${current.appearance.augenfarbe}';
  }

  return AvatarSnapshotDiff(
    attributeChanges: attributeChanges,
    alterChange: alterChange,
    neueVorteile: neueVorteile,
    entfernteVorteile: entfernteVorteile,
    neueNachteile: neueNachteile,
    entfernteNachteile: entfernteNachteile,
    rasseChange: rasseChange,
    haarfarbeChange: haarfarbeChange,
    augenfarbeChange: augenfarbeChange,
  );
}

/// Splittet einen Vor-/Nachteile-Freitext in normalisierte Einzeleintraege.
Set<String> _splitEntries(String text) {
  return text
      .split(RegExp(r'[,;\n]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map((e) => e.toLowerCase())
      .toSet();
}
