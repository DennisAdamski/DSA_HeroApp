import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Eine einzelne, quellenbezogene Wirkung eines Zaubers auf den Helden
/// (MAG-EFF-02).
///
/// Anders als `ActiveSpellEffectsState.activeEffectIds` (eine ID je Zauber)
/// kann ein Held mehrere Instanzen desselben Zaubers tragen, etwa zwei
/// Attributo von verschiedenen Zaubernden. Jede Instanz hat eine eigene [id];
/// das Beenden einer Instanz entfernt nur ihren Beitrag.
///
/// Die Instanz hält nur **bestätigte Eingaben**. Sie rechnet nichts: welche
/// Werte daraus wirken, entscheidet das Regelmodul
/// (`spell_effect_instance_rules.dart`) je Profil. Fremde Herkunft darf
/// unbekannt bleiben ([zfw], [zfpStern] und [quelle] sind optional).
class SpellEffectInstance {
  /// Erstellt eine Instanz.
  const SpellEffectInstance({
    required this.id,
    required this.effectId,
    this.vorgangsId,
    this.quelle,
    this.zfw,
    this.zfpStern,
    this.amount = 0,
    this.attributeMods = const AttributeModifiers(),
    this.duration,
    this.unterdrueckt = false,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile, eindeutige ID der Instanz (UUID).
  final String id;

  /// Profil- bzw. Effekt-ID, etwa `effect_spell_attributo` oder eine
  /// Katalog-Zauber-ID aus `spell_effects.json`.
  final String effectId;

  /// ID des Vorgangs, der die Instanz angelegt hat. Eine zweite Aktivierung
  /// mit derselben Vorgangs-ID (Doppelklick, Retry, Neustart) legt keine
  /// weitere Instanz an.
  final String? vorgangsId;

  /// Freitext zum Ursprung (etwa Name des Zaubernden); `null` = unbekannt.
  final String? quelle;

  /// ZfW des ursprünglich Zaubernden, falls bekannt.
  final int? zfw;

  /// ZfP* der Probe, falls bekannt.
  final int? zfpStern;

  /// Profilspezifischer Zahlenwert (z. B. RS beim Armatrutz).
  final int amount;

  /// Eigenschaftsboni dieser Quelle (nur Attributo).
  final AttributeModifiers attributeMods;

  /// Wirkungsdauer oder `null`, wenn keine erfasst ist.
  final SpellDuration? duration;

  /// Unterdrückte Instanzen bleiben gespeichert, wirken aber nicht.
  final bool unterdrueckt;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest — auch die nur bedingt
  /// geschriebenen.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'effectId',
    'vorgangsId',
    'quelle',
    'zfw',
    'zfpStern',
    'amount',
    'attributeMods',
    'duration',
    'unterdrueckt',
  };

  /// Gibt eine Kopie mit geänderten Feldern zurück. [clearDuration] entfernt
  /// die Wirkungsdauer (`null` heißt sonst „unverändert“).
  SpellEffectInstance copyWith({
    String? effectId,
    String? vorgangsId,
    String? quelle,
    int? zfw,
    int? zfpStern,
    int? amount,
    AttributeModifiers? attributeMods,
    SpellDuration? duration,
    bool clearDuration = false,
    bool? unterdrueckt,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return SpellEffectInstance(
      id: id,
      effectId: effectId ?? this.effectId,
      vorgangsId: vorgangsId ?? this.vorgangsId,
      quelle: quelle ?? this.quelle,
      zfw: zfw ?? this.zfw,
      zfpStern: zfpStern ?? this.zfpStern,
      amount: amount ?? this.amount,
      attributeMods: attributeMods ?? this.attributeMods,
      duration: clearDuration ? null : (duration ?? this.duration),
      unterdrueckt: unterdrueckt ?? this.unterdrueckt,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Instanz; optionale Felder nur bei Belegung.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'id': id,
      'effectId': effectId,
      if (vorgangsId != null) 'vorgangsId': vorgangsId,
      if (quelle != null) 'quelle': quelle,
      if (zfw != null) 'zfw': zfw,
      if (zfpStern != null) 'zfpStern': zfpStern,
      'amount': amount,
      'attributeMods': attributeMods.toJson(),
      if (duration != null) 'duration': duration!.toJson(),
      if (unterdrueckt) 'unterdrueckt': true,
    }, unbekannteFelder);
  }

  /// Lädt eine Instanz; `null`, wenn `id` oder `effectId` fehlen.
  static SpellEffectInstance? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final effectId = (json['effectId'] as String?)?.trim() ?? '';
    if (id.isEmpty || effectId.isEmpty) {
      return null;
    }
    final rawDuration = (json['duration'] as Map?)?.cast<String, dynamic>();
    final rawMods = (json['attributeMods'] as Map?)?.cast<String, dynamic>();
    return SpellEffectInstance(
      id: id,
      effectId: effectId,
      vorgangsId: json['vorgangsId'] as String?,
      quelle: json['quelle'] as String?,
      zfw: (json['zfw'] as num?)?.toInt(),
      zfpStern: (json['zfpStern'] as num?)?.toInt(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      attributeMods: rawMods == null
          ? const AttributeModifiers()
          : AttributeModifiers.fromJson(rawMods),
      duration: rawDuration == null
          ? null
          : SpellDuration.fromJson(rawDuration),
      unterdrueckt: json['unterdrueckt'] == true,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SpellEffectInstance &&
        other.id == id &&
        other.effectId == effectId &&
        other.vorgangsId == vorgangsId &&
        other.quelle == quelle &&
        other.zfw == zfw &&
        other.zfpStern == zfpStern &&
        other.amount == amount &&
        other.duration == duration &&
        other.unterdrueckt == unterdrueckt &&
        _mods(other.attributeMods) == _mods(attributeMods) &&
        unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder);
  }

  @override
  int get hashCode => Object.hash(
    id,
    effectId,
    vorgangsId,
    quelle,
    zfw,
    zfpStern,
    amount,
    duration,
    unterdrueckt,
    _mods(attributeMods),
    unbekannteFelderHash(unbekannteFelder),
  );
}

// AttributeModifiers hat keinen eigenen Vergleich; die acht Werte genügen
// (die unbekannten Felder liegen im JSON und zählen über toJson mit).
String _mods(AttributeModifiers m) => '${m.toJson()}';
