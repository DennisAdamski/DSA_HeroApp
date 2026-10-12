import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/hero_background.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunft.dart';
import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/rules/derived/direkter_modifikator_rules.dart';
import 'package:uuid/uuid.dart';

/// Wie ein Nutzer eine Abweichung zwischen Herkunftstext und -liste auflöst.
enum HerkunftsAbgleichWahl {
  /// Der Text gilt: Die Liste der Gruppe wird daraus neu aufgebaut.
  textUebernehmen,

  /// Die Liste gilt: Der Text der Gruppe wird daraus neu projiziert.
  listeBehalten,
}

/// Eine erkannte Abweichung zwischen dem Herkunftstext und seiner Liste.
///
/// Ursache ist meist eine ältere App-Version, die nur den Text kennt und ihn
/// geändert hat. Sie wird nie still aufgelöst.
class HerkunftsTextAbweichung {
  /// Erstellt eine Abweichung.
  const HerkunftsTextAbweichung({required this.text, required this.listenText});

  /// Gespeicherter Text der Gruppe (`rasseModText` …).
  final String text;

  /// Text, den die strukturierte Liste ergäbe.
  final String listenText;
}

/// Ergebnis des Abgleichs von Herkunftstexten mit dem Container.
class HerkunftsAbgleich {
  /// Erstellt ein Abgleichergebnis.
  const HerkunftsAbgleich({
    required this.eintraege,
    required this.abweichungen,
  });

  /// Wirksamer Container (gespeichert oder zur Laufzeit migriert).
  final HeroHerkunftsModifikatoren eintraege;

  /// Abweichungen je Herkunftsgruppe; leer, wenn alles übereinstimmt.
  final Map<HeroHerkunft, HerkunftsTextAbweichung> abweichungen;
}

final String _migrationsNamespace = const Uuid().v5(
  Namespace.url.value,
  'urn:dsa-heldenverwaltung:herkunftsmigration:v1',
);

final RegExp _fragmentTrenner = RegExp(r'[\n,;]+');

/// Zerlegt [text] in getrimmte, nichtleere Fragmente.
List<String> zerlegeHerkunftsText(String text) {
  return <String>[
    for (final roh in text.split(_fragmentTrenner))
      if (roh.trim().isNotEmpty) roh.trim(),
  ];
}

/// Migriert den Herkunftstext [text] der Gruppe [herkunft] in Einträge.
///
/// Jedes nichtleere Fragment wird ein eigener Eintrag, auch bei Wiederholung;
/// nichts wird zusammengefasst. Direkte Modifikatoren (`MU+1`, `AE-2`) werden
/// strukturiert, alles andere bleibt ein freier Eintrag mit seinem Text. Die ID
/// ist eine UUID v5 aus Herkunft, Fragmentposition und Fragmenttext und damit
/// reproduzierbar; die Migration braucht keinen Katalog.
List<HeroHerkunftsModifikator> migriereHerkunftsText(
  HeroHerkunft herkunft,
  String text,
) {
  final eintraege = <HeroHerkunftsModifikator>[];
  final fragmente = text.split(_fragmentTrenner);
  for (var position = 0; position < fragmente.length; position++) {
    final fragment = fragmente[position].trim();
    if (fragment.isEmpty) {
      continue;
    }
    final id = const Uuid().v5(
      _migrationsNamespace,
      jsonEncode(<Object>[herkunft.name, position, fragment]),
    );
    final direkt = erkenneDirektenModifikator(fragment);
    eintraege.add(
      direkt == null
          ? HeroHerkunftsModifikator(id: id, text: fragment)
          : HeroHerkunftsModifikator(
              id: id,
              art: direkt.art,
              ziel: direkt.ziel,
              betrag: direkt.betrag,
              text: fragment,
            ),
    );
  }
  return List<HeroHerkunftsModifikator>.unmodifiable(eintraege);
}

/// Projiziert Einträge zurück in einen Text für ältere App-Versionen.
///
/// Die Fragmente stehen in Listenreihenfolge, durch `, ` getrennt.
String projiziereHerkunftsText(List<HeroHerkunftsModifikator> eintraege) {
  return <String>[
    for (final eintrag in eintraege)
      if (eintrag.text.trim().isNotEmpty) eintrag.text.trim(),
  ].join(', ');
}

/// Container, den die drei Texte von [background] ergeben (ohne Speichern).
HeroHerkunftsModifikatoren _migrierterContainer(HeroBackground background) {
  return HeroHerkunftsModifikatoren(
    rasse: migriereHerkunftsText(HeroHerkunft.rasse, background.rasseModText),
    kultur: migriereHerkunftsText(
      HeroHerkunft.kultur,
      background.kulturModText,
    ),
    profession: migriereHerkunftsText(
      HeroHerkunft.profession,
      background.professionModText,
    ),
  );
}

