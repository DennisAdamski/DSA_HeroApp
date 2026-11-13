import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kacheln.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kamera.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_maler.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';

/// Was ein Tipp auf der Karte getroffen hat.
sealed class KartenTreffer {
  const KartenTreffer();
}

/// Ein Ort des Ortsverzeichnisses.
class KartenTrefferOrt extends KartenTreffer {
  /// Erstellt den Treffer.
  const KartenTrefferOrt(this.ort);

  /// Der Ort.
  final AvesmapsOrt ort;
}

/// Eine Station der Reiseroute.
class KartenTrefferStation extends KartenTreffer {
  /// Erstellt den Treffer.
  const KartenTrefferStation(this.station, this.nummer);

  /// Die Station.
  final HeroReiseStation station;

  /// Ihre Etappennummer.
  final int nummer;
}

/// Die Aventurien-Karte im Stil von Avesmaps.
///
/// Zeigt das selbst gehostete Kartenbild ([manifest]) oder ohne Kartenbild
/// Papier mit einem Landschimmer aus den Ortsdaten. Darüber liegen Orte und
/// Namen nach den Zoomtafeln von Avesmaps, die Route als Luftlinie, die
/// nummerierten Stationen und der Reisende am Standort.
///
/// [interaktiv] erlaubt Zoomen, Verschieben und Tippen auf Orte; sonst
/// passt die Karte [start] ein und meldet nur [onTap].
class KartoKarte extends StatefulWidget {
  /// Erstellt die Karte.
  const KartoKarte({
    super.key,
    required this.orte,
    this.routenPunkte = const <KartenRoutenPunkt>[],
    this.standort,
    this.manifest,
    this.start,
    this.interaktiv = true,
    this.auswahl,
    this.onTreffer,
    this.onTap,
    this.hoechsterStartZoom = 6,
  });

  /// Ortsverzeichnis von Avesmaps; leer zeigt nur Route und Standort.
  final List<AvesmapsOrt> orte;

  /// Stationen mit Position, in zeitlicher Reihenfolge.
  final List<KartenRoutenPunkt> routenPunkte;

  /// Aktueller Standort, oder `null`.
  final AvesmapsOrt? standort;

  /// Kartenkacheln; `null` zeichnet ohne Kartenbild.
  final KartenKachelManifest? manifest;

  /// Ausschnitt beim Öffnen; ohne ihn Route und Standort, sonst die ganze
  /// Karte.
  final KartenRechteck? start;

  /// Ob die Karte sich bedienen lässt.
  final bool interaktiv;

  /// Kennung des hervorgehobenen Orts bzw. der hervorgehobenen Station.
  final String? auswahl;

  /// Meldet einen Tipp auf Ort oder Station (nur [interaktiv]); `null`
  /// heißt ein Tipp ins Leere.
  final ValueChanged<KartenTreffer?>? onTreffer;

  /// Tipp auf die nicht interaktive Karte.
  final VoidCallback? onTap;

  /// Größter Zoom beim Einpassen.
  final double hoechsterStartZoom;

  @override
  State<KartoKarte> createState() => KartoKarteState();
}

/// Zustand der Karte; [einpassen] und [zoomeUm] bedienen sie von außen.
class KartoKarteState extends State<KartoKarte> {
  final KartenTextSpeicher _texte = KartenTextSpeicher();
  final KartenKachelSpeicher _kacheln = KartenKachelSpeicher();
  KartenKamera? _kamera;
  Size _groesse = Size.zero;
  List<AvesmapsOrt> _sortiert = const <AvesmapsOrt>[];
  ui.Image? _land;
  bool? _landDunkel;
  List<AvesmapsOrt>? _landFuer;

  // Gestenzustand.
  double _startZoom = 0;
  Offset _letzterFokus = Offset.zero;

  /// Aktueller Blick auf die Karte, oder `null` vor dem ersten Layout.
  KartenKamera? get kamera => _kamera;

  @override
  void initState() {
    super.initState();
    _sortiere();
    _kacheln.manifest = widget.manifest;
  }

