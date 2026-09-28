import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// Kennung des Asset-Formats, siehe `tool/avatar_gesicht/convert_blazeface.py`.
const String kBlazeFaceModellFormat = 'dsa-blazeface-v1';

/// Asset-Pfad des umgewandelten BlazeFace-Modells.
const String kBlazeFaceModellAsset = 'assets/models/blazeface_short_range.bin';

/// Eine rechnende Operation des Graphen.
class BlazeFaceOp {
  const BlazeFaceOp({
    required this.typ,
    required this.eingaben,
    required this.ausgabe,
    this.stride = const [1, 1],
    this.filter = const [1, 1],
    this.same = true,
    this.relu = false,
    this.paddings = const [],
    this.achse = 0,
  });

  /// TFLite-Name der Op, z. B. `CONV_2D`.
  final String typ;

  /// Tensor-IDs der Eingaben (Aktivierungen und Konstanten).
  final List<int> eingaben;

  /// Tensor-ID der einzigen Ausgabe.
  final int ausgabe;

  /// Schrittweite `[hoehe, breite]` fuer Faltungen und Pooling.
  final List<int> stride;

  /// Fenstergroesse `[hoehe, breite]` fuer Pooling.
  final List<int> filter;

  /// `true` fuer TFLite-Padding `SAME`, sonst `VALID`.
  final bool same;

  /// Ob eine eingebettete ReLU-Aktivierung folgt.
  final bool relu;

  /// Pad-Mengen `[[vor, nach], ...]` je Dimension fuer `PAD`.
  final List<List<int>> paddings;

  /// Verkettungsachse fuer `CONCATENATION`.
  final int achse;
}

/// Das BlazeFace-Netz als Op-Folge mit dequantisierten Gewichten.
///
/// Rein Dart und ohne Flutter-Abhaengigkeit, damit es auch im Hintergrund-
/// Isolate aufgebaut werden kann.
class BlazeFaceModell {
  const BlazeFaceModell({
    required this.eingabe,
    required this.regressoren,
    required this.klassifikatoren,
    required this.formen,
    required this.konstanten,
    required this.konstantenFormen,
    required this.ops,
  });

  /// Tensor-ID der Netzeingabe `[1, 128, 128, 3]`.
  final int eingabe;

  /// Tensor-ID der Box-Regressoren `[1, 896, 16]`.
  final int regressoren;

  /// Tensor-ID der Score-Logits `[1, 896, 1]`.
  final int klassifikatoren;

  /// Formen aller Aktivierungstensoren.
  final Map<int, List<int>> formen;

  /// Gewichte und Bias-Werte als float32.
  final Map<int, Float32List> konstanten;

  /// Formen der Konstanten.
  final Map<int, List<int>> konstantenFormen;

  /// Ops in Ausfuehrungsreihenfolge.
  final List<BlazeFaceOp> ops;

  /// Liest das Asset-Format `dsa-blazeface-v1`.
  ///
  /// Wirft [FormatException] bei unbekanntem Format oder fehlerhafter Datei.
  static BlazeFaceModell ausBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      throw const FormatException('BlazeFace-Modell ist leer.');
    }
    final daten = ByteData.sublistView(bytes);
    final kopfLaenge = daten.getUint32(0, Endian.little);
    if (4 + kopfLaenge > bytes.length) {
      throw const FormatException('BlazeFace-Modellkopf ist abgeschnitten.');
    }
    final kopf = jsonDecode(
      utf8.decode(Uint8List.sublistView(bytes, 4, 4 + kopfLaenge)),
    ) as Map<String, dynamic>;
    if (kopf['format'] != kBlazeFaceModellFormat) {
      throw FormatException('Unbekanntes Modellformat: ${kopf['format']}');
    }

    final gewichtStart = 4 + kopfLaenge;
    final konstanten = <int, Float32List>{};
    final konstantenFormen = <int, List<int>>{};
    final rohKonstanten = kopf['constants'] as Map<String, dynamic>;
    for (final eintrag in rohKonstanten.entries) {
      final meta = eintrag.value as Map<String, dynamic>;
      final offset = meta['offset'] as int;
      final laenge = meta['length'] as int;
      final byteStart = gewichtStart + offset * 2;
      if (byteStart + laenge * 2 > bytes.length) {
        throw FormatException('Konstante ${eintrag.key} liegt ausserhalb.');
      }
      final werte = Float32List(laenge);
      for (var i = 0; i < laenge; i++) {
        werte[i] = halbZuFloat(
          daten.getUint16(byteStart + i * 2, Endian.little),
        );
      }
      final id = int.parse(eintrag.key);
      konstanten[id] = werte;
      konstantenFormen[id] = _intListe(meta['shape']);
    }

    final formen = <int, List<int>>{
      for (final eintrag in (kopf['tensors'] as Map<String, dynamic>).entries)
        int.parse(eintrag.key): _intListe(eintrag.value),
    };

    final ops = <BlazeFaceOp>[];
    for (final roh in kopf['ops'] as List<dynamic>) {
      final op = roh as Map<String, dynamic>;
      final ausgaben = _intListe(op['out']);
      if (ausgaben.length != 1) {
        throw FormatException(
          'Op ${op['op']} hat ${ausgaben.length} Ausgaben.',
        );
      }
      ops.add(
        BlazeFaceOp(
          typ: op['op'] as String,
          eingaben: _intListe(op['in']),
          ausgabe: ausgaben.single,
          stride: op['stride'] == null ? const [1, 1] : _intListe(op['stride']),
          filter: op['filter'] == null ? const [1, 1] : _intListe(op['filter']),
          same: (op['padding'] ?? 'SAME') == 'SAME',
          relu: op['activation'] == 'RELU',
          paddings: [
            for (final paar in (op['paddings'] as List<dynamic>? ?? const []))
              _intListe(paar),
          ],
          achse: (op['axis'] as int?) ?? 0,
        ),
      );
    }

    final ausgaben = kopf['outputs'] as Map<String, dynamic>;
    return BlazeFaceModell(
      eingabe: kopf['input'] as int,
      regressoren: ausgaben['regressors'] as int,
      klassifikatoren: ausgaben['classificators'] as int,
      formen: formen,
      konstanten: konstanten,
      konstantenFormen: konstantenFormen,
      ops: ops,
    );
  }
}

/// Wandelt ein IEEE-754-Halbwort (float16) in einen Dart-`double`.
double halbZuFloat(int halb) {
  final vorzeichen = (halb & 0x8000) != 0 ? -1.0 : 1.0;
  final exponent = (halb >> 10) & 0x1f;
  final mantisse = halb & 0x3ff;
  if (exponent == 0) {
    // Subnormal: 2^-14 * (mantisse / 1024).
    return vorzeichen * mantisse * 5.960464477539063e-8;
  }
  if (exponent == 0x1f) {
    return mantisse == 0 ? vorzeichen * double.infinity : double.nan;
  }
  return vorzeichen * (1 + mantisse / 1024) * _zweierPotenzen[exponent];
}

// 2^(e - 15) fuer alle normalen Exponenten 1..30 eines float16.
final List<double> _zweierPotenzen = List<double>.generate(
  31,
  (exponent) => math.pow(2, exponent - 15).toDouble(),
  growable: false,
);

List<int> _intListe(Object? roh) {
  return [for (final wert in roh as List<dynamic>) wert as int];
}
