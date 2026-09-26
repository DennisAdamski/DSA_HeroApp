import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_modell.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_ops.dart';

/// Rohausgaben eines Netzdurchlaufs.
class BlazeFaceAusgabe {
  const BlazeFaceAusgabe({required this.regressoren, required this.logits});

  /// 896 x 16 Werte: Box `(x, y, w, h)` in Pixeln der 128er-Eingabe relativ
  /// zum Anker, danach sechs Landmarken.
  final Float32List regressoren;

  /// 896 Score-Logits, vor dem Sigmoid.
  final Float32List logits;
}

/// Fuehrt ein [BlazeFaceModell] auf einer Eingabe aus.
///
/// Generischer Interpreter: Die Architektur steckt allein in der Op-Folge des
/// Assets, der Kern kennt nur die vorkommenden Op-Typen. Zwischenergebnisse
/// werden nach ihrer letzten Verwendung freigegeben.
class BlazeFaceRechenkern {
  BlazeFaceRechenkern(this.modell)
    : _letzteNutzung = _berechneLetzteNutzung(modell);

  final BlazeFaceModell modell;
  final Map<int, int> _letzteNutzung;

  /// Seitenlaenge der quadratischen Netzeingabe.
  int get eingabeSeite => modell.formen[modell.eingabe]![1];

  /// Rechnet das Netz auf einer normierten NHWC-Eingabe (Werte in [-1, 1]).
  ///
  /// [pause] wird zwischen den Ops abgewartet. Im Web gibt das der UI die
  /// Kontrolle zurueck, weil dort kein Hintergrund-Isolate rechnet.
  Future<BlazeFaceAusgabe> rechne(
    Float32List eingabe, {
    Future<void> Function()? pause,
  }) async {
    final erwartet = _anzahl(modell.formen[modell.eingabe]!);
    if (eingabe.length != erwartet) {
      throw ArgumentError(
        'Eingabe hat ${eingabe.length} Werte, erwartet $erwartet.',
      );
    }
    final tensoren = <int, Float32List>{modell.eingabe: eingabe};
    for (var i = 0; i < modell.ops.length; i++) {
      final op = modell.ops[i];
      tensoren[op.ausgabe] = _fuehreAus(op, tensoren);
      for (final id in op.eingaben) {
        if (_letzteNutzung[id] == i) tensoren.remove(id);
      }
      if (pause != null) await pause();
    }
    return BlazeFaceAusgabe(
      regressoren: tensoren[modell.regressoren]!,
      logits: tensoren[modell.klassifikatoren]!,
    );
  }

  Float32List _fuehreAus(BlazeFaceOp op, Map<int, Float32List> tensoren) {
    Float32List tensor(int index) {
      final id = op.eingaben[index];
      final wert = tensoren[id] ?? modell.konstanten[id];
      if (wert == null) {
        throw StateError('Tensor $id fuer ${op.typ} fehlt.');
      }
      return wert;
    }

    List<int> form(int index) {
      final id = op.eingaben[index];
      return modell.formen[id] ?? modell.konstantenFormen[id]!;
    }

    switch (op.typ) {
      case 'CONV_2D':
        final ein = form(0);
        final gewichte = form(1);
        return faltung2d(
          eingabe: tensor(0),
          hoehe: ein[1],
          breite: ein[2],
          kanaeleEin: ein[3],
          gewichte: tensor(1),
          bias: tensor(2),
          kanaeleAus: gewichte[0],
          kernHoehe: gewichte[1],
          kernBreite: gewichte[2],
          strideH: op.stride[0],
          strideW: op.stride[1],
          same: op.same,
          relu: op.relu,
        );
      case 'DEPTHWISE_CONV_2D':
        final ein = form(0);
        final gewichte = form(1);
        return tiefenFaltung2d(
          eingabe: tensor(0),
          hoehe: ein[1],
          breite: ein[2],
          kanaele: ein[3],
          gewichte: tensor(1),
          bias: tensor(2),
          kernHoehe: gewichte[1],
          kernBreite: gewichte[2],
          strideH: op.stride[0],
          strideW: op.stride[1],
          same: op.same,
          relu: op.relu,
        );
      case 'MAX_POOL_2D':
        final ein = form(0);
        return maxPool2d(
          eingabe: tensor(0),
          hoehe: ein[1],
          breite: ein[2],
          kanaele: ein[3],
          filterHoehe: op.filter[0],
          filterBreite: op.filter[1],
          strideH: op.stride[0],
          strideW: op.stride[1],
          same: op.same,
        );
      case 'PAD':
        return auffuellen(
          eingabe: tensor(0),
          form: form(0),
          paddings: op.paddings,
        );
      case 'ADD':
        return addiere(tensor(0), tensor(1), relu: op.relu);
      case 'RELU':
        return gleichrichten(tensor(0));
      case 'RESHAPE':
        // NHWC ist bereits zeilenweise flach; nur die Form aendert sich.
        return tensor(0);
      case 'CONCATENATION':
        return verketten(
          eingaben: [for (var i = 0; i < op.eingaben.length; i++) tensor(i)],
          formen: [for (var i = 0; i < op.eingaben.length; i++) form(i)],
          form: modell.formen[op.ausgabe]!,
          achse: op.achse,
        );
    }
    throw UnsupportedError('Op ${op.typ} wird nicht unterstuetzt.');
  }

  static Map<int, int> _berechneLetzteNutzung(BlazeFaceModell modell) {
    final letzte = <int, int>{};
    for (var i = 0; i < modell.ops.length; i++) {
      for (final id in modell.ops[i].eingaben) {
        if (!modell.konstanten.containsKey(id)) letzte[id] = i;
      }
    }
    // Die Netzausgaben duerfen nie freigegeben werden.
    letzte
      ..remove(modell.regressoren)
      ..remove(modell.klassifikatoren);
    return letzte;
  }

  static int _anzahl(List<int> form) => form.fold<int>(1, (a, b) => a * b);
}