  @override
  void didUpdateWidget(KartoKarte oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.orte, widget.orte)) _sortiere();
    _kacheln.manifest = widget.manifest;
    if (!widget.interaktiv && oldWidget.start != widget.start) _kamera = null;
  }

  @override
  void dispose() {
    _kacheln.dispose();
    _land?.dispose();
    super.dispose();
  }

  void _sortiere() {
    _sortiert = List<AvesmapsOrt>.of(widget.orte)
      ..sort((a, b) => kartenVorrang(a.art).compareTo(kartenVorrang(b.art)));
  }

  void _pruefeLand(bool dunkel) {
    if (identical(_landFuer, widget.orte) && _landDunkel == dunkel) return;
    _land?.dispose();
    _land = zeichneLandschimmer(widget.orte, dunkel: dunkel);
    _landFuer = widget.orte;
    _landDunkel = dunkel;
  }

  KartenRechteck _startAusschnitt() {
    final start = widget.start;
    if (start != null) return start;
    return kartenAusschnitt(<(double, double)>[
      for (final p in widget.routenPunkte) (p.x, p.y),
      if (widget.standort != null) (widget.standort!.x, widget.standort!.y),
    ], ohnePunkte: kartenBegrenzung(widget.orte));
  }

  /// Passt [rechteck] (ohne Angabe Route und Standort) ein.
  void einpassen([KartenRechteck? rechteck]) {
    if (_groesse.isEmpty) return;
    setState(() {
      _kamera = KartenKamera.einpassen(
        rechteck ?? _startAusschnitt(),
        _groesse,
        hoechstens: widget.hoechsterStartZoom,
      );
    });
  }

  /// Zoomt um [stufen] um die Bildmitte.
  void zoomeUm(double stufen) {
    final kamera = _kamera;
    if (kamera == null) return;
    setState(() {
      _kamera = kamera.gezoomt(
        kamera.zoom + stufen,
        _groesse.center(Offset.zero),
        _groesse,
      );
    });
  }

  /// Zeigt die Position ([x], [y]) in der Mitte, mindestens bei [zoom].
  void zeige(double x, double y, {double zoom = 5}) {
    final kamera = _kamera;
    setState(() {
      _kamera = KartenKamera(
        x: x,
        y: y,
        zoom: math
            .max(kamera?.zoom ?? 0, zoom)
            .clamp(kKartenZoomMin, kKartenZoomMax),
      );
    });
  }

  void _setze(KartenKamera neu) {
    if (neu == _kamera) return;
    setState(() => _kamera = neu);
  }

  KartenTreffer? _treffer(Offset punkt) {
    final kamera = _kamera;
    if (kamera == null) return null;
    // Stationen liegen oben und gehen vor.
    for (final p in widget.routenPunkte.reversed) {
      final lage = kamera.zuBildschirm(p.x, p.y, _groesse);
      if ((lage - punkt).distance <= kWegpunktHalbmesser + 4) {
        return KartenTrefferStation(p.station, p.nummer);
      }
    }
    AvesmapsOrt? bester;
    var besterAbstand = double.infinity;
    final sichtbar = kamera.sichtbar(_groesse);
    for (final ort in _sortiert) {
      if (ort.x < sichtbar.minX ||
          ort.x > sichtbar.maxX ||
          ort.y < sichtbar.minY ||
          ort.y > sichtbar.maxY) {
        continue;
      }
      final d = markerDurchmesser(ort.art, kamera.zoom);
      if (d == null) continue;
      final abstand =
          (kamera.zuBildschirm(ort.x, ort.y, _groesse) - punkt).distance;
      final reichweite = math.max(12.0, d / 2 + 6);
      // Gleich nah: der bedeutendere Ort (später in der Liste) gewinnt.
      if (abstand <= reichweite && abstand <= besterAbstand) {
        bester = ort;
        besterAbstand = abstand;
      }
    }
    return bester == null ? null : KartenTrefferOrt(bester);
  }

  void _benoetigeKacheln(KartenKamera kamera) {
    final manifest = widget.manifest;
    if (manifest == null || _groesse.isEmpty) return;
    final z = kachelStufe(kamera, manifest.maxZoom);
    _kacheln.benoetige(<KachelNummer>[
      // Die ganze Karte in Stufe 0 als Platzhalter für alles.
      (0, 0, 0),
      ...kachelnIm(kamera.sichtbar(_groesse), z),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final dunkel = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final groesse = constraints.biggest;
        if (groesse != _groesse) {
          _groesse = groesse;
          if (!widget.interaktiv) _kamera = null;
        }
        final kamera = _kamera ??= KartenKamera.einpassen(
          _startAusschnitt(),
          groesse,
          hoechstens: widget.hoechsterStartZoom,
        );
        if (widget.manifest == null) {
          _pruefeLand(dunkel);
        } else {
          _benoetigeKacheln(kamera);
        }
        final karte = CustomPaint(
          size: groesse,
          isComplex: true,
          painter: KartenMaler(
            texte: _texte,
            repaint: _kacheln,
            szene: KartenSzene(
              kamera: kamera,
              orte: _sortiert,
              dunkel: dunkel,
              routenPunkte: widget.routenPunkte,
              standort: widget.standort,
              auswahl: widget.auswahl,
              landschimmer: widget.manifest == null ? _land : null,
              kacheln: widget.manifest == null ? null : _kacheln,
              mitKompass: widget.interaktiv,
            ),
          ),
        );
        if (!widget.interaktiv) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: karte,
          );
        }
        return Listener(
          onPointerSignal: (signal) {
            if (signal is! PointerScrollEvent) return;
            final k = _kamera;
            if (k == null) return;
            GestureBinding.instance.pointerSignalResolver.register(signal, (_) {
              _setze(
                k.gezoomt(
                  k.zoom - signal.scrollDelta.dy / 240,
                  signal.localPosition,
                  _groesse,
                ),
              );
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _startZoom = _kamera?.zoom ?? 0;
              _letzterFokus = details.localFocalPoint;
            },
            onScaleUpdate: (details) {
              final k = _kamera;
              if (k == null) return;
              final verschoben = k.verschoben(
                details.localFocalPoint - _letzterFokus,
              );
              _letzterFokus = details.localFocalPoint;
              final zoom = details.scale == 1
                  ? verschoben.zoom
                  : _startZoom + math.log(details.scale) / math.ln2;
              _setze(
                verschoben.gezoomt(zoom, details.localFocalPoint, _groesse),
              );
            },
            onTapUp: (details) =>
                widget.onTreffer?.call(_treffer(details.localPosition)),
            onDoubleTapDown: (details) {
              final k = _kamera;
              if (k == null) return;
              _setze(k.gezoomt(k.zoom + 1, details.localPosition, _groesse));
            },
            onDoubleTap: () {},
            child: karte,
          ),
        );
      },
    );
  }
}

