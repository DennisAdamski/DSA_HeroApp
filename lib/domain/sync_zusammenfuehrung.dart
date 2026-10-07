/// Dreiwege-Zusammenführung zweier Stände eines Sync-Objekts (ARCH-06).
///
/// Verglichen werden die `toJson()`-Maps des zuletzt gemeinsam
/// abgeglichenen Stands (**Basis**), des lokalen und des Online-Stands. Was
/// nur eine Seite seit der Basis geändert hat, wird übernommen; was beide
/// Seiten gleich geändert haben, ebenfalls. Ein **echter Konflikt** ist nur
/// ein Wert, den beide Seiten verschieden geändert haben — nur er braucht
/// eine Entscheidung.
///
/// Maps werden je Schlüssel zusammengeführt, Listen aus Objekten mit
/// eindeutiger `id` bzw. `instanzId` je Element (Inventar, Kampfslots,
/// Steigerungsverlauf, Abenteuer, Buchungen …). Alle übrigen Listen und
/// Werte sind unteilbar. Fachliche Sonderregeln für Felder oberster Ebene
/// (Zähler wie AP oder LeP, Protokolle) beschreibt
/// [SyncZusammenfuehrungsRegeln].
library;

import 'dart:convert';

/// Seite, deren Wert ein echter Konflikt übernehmen soll.
enum SyncSeite {
  /// Der Online-Stand.
  online,

  /// Der Stand dieses Geräts.
  lokal,
}

/// Fachliche Sonderregeln für Felder oberster Ebene.
class SyncZusammenfuehrungsRegeln {
  /// Erzeugt einen Regelsatz.
  const SyncZusammenfuehrungsRegeln({
    this.zaehler = const <String>{},
    this.maximum = const <String>{},
    this.lokal = const <String>{},
    this.protokolle = const <String, String>{},
    this.grenzen = const <String, int>{},
  });

  /// Zahlen, bei denen beide Seiten ihre Änderung beitragen:
  /// `lokal + online − basis`. Nie ein Konflikt.
  final Set<String> zaehler;

  /// Werte, bei denen der größere gilt (Stufe, Zeitstempel, Schemaversion).
  final Set<String> maximum;

  /// Abgeleitete Werte, bei denen der lokale gilt; das nächste Speichern
  /// rechnet sie ohnehin neu.
  final Set<String> lokal;

  /// Listen ohne IDs, die als Vereinigung beider Seiten zusammengeführt
  /// werden, sortiert nach dem genannten Zeitfeld (Würfelprotokoll).
  final Map<String, String> protokolle;

  /// Höchstlänge einer Liste nach dem Zusammenführen; behalten werden die
  /// letzten Einträge.
  final Map<String, int> grenzen;
}

/// Regeln für das Heldenblatt.
///
/// AP sind Zähler. Die Stufe folgt den AP und wird beim nächsten Speichern
/// neu berechnet; bis dahin gilt die höhere.
const SyncZusammenfuehrungsRegeln heldZusammenfuehrungsRegeln =
    SyncZusammenfuehrungsRegeln(
      zaehler: <String>{'apTotal', 'apSpent', 'apAvailable'},
      maximum: <String>{'level', 'schemaVersion', 'lastModified'},
      lokal: <String>{'unknownModifierFragments'},
    );

/// Regeln für den Laufzeitzustand.
///
/// Ressourcen und Erschöpfung sind Zähler: Treffer und Heilung beider
/// Geräte zählen. Das Würfelprotokoll ist eine Vereinigung; Buchungen
/// werden über ihre ID zusammengeführt. Beide bleiben auf 50 begrenzt.
const SyncZusammenfuehrungsRegeln zustandZusammenfuehrungsRegeln =
    SyncZusammenfuehrungsRegeln(
      zaehler: <String>{
        'currentLep',
        'currentAsp',
        'currentKap',
        'currentAu',
        'erschoepfung',
        'ueberanstrengung',
      },
      maximum: <String>{'schemaVersion', 'lastModified'},
      protokolle: <String, String>{'diceLog': 'timestamp'},
      grenzen: <String, int>{'diceLog': 50, 'buchungen': 50},
    );

/// Ein Wert, den beide Seiten seit der Basis verschieden geändert haben.
class SyncKonfliktFeld {
  /// Erzeugt einen Konflikt.
  const SyncKonfliktFeld({
    required this.schluessel,
    required this.pfad,
    required this.online,
    required this.lokal,
    this.onlineFehlt = false,
    this.lokalFehlt = false,
  });

