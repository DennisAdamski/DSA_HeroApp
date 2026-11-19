// Reisewege der Entwickler-API v1 von Avesmaps (`GET /api/v1/route`).
//
// Liegen nur im lokalen Zwischenspeicher, nie im Heldendokument: Die Linie
// hat schnell Hunderte Punkte, und jedes neue Feld am Helden berührt Hash und
// Sync. Gerechnet wird bei Avesmaps; die App formatiert nur.

/// Wegart `land` der Schnittstelle (Straßen, Wege, Pfade, querfeldein).
const String kReiseWegLand = 'land';

/// Wegart `fluss` der Schnittstelle (Flusssegler).
const String kReiseWegFluss = 'fluss';

/// Wegart `see` der Schnittstelle (Lastensegler).
const String kReiseWegSee = 'see';

/// Alle Wegarten in fester Reihenfolge; ohne Auswahl gelten alle.
const List<String> kReiseWegArten = <String>[
  kReiseWegLand,
  kReiseWegFluss,
  kReiseWegSee,
];

/// Optimierung „schnellste“ (Vorgabe der Schnittstelle).
const String kReiseOptimierungSchnellste = 'schnellste';

/// Optimierung „kürzeste“.
const String kReiseOptimierungKuerzeste = 'kuerzeste';

/// Eine Anfrage an `/route`: von Ort zu Ort mit erlaubten Wegen und
/// Optimierung.
///
/// Wertgleich, damit sie als Schlüssel für Zwischenspeicher und Provider
/// taugt. [wege] ist sortiert und enthält nur bekannte Wegarten; leer
/// bedeutet alle.
class AvesmapsRoutenAnfrage {
  /// Erstellt die Anfrage; [wege] wird bereinigt.
  factory AvesmapsRoutenAnfrage({
    required String vonId,
    required String nachId,
    Iterable<String> wege = const <String>[],
    String optimierung = kReiseOptimierungSchnellste,
  }) {
    final bekannt = <String>[
      for (final art in kReiseWegArten)
        if (wege.contains(art)) art,
    ];
    return AvesmapsRoutenAnfrage._(
      vonId: vonId,
      nachId: nachId,
      wege: bekannt.length == kReiseWegArten.length
          ? const <String>[]
          : List<String>.unmodifiable(bekannt),
      optimierung: optimierung == kReiseOptimierungKuerzeste
          ? kReiseOptimierungKuerzeste
          : kReiseOptimierungSchnellste,
    );
  }

  const AvesmapsRoutenAnfrage._({
    required this.vonId,
    required this.nachId,
    required this.wege,
    required this.optimierung,
  });

  /// Kennung des Startorts bei Avesmaps.
  final String vonId;

  /// Kennung des Zielorts bei Avesmaps.
  final String nachId;

  /// Erlaubte Wegarten; leer heißt alle.
  final List<String> wege;

  /// `schnellste` oder `kuerzeste`.
  final String optimierung;

  /// Ob alle Wegarten erlaubt sind.
  bool get alleWege => wege.isEmpty;

  /// Eindeutiger Text für den Zwischenspeicher.
  String get schluessel =>
      '$vonId|$nachId|${alleWege ? 'alle' : wege.join(',')}|$optimierung';

  @override
  bool operator ==(Object other) =>
      other is AvesmapsRoutenAnfrage && other.schluessel == schluessel;

  @override
  int get hashCode => schluessel.hashCode;

  @override
  String toString() => 'AvesmapsRoutenAnfrage($schluessel)';
}

/// Eine Etappe der Antwort: ein Stück gleicher Wegart.
class AvesmapsRoutenEtappe {
  /// Erstellt die Etappe.
  const AvesmapsRoutenEtappe({
    required this.art,
    this.mittel = '',
    this.wege = const <String>[],
    this.meilen = 0,
    this.reisestunden = 0,
  });

  /// Wegart, etwa `Reichsstrasse`, `Flussweg`, `Seeweg`; neue Werte möglich.
  final String art;

  /// Reisemittel, etwa `groupFoot`, `riverSailer`.
  final String mittel;

  /// Namen der Wege (Straßen, Flüsse).
  final List<String> wege;

  /// Länge in Meilen.
  final double meilen;

  /// Reine Reisezeit in Stunden.
  final double reisestunden;

