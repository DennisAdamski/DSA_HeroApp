import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';
import 'package:dsa_heldenverwaltung/rules/derived/avatar_rahmung_rules.dart';

void main() {
  // Seitenverhaeltnis des Ausschnitts in Pixeln.
  double pixelVerhaeltnis(AvatarAusschnitt a, int breite, int hoehe) =>
      (a.breite * breite) / (a.hoehe * hoehe);

  void liegtImBild(AvatarAusschnitt a) {
    expect(a.links, greaterThanOrEqualTo(0));
    expect(a.oben, greaterThanOrEqualTo(0));
    expect(a.links + a.breite, lessThanOrEqualTo(1 + 1e-9));
    expect(a.oben + a.hoehe, lessThanOrEqualTo(1 + 1e-9));
  }

  group('ohne Gesicht', () {
    test('Hochformat zeigt die obere Bildhaelfte statt der Mitte', () {
      final a = berechneAvatarAusschnitt(
        bildBreite: 1024,
        bildHoehe: 1536,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
      );

      expect(a.breite, 1);
      expect(a.hoehe, closeTo(1024 / 1536, 1e-9));
      // Mitte bei 38 % der Hoehe: 583,7 px - 512 px = 71,7 px.
      expect(a.oben * 1536, closeTo(0.38 * 1536 - 512, 1e-6));
      liegtImBild(a);
    });

    test('Querformat bleibt mittig', () {
      final a = berechneAvatarAusschnitt(
        bildBreite: 1536,
        bildHoehe: 1024,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
      );

      expect(a.hoehe, 1);
      expect(a.links, closeTo((1536 - 1024) / 2 / 1536, 1e-9));
      expect(a.oben, 0);
    });

    test('unbrauchbare Masse ergeben das ganze Bild', () {
      expect(
        berechneAvatarAusschnitt(
          bildBreite: 0,
          bildHoehe: 10,
          seitenverhaeltnis: 1,
          rahmung: AvatarRahmung.portraet,
        ),
        AvatarAusschnitt.ganz,
      );
      expect(
        berechneAvatarAusschnitt(
          bildBreite: 10,
          bildHoehe: 10,
          seitenverhaeltnis: double.nan,
          rahmung: AvatarRahmung.portraet,
        ),
        AvatarAusschnitt.ganz,
      );
    });
  });

  group('mit Gesicht', () {
    test('fasst das Gesicht nach der Rahmung und haelt das Format', () {
      const gesicht = AvatarGesichtsrahmen(
        links: 0.4,
        oben: 0.2,
        breite: 0.2,
        hoehe: 0.1,
      );
      final a = berechneAvatarAusschnitt(
        bildBreite: 1000,
        bildHoehe: 1500,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
        gesicht: gesicht,
      );

      // Gesichtshoehe 150 px / 0,36 = 416,7 px Ausschnitt.
      expect(a.hoehe * 1500, closeTo(150 / 0.36, 1e-6));
      expect(pixelVerhaeltnis(a, 1000, 1500), closeTo(1, 1e-9));
      // Gesichtsmitte horizontal zentriert, vertikal bei 52 %.
      expect((a.links + a.breite / 2) * 1000, closeTo(500, 1e-6));
      final mitteImAusschnitt =
          (0.25 * 1500 - a.oben * 1500) / (a.hoehe * 1500);
      expect(mitteImAusschnitt, closeTo(0.52, 1e-9));
      liegtImBild(a);
    });

    test('Gesicht am Rand schiebt den Ausschnitt ins Bild', () {
      final a = berechneAvatarAusschnitt(
        bildBreite: 800,
        bildHoehe: 800,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
        gesicht: const AvatarGesichtsrahmen(
          links: 0,
          oben: 0,
          breite: 0.15,
          hoehe: 0.15,
        ),
      );

      expect(a.links, 0);
      expect(a.oben, 0);
      liegtImBild(a);
    });

    test('winzige Gesichter zoomen hoechstens vierfach', () {
      final a = berechneAvatarAusschnitt(
        bildBreite: 1000,
        bildHoehe: 1000,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
        gesicht: const AvatarGesichtsrahmen(
          links: 0.5,
          oben: 0.3,
          breite: 0.01,
          hoehe: 0.01,
        ),
      );

      expect(a.hoehe, closeTo(1 / kAvatarMaxZoom, 1e-9));
      expect(a.breite, closeTo(1 / kAvatarMaxZoom, 1e-9));
    });

    test('ein bildfuellendes Gesicht ergibt den groessten Ausschnitt', () {
      final a = berechneAvatarAusschnitt(
        bildBreite: 600,
        bildHoehe: 900,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
        gesicht: const AvatarGesichtsrahmen(
          links: 0.1,
          oben: 0.1,
          breite: 0.8,
          hoehe: 0.6,
        ),
      );

      expect(a.breite, closeTo(1, 1e-9));
      expect(a.hoehe, closeTo(600 / 900, 1e-9));
      liegtImBild(a);
    });

    test('breite Gesichter werden nicht seitlich angeschnitten', () {
      const gesicht = AvatarGesichtsrahmen(
        links: 0.3,
        oben: 0.3,
        breite: 0.4,
        hoehe: 0.1,
      );
      final a = berechneAvatarAusschnitt(
        bildBreite: 1000,
        bildHoehe: 1000,
        seitenverhaeltnis: 1,
        rahmung: AvatarRahmung.portraet,
        gesicht: gesicht,
      );

      expect(a.breite, greaterThanOrEqualTo(gesicht.breite / 0.8 - 1e-9));
    });

    test('die Kopfzeile fasst enger als das Portraet', () {
      const gesicht = AvatarGesichtsrahmen(
        links: 0.4,
        oben: 0.3,
        breite: 0.2,
        hoehe: 0.15,
      );
      AvatarAusschnitt fuer(AvatarRahmung rahmung) => berechneAvatarAusschnitt(
        bildBreite: 1000,
        bildHoehe: 1000,
        seitenverhaeltnis: 104 / 72,
        rahmung: rahmung,
        gesicht: gesicht,
      );

      final kopfzeile = fuer(AvatarRahmung.kopfzeile);
      expect(kopfzeile.hoehe, lessThan(fuer(AvatarRahmung.portraet).hoehe));
      expect(pixelVerhaeltnis(kopfzeile, 1000, 1000), closeTo(104 / 72, 1e-9));
      liegtImBild(kopfzeile);
    });
  });
}