  /// Stabiler Schlüssel aus JSON-Feldern und Listen-IDs; über ihn wird
  /// entschieden.
  final String schluessel;

  /// Anzeigepfad aus JSON-Feldnamen und Elementnamen.
  final List<String> pfad;

  /// Online-Wert (roh, JSON).
  final Object? online;

  /// Lokaler Wert (roh, JSON).
  final Object? lokal;

  /// Online fehlt der Wert (gelöscht oder nie angelegt).
  final bool onlineFehlt;

  /// Lokal fehlt der Wert.
  final bool lokalFehlt;
}

/// Ergebnis von [fuehreSyncZusammen].
class SyncZusammenfuehrung {
  /// Erzeugt das Ergebnis.
  const SyncZusammenfuehrung({
    required this.ergebnis,
    required this.konflikte,
    required this.vonLokal,
    required this.vonOnline,
  });

  /// Zusammengeführtes JSON. Offene Konflikte tragen darin vorläufig den
  /// lokalen Wert; verbindlich ist es nur, wenn [vollstaendig] gilt.
  final Map<String, dynamic> ergebnis;

  /// Echte Konflikte ohne Entscheidung.
  final List<SyncKonfliktFeld> konflikte;

  /// Änderungen, die nur dieses Gerät gemacht hat und die übernommen werden.
  final int vonLokal;

  /// Änderungen, die nur online gemacht wurden und die übernommen werden.
  final int vonOnline;

  /// Ob alles ohne offene Entscheidung zusammengeführt ist.
  bool get vollstaendig => konflikte.isEmpty;
}

/// Führt [lokal] und [online] gegen ihre gemeinsame [basis] zusammen.
///
/// [entscheidungen] lösen echte Konflikte über ihren
/// [SyncKonfliktFeld.schluessel]; [praefix] stellt dem Schlüssel etwas
/// voran, damit Held und Zustand in einer Entscheidung getrennt bleiben.
SyncZusammenfuehrung fuehreSyncZusammen({
  required Map<String, dynamic> basis,
  required Map<String, dynamic> lokal,
  required Map<String, dynamic> online,
  SyncZusammenfuehrungsRegeln regeln = const SyncZusammenfuehrungsRegeln(),
  Map<String, SyncSeite> entscheidungen = const <String, SyncSeite>{},
  String praefix = '',
}) {
  final lauf = _Lauf(entscheidungen);
  final ergebnis = <String, dynamic>{};
  for (final schluessel in _schluesselMenge(basis, lokal, online)) {
    final b = _wert(basis, schluessel);
    final l = _wert(lokal, schluessel);
    final o = _wert(online, schluessel);
    final Object? wert;
    if (regeln.zaehler.contains(schluessel)) {
      wert = _zaehle(b, l, o, lauf);
    } else if (regeln.maximum.contains(schluessel)) {
      wert = _hoechster(l, o);
    } else if (regeln.lokal.contains(schluessel)) {
      wert = l;
    } else if (regeln.protokolle.containsKey(schluessel)) {
      wert = _vereinige(b, l, o, regeln.protokolle[schluessel]!, lauf);
    } else {
      wert = lauf.fuehreZusammen(
        b,
        l,
        o,
        schluessel: '$praefix$schluessel',
        pfad: <String>[schluessel],
      );
    }
    if (identical(wert, _fehlt)) {
      continue;
    }
    final grenze = regeln.grenzen[schluessel];
    ergebnis[schluessel] =
        grenze != null && wert is List && wert.length > grenze
        ? wert.sublist(wert.length - grenze)
        : wert;
  }
  // Über JSON-Text, damit `fromJson` dieselben Typen sieht wie beim Laden.
  return SyncZusammenfuehrung(
    ergebnis: jsonDecode(jsonEncode(ergebnis)) as Map<String, dynamic>,
    konflikte: List<SyncKonfliktFeld>.unmodifiable(lauf.konflikte),
    vonLokal: lauf.vonLokal,
    vonOnline: lauf.vonOnline,
  );
}

// Platzhalter für einen Schlüssel oder ein Element, das einem Stand fehlt.
// Viele Felder werden nur bei Belegung geschrieben; „fehlt“ ist ein Wert.
class _Fehlt {
  const _Fehlt();
}

const Object _fehlt = _Fehlt();

Object? _wert(Map<dynamic, dynamic> map, Object schluessel) =>
    map.containsKey(schluessel) ? map[schluessel] : _fehlt;

