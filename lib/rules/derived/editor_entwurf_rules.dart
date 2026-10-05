// Speichern eines Editorentwurfs auf dem gespeicherten Helden (ARCH-05).
//
// Ein Editor füllt seinen Entwurf aus dem Helden bei Bearbeitungsbeginn, der
// Basis. Beim Speichern wird der Entwurf nicht mehr über den Helden gelegt,
// sondern mit dem frisch geladenen Stand abgeglichen: je oberstem
// JSON-Schlüssel des Helden gewinnt die Seite, die etwas geändert hat. Haben
// beide Seiten denselben Schlüssel verschieden geändert, entscheidet der
// Nutzer; nur Buchungen dürfen dabei nie zurückgenommen werden.

import 'dart:convert';

import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisebericht_rules.dart';

/// Ein Editorentwurf überschneidet sich mit einer inzwischen gespeicherten
/// Änderung.
class EditorEntwurfKonflikt implements Exception {
  /// Erstellt den Konflikt für die betroffenen [schluessel].
  const EditorEntwurfKonflikt({
    required this.schluessel,
    required this.erzwingbar,
  });

  /// Oberste JSON-Schlüssel des Helden, die Entwurf und Speicher seit
  /// Bearbeitungsbeginn beide und verschieden geändert haben.
  final Set<String> schluessel;

  /// Ob der Entwurf diese Schlüssel auf Wunsch des Nutzers überschreiben
  /// darf. Nein, sobald er dabei eine inzwischen gespeicherte Buchung
  /// zurücknähme (abgeschlossene Abenteuer, angewendete
  /// Reisebericht-Belohnungen): eine spätere Buchung bekäme sonst dieselben
  /// AP noch einmal.
  final bool erzwingbar;

  @override
  String toString() => 'Inzwischen anderswo geändert: ${schluessel.join(', ')}';
}

// Zähler: der Entwurf trägt seine Differenz bei, nie ein Konflikt.
const Set<String> _zaehler = <String>{'apTotal', 'apSpent'};

// Rechnet `saveHero` aus dem Ergebnis neu; es gilt der gespeicherte Stand.
const Set<String> _abgeleitet = <String>{
  'lastModified',
  'level',
  'apAvailable',
  'unknownModifierFragments',
};

// Platzhalter für einen Schlüssel, der in einem Stand fehlt. Viele Felder
// werden nur bei Belegung geschrieben; „fehlt“ ist dann ein eigener Wert.
const Object _fehlt = Object();

/// Übernimmt einen Editorentwurf auf den gespeicherten Helden.
///
/// [basis] ist der Held, aus dem der Editor seinen Entwurf gefüllt hat,
/// [entwurf] die Basis samt Editoränderungen, [aktuell] der frisch geladene
/// Held. Je oberstem JSON-Schlüssel gilt:
///
/// - unverändert im Entwurf: der gespeicherte Wert, auch wenn ihn inzwischen
///   ein anderer Weg geändert hat;
/// - nur im Entwurf geändert (oder auf beiden Seiten gleich): der Entwurf;
/// - auf beiden Seiten verschieden geändert: [EditorEntwurfKonflikt], außer
///   der Nutzer hat den Schlüssel in [erzwungen] bestätigt.
///
/// AP-Gesamt und ausgegebene AP sind Zähler: Der Entwurf trägt seine
/// Differenz zum gespeicherten Wert bei. Abgeleitete Werte (Stufe, freie AP)
/// rechnet das Speichern neu.
///
/// Hat sich seit [basis] nichts geändert, kommt [entwurf] unverändert
/// zurück; das ist das bisherige Speichern. Sonst entsteht der Held über
/// sein JSON, damit unbekannte Felder beider Seiten erhalten bleiben. Neue
/// Kampf-Slots bekommen vorher ihre ID aus [neueId]: `fromJson` vergäbe
/// sonst eine deterministische, und ein neuer Slot könnte die
/// Inventardaten eines gerade entfernten erben.
///
/// Ein Konflikt auf den Abenteuern ist nie erzwingbar, wenn dort
/// inzwischen ein Abenteuer abgeschlossen oder wieder geöffnet wurde; das
/// gilt auch für bereits bestätigte Schlüssel.
HeroSheet uebernimmEditorEntwurf({
  required HeroSheet basis,
  required HeroSheet entwurf,
  required HeroSheet aktuell,
  Set<String> erzwungen = const <String>{},
  required String Function() neueId,
}) {
  if (heroContentHash(aktuell) == heroContentHash(basis)) {
    return entwurf;
  }
  final basisJson = basis.toJson();
  final entwurfJson = entwurf
      .copyWith(
        combatConfig: entwurf.combatConfig.withStableIds(neueId: neueId),
      )
      .toJson();
  final aktuellJson = aktuell.toJson();

  final ergebnis = <String, dynamic>{};
  final konflikte = <String>{};
  final schluesselMenge = <String>{
    ...aktuellJson.keys,
    ...entwurfJson.keys,
    ...basisJson.keys,
  };
  for (final schluessel in schluesselMenge) {
    final b = basisJson.containsKey(schluessel)
        ? basisJson[schluessel]
        : _fehlt;
    final e = entwurfJson.containsKey(schluessel)
        ? entwurfJson[schluessel]
        : _fehlt;
    final a = aktuellJson.containsKey(schluessel)
        ? aktuellJson[schluessel]
        : _fehlt;
    final Object? wert;
    if (_abgeleitet.contains(schluessel)) {
      wert = a;
    } else if (_zaehler.contains(schluessel)) {
      wert = _zahl(a) + _zahl(e) - _zahl(b);
    } else {
      final basisHash = _hash(b);
      final entwurfHash = _hash(e);
      final aktuellHash = _hash(a);
      if (entwurfHash == basisHash || entwurfHash == aktuellHash) {
        wert = a;
      } else if (aktuellHash == basisHash) {
        wert = e;
      } else {
        konflikte.add(schluessel);
        wert = e;
      }
    }
    if (!identical(wert, _fehlt)) {
      ergebnis[schluessel] = wert;
    }
  }

  if (konflikte.contains('adventures') &&
      _abenteuerBuchungen(aktuell) != _abenteuerBuchungen(basis)) {
    throw EditorEntwurfKonflikt(schluessel: konflikte, erzwingbar: false);
  }
  final offen = konflikte.difference(erzwungen);
  if (offen.isNotEmpty) {
    throw EditorEntwurfKonflikt(schluessel: offen, erzwingbar: true);
  }
  // Über JSON-Text, damit `fromJson` dieselben Typen sieht wie beim Laden.
  final gelesen = jsonDecode(jsonEncode(ergebnis)) as Map<String, dynamic>;
  return HeroSheet.fromJson(gelesen);
}