  /// Liest eine Etappe tolerant; ohne `art` `null`.
  static AvesmapsRoutenEtappe? ausJson(Object? roh) {
    if (roh is! Map) return null;
    final art = roh['art'];
    if (art is! String || art.trim().isEmpty) return null;
    return AvesmapsRoutenEtappe(
      art: art.trim(),
      mittel: roh['mittel'] is String ? roh['mittel'] as String : '',
      wege: <String>[
        if (roh['wege'] is List)
          for (final w in roh['wege'] as List)
            if (w is String && w.trim().isNotEmpty) w.trim(),
      ],
      meilen: _zahl(roh['meilen']),
      reisestunden: _zahl(roh['reisestunden']),
    );
  }

  /// Form für den Zwischenspeicher.
  Map<String, Object?> toJson() => <String, Object?>{
    'art': art,
    if (mittel.isNotEmpty) 'mittel': mittel,
    if (wege.isNotEmpty) 'wege': wege,
    'meilen': meilen,
    'reisestunden': reisestunden,
  };
}

/// Ein Reiseweg von Avesmaps.
class AvesmapsRoute {
  /// Erstellt den Weg.
  const AvesmapsRoute({
    required this.gefunden,
    this.grund = '',
    this.meilen = 0,
    this.reisestunden = 0,
    this.reisetage = 0,
    this.etappen = const <AvesmapsRoutenEtappe>[],
    this.linie = const <(double, double)>[],
    this.hinweise = const <String>[],
  });

  /// Antwort ohne Weg (`gefunden: false` oder unbekannter Ort).
  const AvesmapsRoute.nichtGefunden(String grund)
    : this(gefunden: false, grund: grund);

  /// Grund für einen unbekannten Ort (Antwort `404 place_not_found`).
  static const String grundOrtUnbekannt = 'ort_unbekannt';

  /// Ob es einen Weg gibt.
  final bool gefunden;

  /// Grund ohne Weg: `kein_zusammenhang`, `gesperrt`, [grundOrtUnbekannt].
  final String grund;

  /// Ganze Strecke in Meilen.
  final double meilen;

  /// Reine Reisezeit in Stunden.
  final double reisestunden;

  /// Reisetage laut Avesmaps (acht Reisestunden je Tag an Land).
  final double reisetage;

  /// Etappen gleicher Wegart in Reihenfolge.
  final List<AvesmapsRoutenEtappe> etappen;

  /// Verlauf als Kartenpunkte `(x, y)`.
  final List<(double, double)> linie;

  /// Hinweise wie `querfeldein`, `keine_freie_see`; neue Werte möglich.
  final List<String> hinweise;

  /// Liest die Antwort tolerant; ohne `gefunden` `null`.
  static AvesmapsRoute? ausJson(Object? roh) {
    if (roh is! Map) return null;
    final gefunden = roh['gefunden'];
    if (gefunden is! bool) return null;
    if (!gefunden) {
      final grund = roh['grund'];
      return AvesmapsRoute.nichtGefunden(grund is String ? grund : '');
    }
    return AvesmapsRoute(
      gefunden: true,
      meilen: _zahl(roh['meilen']),
      reisestunden: _zahl(roh['reisestunden']),
      reisetage: _zahl(roh['reisetage']),
      etappen: <AvesmapsRoutenEtappe>[
        if (roh['etappen'] is List)
          for (final e in roh['etappen'] as List)
            ?AvesmapsRoutenEtappe.ausJson(e),
      ],
      linie: <(double, double)>[
        if (roh['linie'] is List)
          for (final p in roh['linie'] as List)
            if (p is List && p.length >= 2 && p[0] is num && p[1] is num)
              ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ],
      hinweise: <String>[
        if (roh['hinweise'] is List)
          for (final h in roh['hinweise'] as List)
            if (h is String && h.isNotEmpty) h,
      ],
    );
  }

  /// Form für den Zwischenspeicher, lesbar mit [ausJson].
  Map<String, Object?> toJson() => <String, Object?>{
    'gefunden': gefunden,
    if (grund.isNotEmpty) 'grund': grund,
    if (gefunden) ...<String, Object?>{
      'meilen': meilen,
      'reisestunden': reisestunden,
      'reisetage': reisetage,
      'etappen': <Object?>[for (final e in etappen) e.toJson()],
      'linie': <Object?>[
        for (final (x, y) in linie) <double>[x, y],
      ],
      if (hinweise.isNotEmpty) 'hinweise': hinweise,
    },
  };
}

double _zahl(Object? roh) => roh is num && roh.isFinite ? roh.toDouble() : 0;
