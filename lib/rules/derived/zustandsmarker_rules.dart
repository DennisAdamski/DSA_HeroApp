import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_marker.dart';

/// Höchstzahl freier Zustandsmarker je Held (SPIEL-03).
const int kZustandsmarkerMax = 30;

/// Höchstdauer eines Markers in Runden.
const int kZustandsmarkerDauerMax = 999;

/// Längster Markername in Zeichen.
const int kZustandsmarkerNameMax = 40;

/// Längste Notiz eines Markers in Zeichen.
const int kZustandsmarkerNotizMax = 200;

/// Vorschläge für den Namen im Dialog; reine Eingabehilfe ohne Regelbezug.
const List<String> kZustandsmarkerVorschlaege = <String>[
  'Betäubung',
  'Furcht',
  'Schmerz',
  'Verwirrung',
  'Lähmung',
  'Blind',
];

/// Text der Dauer eines Markers: „3 Runden“, „1 Runde“, „abgelaufen“ oder
/// `null` ohne Dauer.
String? zustandsmarkerDauerText(ZustandsMarker marker) {
  final rest = marker.rest;
  if (rest == null) return null;
  if (rest <= 0) return 'abgelaufen';
  return rest == 1 ? '1 Runde' : '$rest Runden';
}

/// Hängt einen neuen Marker an das Ende der Liste.
///
/// Der Name wird gekürzt (Leerraum außen weg, höchstens
/// [kZustandsmarkerNameMax] Zeichen); ein leerer Name ändert nichts. Die
/// Dauer liegt zwischen 0 und [kZustandsmarkerDauerMax] oder fehlt. Eine ID,
/// die es schon gibt, wird abgewiesen. Ist die Liste voll, endet der Aufruf
/// mit einem [StateError], statt still etwas zu verwerfen.
HeroState mitMarkerHinzu(
  HeroState zustand, {
  required String id,
  required String name,
  int? dauer,
  String notiz = '',
}) {
  final bereinigt = _name(name);
  if (bereinigt.isEmpty || id.isEmpty) return zustand;
  if (zustand.zustandsmarker.any((m) => m.id == id)) return zustand;
  if (zustand.zustandsmarker.length >= kZustandsmarkerMax) {
    throw StateError(
      'Es sind höchstens $kZustandsmarkerMax Zustandsmarker möglich.',
    );
  }
  final marker = ZustandsMarker(
    id: id,
    name: bereinigt,
    rest: _dauer(dauer),
    notiz: _notiz(notiz),
  );
  return zustand.copyWith(
    zustandsmarker: List<ZustandsMarker>.unmodifiable(<ZustandsMarker>[
      ...zustand.zustandsmarker,
      marker,
    ]),
  );
}

/// Ändert Name, Dauer und Notiz des Markers [id].
///
/// Ein Marker, den es nicht mehr gibt (auf einem anderen Gerät entfernt), und
/// ein leerer Name ändern nichts; ohne tatsächliche Änderung bleibt dieselbe
/// Instanz zurück, damit nichts gespeichert wird.
HeroState mitMarkerGeaendert(
  HeroState zustand, {
  required String id,
  required String name,
  int? dauer,
  String notiz = '',
}) {
  final bereinigt = _name(name);
  if (bereinigt.isEmpty) return zustand;
  var geaendert = false;
  final neu = <ZustandsMarker>[
    for (final marker in zustand.zustandsmarker)
      if (marker.id == id)
        () {
          final ersatz = marker.copyWith(
            name: bereinigt,
            rest: _dauer(dauer),
            notiz: _notiz(notiz),
          );
          if (ersatz != marker) geaendert = true;
          return ersatz;
        }()
      else
        marker,
  ];
  if (!geaendert) return zustand;
  return zustand.copyWith(
    zustandsmarker: List<ZustandsMarker>.unmodifiable(neu),
  );
}

/// Entfernt den Marker [id]; gibt es ihn nicht, bleibt der Zustand gleich.
HeroState ohneMarker(HeroState zustand, String id) {
  if (!zustand.zustandsmarker.any((m) => m.id == id)) return zustand;
  return zustand.copyWith(
    zustandsmarker: List<ZustandsMarker>.unmodifiable(
      zustand.zustandsmarker.where((m) => m.id != id),
    ),
  );
}

/// Zählt die Dauer des Markers [id] um [delta] Runden, vom gespeicherten Wert
/// aus.
///
/// Nur Marker mit Dauer zählen; die Dauer bleibt zwischen 0 und
/// [kZustandsmarkerDauerMax]. Ein Marker ohne Dauer, ein fehlender Marker und
/// ein Schritt an der Grenze ändern nichts.
HeroState mitMarkerSchritt(HeroState zustand, String id, int delta) {
  var geaendert = false;
  final neu = <ZustandsMarker>[
    for (final marker in zustand.zustandsmarker)
      if (marker.id == id && marker.rest != null)
        () {
          final rest = _begrenze(marker.rest! + delta);
          if (rest == marker.rest) return marker;
          geaendert = true;
          return marker.copyWith(rest: rest);
        }()
      else
        marker,
  ];
  if (!geaendert) return zustand;
  return zustand.copyWith(
    zustandsmarker: List<ZustandsMarker>.unmodifiable(neu),
  );
}

/// Zählt die Dauer **aller** Marker mit laufender Dauer um eine Runde herunter.
///
/// Abgelaufene Marker (0) und Marker ohne Dauer bleiben unverändert; nichts
/// wird entfernt oder gebucht. Ohne zählbaren Marker bleibt dieselbe Instanz
/// zurück.
HeroState mitNaechsterMarkerRunde(HeroState zustand) {
  if (!zustand.zustandsmarker.any((m) => (m.rest ?? 0) > 0)) return zustand;
  return zustand.copyWith(
    zustandsmarker: List<ZustandsMarker>.unmodifiable(
      zustand.zustandsmarker.map(
        (m) => (m.rest ?? 0) > 0 ? m.copyWith(rest: m.rest! - 1) : m,
      ),
    ),
  );
}

/// Anzahl der Marker, deren Dauer noch läuft.
int zaehleLaufendeMarker(HeroState zustand) =>
    zustand.zustandsmarker.where((m) => (m.rest ?? 0) > 0).length;

String _name(String name) {
  final kurz = name.trim();
  return kurz.length > kZustandsmarkerNameMax
      ? kurz.substring(0, kZustandsmarkerNameMax).trimRight()
      : kurz;
}

String _notiz(String notiz) {
  final kurz = notiz.trim();
  return kurz.length > kZustandsmarkerNotizMax
      ? kurz.substring(0, kZustandsmarkerNotizMax).trimRight()
      : kurz;
}

int? _dauer(int? dauer) => dauer == null ? null : _begrenze(dauer);

int _begrenze(int wert) => wert < 0
    ? 0
    : (wert > kZustandsmarkerDauerMax ? kZustandsmarkerDauerMax : wert);