/// Bedienknopf der Karte im Stil von Avesmaps: taupe-braun, 32 px, Radius 8.
class KartoKartenKnopf extends StatelessWidget {
  /// Erstellt den Knopf.
  const KartoKartenKnopf({
    super.key,
    required this.symbol,
    required this.tooltip,
    required this.onPressed,
  });

  /// Symbol.
  final IconData symbol;

  /// Beschriftung für Hilfe und Bildschirmleser.
  final String tooltip;

  /// Aktion; `null` sperrt den Knopf.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: KartenFarben.knopf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: KartenFarben.knopfRand),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(symbol, size: 20, color: KartenFarben.knopfText),
          ),
        ),
      ),
    );
  }
}

/// Namensnennung in der Kartenecke: Ortsdaten immer, das Kartenmaterial samt
/// Logo und Lizenz nur mit Kartenbild.
class KartoKartenNennung extends StatelessWidget {
  /// Erstellt die Nennung.
  const KartoKartenNennung({super.key, this.manifest, this.knapp = false});

  /// Kartenkacheln, oder `null` (ohne Kartenbild).
  final KartenKachelManifest? manifest;

  /// Nur eine Zeile (Kachel der Spielansicht).
  final bool knapp;

  /// Pflichtzeile des Kartenmaterials, falls das Manifest keine nennt.
  static const String kartenmaterial =
      'Kartenmaterial © Ulisses Spiele · Originalkarte: Ina Kramer · '
      'Bearbeitung: Avesmaps (DSA-Fanprojekt)';

  @override
  Widget build(BuildContext context) {
    final manifest = this.manifest;
    final zeilen = <String>[
      if (manifest != null)
        manifest.nennung.isEmpty
            ? kartenmaterial
            : manifest.nennung.join(' · '),
      'Ortsdaten: Avesmaps (avesmaps.de)',
      if (manifest != null && manifest.lizenzUri.isNotEmpty && !knapp)
        'Lizenz: ${manifest.lizenzUri}',
    ];
    final logo = manifest?.logoAdresse;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: KartenFarben.tafel.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (logo != null && !knapp) ...[
              Image.network(
                logo.toString(),
                height: 28,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                zeilen.join('\n'),
                key: const ValueKey<String>('karto-karte-nennung'),
                maxLines: knapp ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kKartenSchrift,
                  fontSize: 10,
                  height: 1.25,
                  color: KartenFarben.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
