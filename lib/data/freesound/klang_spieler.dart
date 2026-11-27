import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Ein Audiokanal des Klangpults: spielt genau einen Klang.
///
/// Austauschbar für Tests. Ein Kanal wird nach [blendeAus] oder dem Ende eines
/// Klangs ohne Schleife nicht wiederverwendet.
abstract interface class KlangKanal {
  /// Spielt [url] mit [lautstaerke] (0 bis 1); blendet über [einblenden] ein.
  Future<void> spiele(
    String url, {
    required double lautstaerke,
    bool schleife = true,
    Duration einblenden = Duration.zero,
  });

  /// Setzt die Lautstärke sofort.
  Future<void> setzeLautstaerke(double wert);

  /// Blendet über [dauer] aus, hält an und gibt den Kanal frei.
  Future<void> blendeAus(Duration dauer);
}

/// Erzeugt frische Kanäle.
typedef KlangKanalFabrik = KlangKanal Function();

/// [KlangKanal] über `audioplayers` (alle Plattformen der App).
///
/// audioplayers kennt kein Blenden; die Lautstärke läuft in [_schritte]
/// Schritten über einen Timer.
class AudioplayersKlangKanal implements KlangKanal {
  final AudioPlayer _spieler = AudioPlayer();
  static const int _schritte = 20;
  Timer? _timer;
  Completer<void>? _blende;
  double _wert = 0;
  bool _frei = false;

  @override
  Future<void> spiele(
    String url, {
    required double lautstaerke,
    bool schleife = true,
    Duration einblenden = Duration.zero,
  }) async {
    await _spieler.setReleaseMode(
      schleife ? ReleaseMode.loop : ReleaseMode.stop,
    );
    if (!schleife) {
      unawaited(_spieler.onPlayerComplete.first.then((_) => _freigeben()));
    }
    _wert = einblenden == Duration.zero ? lautstaerke : 0;
    await _spieler.play(UrlSource(url), volume: _wert);
    if (einblenden > Duration.zero) {
      unawaited(_blendeAuf(lautstaerke, einblenden));
    }
  }

  @override
  Future<void> setzeLautstaerke(double wert) {
    _stoppeBlende();
    _wert = wert;
    return _frei ? Future<void>.value() : _spieler.setVolume(wert);
  }

  @override
  Future<void> blendeAus(Duration dauer) async {
    if (_frei) return;
    await _blendeAuf(0, dauer);
    await _freigeben();
  }

  Future<void> _blendeAuf(double ziel, Duration dauer) {
    _stoppeBlende();
    if (dauer <= Duration.zero || _frei) {
      _wert = ziel;
      return _frei ? Future<void>.value() : _spieler.setVolume(ziel);
    }
    final start = _wert;
    final fertig = _blende = Completer<void>();
    var i = 0;
    _timer = Timer.periodic(dauer ~/ _schritte, (timer) {
      i++;
      _wert = start + (ziel - start) * i / _schritte;
      if (!_frei) unawaited(_spieler.setVolume(_wert));
      if (i >= _schritte) _stoppeBlende();
    });
    return fertig.future;
  }

  // Eine abgebrochene Blende gilt als fertig, damit niemand ewig wartet.
  void _stoppeBlende() {
    _timer?.cancel();
    _timer = null;
    final blende = _blende;
    _blende = null;
    if (blende != null && !blende.isCompleted) blende.complete();
  }

  Future<void> _freigeben() async {
    if (_frei) return;
    _frei = true;
    _stoppeBlende();
    await _spieler.dispose();
  }
}

/// Stummer [KlangKanal] für Tests und Vorschauen: merkt sich die Aufrufe.
class StummerKlangKanal implements KlangKanal {
  /// Gespielte Adresse.
  String? url;

  /// Ob als Schleife gespielt.
  bool? schleife;

  /// Zuletzt gesetzte Lautstärke.
  double? lautstaerke;

  /// Ob der Kanal ausgeblendet und freigegeben ist.
  bool ausgeblendet = false;

  @override
  Future<void> spiele(
    String url, {
    required double lautstaerke,
    bool schleife = true,
    Duration einblenden = Duration.zero,
  }) async {
    this.url = url;
    this.schleife = schleife;
    this.lautstaerke = lautstaerke;
  }

  @override
  Future<void> setzeLautstaerke(double wert) async => lautstaerke = wert;

  @override
  Future<void> blendeAus(Duration dauer) async => ausgeblendet = true;
}