List<String> _schluesselMenge(
  Map<dynamic, dynamic> basis,
  Map<dynamic, dynamic> lokal,
  Map<dynamic, dynamic> online,
) {
  final schluessel = <String>[];
  final gesehen = <String>{};
  for (final map in <Map<dynamic, dynamic>>[lokal, online, basis]) {
    for (final key in map.keys) {
      if (gesehen.add('$key')) {
        schluessel.add('$key');
      }
    }
  }
  return schluessel;
}

// Inhalt als kanonischer Text: Maps sortiert, Listen in Reihenfolge.
String _kanonisch(Object? wert) {
  if (identical(wert, _fehlt)) {
    return '\u0000fehlt';
  }
  return jsonEncode(_sortiert(wert));
}

Object? _sortiert(Object? wert) {
  if (wert is Map) {
    final schluessel = wert.keys.map((k) => '$k').toList()..sort();
    return <String, Object?>{for (final k in schluessel) k: _sortiert(wert[k])};
  }
  if (wert is List) {
    return wert.map(_sortiert).toList();
  }
  return wert;
}

bool _gleich(Object? a, Object? b) => _kanonisch(a) == _kanonisch(b);

num _zahl(Object? wert) => wert is num ? wert : 0;

Object? _zaehle(Object? b, Object? l, Object? o, _Lauf lauf) {
  if (!_gleich(l, b)) {
    lauf.vonLokal++;
  }
  if (!_gleich(o, b)) {
    lauf.vonOnline++;
  }
  if (identical(l, _fehlt) && identical(o, _fehlt)) {
    return _fehlt;
  }
  // Ganze Zahlen bleiben ganz: int + int − int ist zur Laufzeit ein int.
  return _zahl(l) + _zahl(o) - _zahl(b);
}

Object? _hoechster(Object? l, Object? o) {
  if (identical(l, _fehlt)) {
    return o;
  }
  if (identical(o, _fehlt)) {
    return l;
  }
  if (l is num && o is num) {
    return l >= o ? l : o;
  }
  if (l is String && o is String) {
    return l.compareTo(o) >= 0 ? l : o;
  }
  return l;
}

// Vereinigt zwei Protokolle ohne IDs: Einträge, die eine Seite seit der
// Basis entfernt hat, fallen weg; alle übrigen erscheinen einmal, nach
// [zeitfeld] sortiert.
Object? _vereinige(
  Object? b,
  Object? l,
  Object? o,
  String zeitfeld,
  _Lauf lauf,
) {
  final basis = b is List ? b : const <Object?>[];
  final lokal = l is List ? l : const <Object?>[];
  final online = o is List ? o : const <Object?>[];
  if (_gleich(l, o)) {
    return l;
  }
  final basisText = {for (final e in basis) _kanonisch(e)};
  final lokalText = {for (final e in lokal) _kanonisch(e)};
  final onlineText = {for (final e in online) _kanonisch(e)};
  final ergebnis = <Object?>[];
  final gesehen = <String>{};
  for (final eintrag in <Object?>[...lokal, ...online]) {
    final text = _kanonisch(eintrag);
    if (!gesehen.add(text)) {
      continue;
    }
    final inBeiden = lokalText.contains(text) && onlineText.contains(text);
    if (!inBeiden && basisText.contains(text)) {
      // Eine Seite hat ihn entfernt (etwa verdrängt oder geleert).
      continue;
    }
    ergebnis.add(eintrag);
  }
  if (!_gleich(l, b)) {
    lauf.vonLokal++;
  }
  if (!_gleich(o, b)) {
    lauf.vonOnline++;
  }
  ergebnis.sort((x, y) {
    final a = x is Map ? '${x[zeitfeld] ?? ''}' : '';
    final c = y is Map ? '${y[zeitfeld] ?? ''}' : '';
    return a.compareTo(c);
  });
  return ergebnis;
}

class _Lauf {
  _Lauf(this.entscheidungen);

  final Map<String, SyncSeite> entscheidungen;
  final List<SyncKonfliktFeld> konflikte = <SyncKonfliktFeld>[];
  int vonLokal = 0;
  int vonOnline = 0;

