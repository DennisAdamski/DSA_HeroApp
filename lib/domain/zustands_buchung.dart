import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';

/// Art einer [ZustandsBuchung].
enum ZustandsBuchungsArt {
  /// Ein übernommener Treffer („Schaden erhalten“).
  schaden,

  /// Die Gegenbuchung, die einen Treffer zurücknimmt.
  schadenRuecknahme,

  /// Ersatz für eine Art einer neueren App-Version; nie zurücknehmbar.
  unbekannt,
}

/// Eine fachliche Buchung auf dem Laufzeitzustand (ARCH-06).
///
/// Hält fest, was eine Buchung **tatsächlich** verändert hat — nach allen
/// Untergrenzen und vollen Zonen —, damit sie sich später als Gegenbuchung
/// zurücknehmen lässt und eine Wiederholung derselben Buchung (gleiche [id])
/// erkannt wird. Buchungen sind unveränderlich bis auf [unterdrueckt], das
/// die anschließende Wundunterdrückung desselben Treffers nachträgt.
class ZustandsBuchung {
  /// Erzeugt eine Buchung.
  const ZustandsBuchung({
    required this.id,
    required this.art,
    required this.zeitpunkt,
    this.lepDelta = 0,
    this.auDelta = 0,
    this.zone,
    this.wundenDelta = 0,
    this.kopfIniMalusDelta = 0,
    this.unterdrueckt = 0,
    this.ruecknahmeVon,
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Vorgangs-ID; dieselbe ID bucht nie zweimal.
  final String id;

  /// Art der Buchung.
  final ZustandsBuchungsArt art;

  /// Zeitpunkt der Buchung (UTC).
  final DateTime zeitpunkt;

  /// Tatsächliche Änderung der LeP.
  final int lepDelta;

  /// Tatsächliche Änderung der AuP.
  final int auDelta;

  /// Zone der eingetragenen bzw. entfernten Wunden; `null` ohne Wunden oder
  /// bei einer Zone einer neueren App-Version.
  final WundZone? zone;

  /// Eingetragene (positiv) bzw. entfernte (negativ) Wunden in [zone].
  final int wundenDelta;

  /// Änderung des gewürfelten Kopf-INI-Malus.
  final int kopfIniMalusDelta;

  /// Wie viele Wunden dieses Treffers anschließend unterdrückt wurden.
  final int unterdrueckt;

  /// ID der Buchung, die diese Gegenbuchung zurücknimmt.
  final String? ruecknahmeVon;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzählungswerte einer neueren App-Version (Rohwerte).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schlüssel, die [fromJson] liest, auch die nur bedingt
  /// geschriebenen.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'art',
    'zeitpunkt',
    'lepDelta',
    'auDelta',
    'zone',
    'wundenDelta',
    'kopfIniMalusDelta',
    'unterdrueckt',
    'ruecknahmeVon',
  };

  /// Kopie mit nachgetragener Unterdrückung.
  ZustandsBuchung copyWith({int? unterdrueckt}) {
    return ZustandsBuchung(
      id: id,
      art: art,
      zeitpunkt: zeitpunkt,
      lepDelta: lepDelta,
      auDelta: auDelta,
      zone: zone,
      wundenDelta: wundenDelta,
      kopfIniMalusDelta: kopfIniMalusDelta,
      unterdrueckt: unterdrueckt ?? this.unterdrueckt,
      ruecknahmeVon: ruecknahmeVon,
      unbekannteFelder: unbekannteFelder,
      unbekannteEnumWerte: unbekannteEnumWerte,
    );
  }

  /// Serialisiert die Buchung; Nullwerte entfallen.
  Map<String, dynamic> toJson() {
    final zone = this.zone;
    final ruecknahmeVon = this.ruecknahmeVon;
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'id': id,
        'art': art.name,
        'zeitpunkt': zeitpunkt.toUtc().toIso8601String(),
        if (lepDelta != 0) 'lepDelta': lepDelta,
        if (auDelta != 0) 'auDelta': auDelta,
        if (zone != null) 'zone': zone.name,
        if (wundenDelta != 0) 'wundenDelta': wundenDelta,
        if (kopfIniMalusDelta != 0) 'kopfIniMalusDelta': kopfIniMalusDelta,
        if (unterdrueckt != 0) 'unterdrueckt': unterdrueckt,
        'ruecknahmeVon': ?ruecknahmeVon,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest eine Buchung; unbekannte Art und Zone bleiben als Rohwert erhalten.
  static ZustandsBuchung fromJson(Map<String, dynamic> json) {
    int zahl(String schluessel) => (json[schluessel] as num?)?.toInt() ?? 0;
    final enumRoh = <String, Object?>{};
    return ZustandsBuchung(
      id: json['id'] as String? ?? '',
      art: leseEnumWert(
        json['art'],
        'art',
        erkenne: (roh) => enumNachName(ZustandsBuchungsArt.values, roh),
        ersatz: ZustandsBuchungsArt.unbekannt,
        unbekannt: enumRoh,
      ),
      zeitpunkt:
          DateTime.tryParse(json['zeitpunkt'] as String? ?? '')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lepDelta: zahl('lepDelta'),
      auDelta: zahl('auDelta'),
      zone: leseEnumWert<WundZone?>(
        json['zone'],
        'zone',
        erkenne: (roh) => enumNachName(WundZone.values, roh),
        ersatz: null,
        unbekannt: enumRoh,
      ),
      wundenDelta: zahl('wundenDelta'),
      kopfIniMalusDelta: zahl('kopfIniMalusDelta'),
      unterdrueckt: zahl('unterdrueckt'),
      ruecknahmeVon: json['ruecknahmeVon'] as String?,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }

  /// `true`, wenn die Zone aus einer neueren App-Version stammt.
  bool get hatUnbekannteZone => unbekannteEnumWerte.containsKey('zone');
}