/// Der Herkunftstext, den [background] für [herkunft] trägt.
String herkunftsTextVon(HeroBackground background, HeroHerkunft herkunft) {
  return switch (herkunft) {
    HeroHerkunft.rasse => background.rasseModText,
    HeroHerkunft.kultur => background.kulturModText,
    HeroHerkunft.profession => background.professionModText,
  };
}

HeroBackground _mitHerkunftsText(
  HeroBackground background,
  HeroHerkunft herkunft,
  String text,
) {
  return switch (herkunft) {
    HeroHerkunft.rasse => background.copyWith(rasseModText: text),
    HeroHerkunft.kultur => background.copyWith(kulturModText: text),
    HeroHerkunft.profession => background.copyWith(professionModText: text),
  };
}

/// Wirksamer Container: der gespeicherte oder, solange keiner gespeichert ist,
/// die Laufzeitmigration der drei Texte.
HeroHerkunftsModifikatoren wirksameHerkunftsModifikatoren(
  HeroBackground background,
) {
  return background.herkunftsModifikatoren ?? _migrierterContainer(background);
}

/// Gleicht die Herkunftstexte von [background] mit dem Container ab.
///
/// Verglichen werden geordnete, getrimmte Fragmente; Trennerwechsel zählen
/// nicht. Gruppen mit nicht verstandenen Daten und Container einer unbekannten
/// Version werden nicht verglichen, weil ihre Liste nicht belastbar ist.
HerkunftsAbgleich gleicheHerkunftAb(HeroBackground background) {
  final container = wirksameHerkunftsModifikatoren(background);
  final abweichungen = <HeroHerkunft, HerkunftsTextAbweichung>{};
  if (container.istBearbeitbar) {
    for (final herkunft in HeroHerkunft.values) {
      if (container.unverstandeneGruppen.containsKey(herkunft.name)) {
        continue;
      }
      final liste = container.eintraegeFuer(herkunft);
      if (liste.any((e) => e.istUnverstanden)) {
        continue;
      }
      final text = herkunftsTextVon(background, herkunft);
      final erwartet = <String>[
        for (final eintrag in liste) ...zerlegeHerkunftsText(eintrag.text),
      ];
      if (!_listenGleich(zerlegeHerkunftsText(text), erwartet)) {
        abweichungen[herkunft] = HerkunftsTextAbweichung(
          text: text,
          listenText: projiziereHerkunftsText(liste),
        );
      }
    }
  }
  return HerkunftsAbgleich(
    eintraege: container,
    abweichungen: Map<HeroHerkunft, HerkunftsTextAbweichung>.unmodifiable(
      abweichungen,
    ),
  );
}

/// Bereitet die Herkunft für `saveHero` vor.
///
/// Fehlt der Container, wird er aus den drei Texten angelegt (auch leere
/// Bestandsfelder als leere Listen); die Texte bleiben dabei unverändert. Ein
/// vorhandener Container wird nie angefasst, insbesondere löst das Speichern
/// eine Textabweichung nicht auf und migriert keine unbekannte Version.
HeroBackground herkunftZumSpeichern(HeroBackground background) {
  if (background.herkunftsModifikatoren != null) {
    return background;
  }
  return background.copyWith(
    herkunftsModifikatoren: _migrierterContainer(background),
  );
}

/// Löst die Abweichung der Gruppe [herkunft] ausdrücklich auf.
///
/// Verändert nur diese Gruppe. Wirft [StateError], wenn die Gruppe wegen nicht
/// verstandener Daten gesperrt ist.
HeroBackground loeseHerkunftsAbweichung(
  HeroBackground background,
  HeroHerkunft herkunft,
  HerkunftsAbgleichWahl wahl,
) {
  final container = wirksameHerkunftsModifikatoren(background);
  if (!container.istGruppeBearbeitbar(herkunft)) {
    throw StateError('Die Herkunftsgruppe ${herkunft.name} ist gesperrt.');
  }
  switch (wahl) {
    case HerkunftsAbgleichWahl.listeBehalten:
      return _mitHerkunftsText(
        background.copyWith(herkunftsModifikatoren: container),
        herkunft,
        projiziereHerkunftsText(container.eintraegeFuer(herkunft)),
      );
    case HerkunftsAbgleichWahl.textUebernehmen:
      final neu = migriereHerkunftsText(
        herkunft,
        herkunftsTextVon(background, herkunft),
      );
      return background.copyWith(
        herkunftsModifikatoren: switch (herkunft) {
          HeroHerkunft.rasse => container.copyWith(rasse: neu),
          HeroHerkunft.kultur => container.copyWith(kultur: neu),
          HeroHerkunft.profession => container.copyWith(profession: neu),
        },
      );
  }
}

bool _listenGleich(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
