import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';

void main() {
  final zeit = DateTime.utc(2026, 10, 7, 12);

  test('Nullwerte entfallen im JSON', () {
    final buchung = ZustandsBuchung(
      id: 'b1',
      art: ZustandsBuchungsArt.schaden,
      zeitpunkt: zeit,
      lepDelta: -4,
    );

    expect(buchung.toJson(), <String, dynamic>{
      'id': 'b1',
      'art': 'schaden',
      'zeitpunkt': '2026-10-07T12:00:00.000Z',
      'lepDelta': -4,
    });
  });

  test('alle Felder überstehen JSON', () {
    final buchung = ZustandsBuchung(
      id: 'b2',
      art: ZustandsBuchungsArt.schadenRuecknahme,
      zeitpunkt: zeit,
      lepDelta: 9,
      auDelta: 3,
      zone: WundZone.kopf,
      wundenDelta: -2,
      kopfIniMalusDelta: -7,
      unterdrueckt: 1,
      ruecknahmeVon: 'b1',
    );

    final geladen = ZustandsBuchung.fromJson(buchung.toJson());

    expect(geladen.toJson(), buchung.toJson());
    expect(geladen.zone, WundZone.kopf);
    expect(geladen.ruecknahmeVon, 'b1');
    expect(geladen.hatUnbekannteZone, isFalse);
  });

  test('Art und Zone einer neueren Version bleiben als Rohwert', () {
    final geladen = ZustandsBuchung.fromJson(<String, dynamic>{
      'id': 'b3',
      'art': 'kuenftig',
      'zeitpunkt': zeit.toIso8601String(),
      'zone': 'schwanz',
      'wundenDelta': 1,
      'neu': true,
    });

    expect(geladen.art, ZustandsBuchungsArt.unbekannt);
    expect(geladen.zone, isNull);
    expect(geladen.hatUnbekannteZone, isTrue);
    final json = geladen.copyWith(unterdrueckt: 1).toJson();
    expect(json['art'], 'kuenftig');
    expect(json['zone'], 'schwanz');
    expect(json['neu'], isTrue);
  });
}