  Object? fuehreZusammen(
    Object? b,
    Object? l,
    Object? o, {
    required String schluessel,
    required List<String> pfad,
  }) {
    if (_gleich(l, o)) {
      return l;
    }
    if (_gleich(l, b)) {
      vonOnline++;
      return o;
    }
    if (_gleich(o, b)) {
      vonLokal++;
      return l;
    }
    // Beide Seiten haben verschieden geändert: tiefer suchen, wo möglich.
    if (l is Map && o is Map && b is Map) {
      return _maps(b, l, o, schluessel: schluessel, pfad: pfad);
    }
    if (l is List && o is List && b is List) {
      final zusammen = _listen(b, l, o, schluessel: schluessel, pfad: pfad);
      if (!identical(zusammen, _fehlt)) {
        return zusammen;
      }
    }
    return _konflikt(b, l, o, schluessel: schluessel, pfad: pfad);
  }

  Object? _konflikt(
    Object? b,
    Object? l,
    Object? o, {
    required String schluessel,
    required List<String> pfad,
  }) {
    switch (entscheidungen[schluessel]) {
      case SyncSeite.online:
        return o;
      case SyncSeite.lokal:
        return l;
      case null:
        konflikte.add(
          SyncKonfliktFeld(
            schluessel: schluessel,
            pfad: List<String>.unmodifiable(pfad),
            online: identical(o, _fehlt) ? null : o,
            lokal: identical(l, _fehlt) ? null : l,
            onlineFehlt: identical(o, _fehlt),
            lokalFehlt: identical(l, _fehlt),
          ),
        );
        return l;
    }
  }

  Map<String, dynamic> _maps(
    Map<dynamic, dynamic> b,
    Map<dynamic, dynamic> l,
    Map<dynamic, dynamic> o, {
    required String schluessel,
    required List<String> pfad,
  }) {
    final ergebnis = <String, dynamic>{};
    for (final key in _schluesselMenge(b, l, o)) {
      final wert = fuehreZusammen(
        _wert(b, key),
        _wert(l, key),
        _wert(o, key),
        schluessel: '$schluessel/$key',
        pfad: <String>[...pfad, key],
      );
      if (!identical(wert, _fehlt)) {
        ergebnis[key] = wert;
      }
    }
    return ergebnis;
  }

  // Führt Listen aus Objekten mit eindeutigen IDs je Element zusammen;
  // `_fehlt`, wenn sich die Liste nicht über IDs zuordnen lässt.
  Object? _listen(
    List<dynamic> b,
    List<dynamic> l,
    List<dynamic> o, {
    required String schluessel,
    required List<String> pfad,
  }) {
    final idFeld = _idFeld(<List<dynamic>>[b, l, o]);
    if (idFeld == null) {
      return _fehlt;
    }
    final basis = _nachId(b, idFeld);
    final lokal = _nachId(l, idFeld);
    final online = _nachId(o, idFeld);
    final reihenfolge = <String>[
      ...lokal.keys,
      for (final id in online.keys)
        if (!lokal.containsKey(id)) id,
    ];
    final ergebnis = <Object?>[];
    for (final id in reihenfolge) {
      final lokalesElement = lokal[id] ?? _fehlt;
      final onlineElement = online[id] ?? _fehlt;
      final wert = fuehreZusammen(
        basis[id] ?? _fehlt,
        lokalesElement,
        onlineElement,
        schluessel: '$schluessel/$idFeld=$id',
        pfad: <String>[
          ...pfad,
          _elementName(lokalesElement, onlineElement, id),
        ],
      );
      if (!identical(wert, _fehlt)) {
        ergebnis.add(wert);
      }
    }
    return ergebnis;
  }
}

// Das ID-Feld, über das alle Elemente aller Stände eindeutig zuzuordnen
// sind; sonst `null`.
String? _idFeld(List<List<dynamic>> listen) {
  for (final feld in const <String>['id', 'instanzId']) {
    var passt = true;
    for (final liste in listen) {
      final ids = <String>{};
      for (final element in liste) {
        final id = element is Map ? element[feld] : null;
        if (id is! String || id.isEmpty || !ids.add(id)) {
          passt = false;
          break;
        }
      }
      if (!passt) {
        break;
      }
    }
    if (passt) {
      return feld;
    }
  }
  return null;
}

Map<String, Map<dynamic, dynamic>> _nachId(List<dynamic> liste, String feld) {
  return <String, Map<dynamic, dynamic>>{
    for (final element in liste) (element as Map)[feld] as String: element,
  };
}

String _elementName(Object? lokal, Object? online, String id) {
  for (final element in <Object?>[lokal, online]) {
    if (element is Map) {
      final name = element['name'] ?? element['label'] ?? element['title'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }
  }
  return id;
}