/// Bucht einen Reisebericht-Entwurf auf den gespeicherten Helden.
///
/// [belohnungen] sind die aus [entwurf] errechneten, noch nicht angewendeten
/// Belohnungen. Sie werden auf [aktuell] gebucht (AP, SE, Boni als
/// Zuschlag), sodass inzwischen gespeicherte Talent- oder AP-Änderungen
/// erhalten bleiben.
///
/// Wurde der Reisebericht seit [basis] anderswo geändert, entsteht ein
/// [EditorEntwurfKonflikt]. Er ist nur erzwingbar ([erzwingen]), solange
/// die angewendeten Belohnungen gleich geblieben sind; sonst bekäme der
/// Held dieselben Belohnungen ein zweites Mal. Ist der Entwurf unverändert,
/// kommt [aktuell] selbst zurück.
HeroSheet bucheReiseberichtEntwurf({
  required HeroSheet basis,
  required HeroSheet aktuell,
  required HeroReisebericht entwurf,
  required ReiseberichtRewards belohnungen,
  bool erzwingen = false,
}) {
  final basisHash = stableContentHash(basis.reisebericht.toJson());
  final entwurfHash = stableContentHash(entwurf.toJson());
  final aktuellHash = stableContentHash(aktuell.reisebericht.toJson());
  if (entwurfHash == basisHash && belohnungen.isEmpty) {
    return aktuell;
  }
  if (aktuellHash != basisHash && aktuellHash != entwurfHash) {
    final gleicheBuchungen = _gleicheMengen(
      aktuell.reisebericht.appliedRewardIds,
      basis.reisebericht.appliedRewardIds,
    );
    if (!gleicheBuchungen || !erzwingen) {
      throw EditorEntwurfKonflikt(
        schluessel: const <String>{'reisebericht'},
        erzwingbar: gleicheBuchungen,
      );
    }
  }
  return applyReiseberichtRewards(
    hero: aktuell,
    rewards: belohnungen,
    updatedState: entwurf,
  );
}

int _zahl(Object? wert) => wert is num ? wert.toInt() : 0;

String _hash(Object? wert) =>
    identical(wert, _fehlt) ? '<fehlt>' : stableContentHash(wert);

// Abschlussstand je Abenteuer; ändert ihn jemand, ist gebucht worden.
String _abenteuerBuchungen(HeroSheet held) {
  return stableContentHash(<String, Object?>{
    for (final abenteuer in held.adventures)
      abenteuer.id: <Object?>[
        abenteuer.toJson()['status'],
        abenteuer.rewardsApplied,
      ],
  });
}

bool _gleicheMengen(Set<String> links, Set<String> rechts) {
  return links.length == rechts.length && links.containsAll(rechts);
}
