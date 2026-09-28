#!/usr/bin/env python3
"""Wandelt MediaPipes BlazeFace-Modell in das Asset der Dart-Erkennung um.

Eingabe ist `blaze_face_short_range.tflite` (MediaPipe Face Detector, float16,
Apache 2.0). Ausgabe ist `assets/models/blazeface_short_range.bin`:

    4 Byte    Laenge L des JSON-Kopfs (uint32, little endian)
    L Byte    JSON-Kopf (UTF-8), mit Leerzeichen auf gerade Laenge aufgefuellt
    Rest      alle Konstanten als float16 (little endian), hintereinander

Der Kopf beschreibt den Graphen als Op-Folge in Ausfuehrungsreihenfolge. Die
`DEQUANTIZE`-Ops des Originals verschwinden: Ihre float32-Ausgabe entspricht
bitgenau den float16-Werten, deshalb stehen diese direkt als Konstante unter
der Tensor-ID der Dequantisierungsausgabe. Die Dart-Seite
(`lib/data/avatar_gesicht/blazeface_modell.dart`) kennt damit nur noch die
Ops, die tatsaechlich rechnen.

Aufruf:
    python tool/avatar_gesicht/convert_blazeface.py \
        --model blaze_face_short_range.tflite \
        --out assets/models/blazeface_short_range.bin

Benoetigt `numpy` und `tflite` (pip).
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path

import numpy as np
import tflite
from tflite.ActivationFunctionType import ActivationFunctionType
from tflite.BuiltinOperator import BuiltinOperator
from tflite.Padding import Padding
from tflite.TensorType import TensorType

FORMAT = "dsa-blazeface-v1"

_OP_NAMES = {
    value: name for name, value in BuiltinOperator.__dict__.items()
    if not name.startswith("_")
}
_PADDING_NAMES = {Padding.SAME: "SAME", Padding.VALID: "VALID"}
_ACTIVATION_NAMES = {
    ActivationFunctionType.NONE: "NONE",
    ActivationFunctionType.RELU: "RELU",
}
_NUMPY_TYPES = {
    TensorType.FLOAT32: np.float32,
    TensorType.FLOAT16: np.float16,
    TensorType.INT32: np.int32,
}


def _tensor_shape(graph, index: int) -> list[int]:
    tensor = graph.Tensors(index)
    if tensor.ShapeLength() == 0:
        return []
    return [int(v) for v in tensor.ShapeAsNumpy()]


def _tensor_data(model, graph, index: int) -> np.ndarray | None:
    tensor = graph.Tensors(index)
    buffer = model.Buffers(tensor.Buffer())
    if buffer is None or buffer.DataLength() == 0:
        return None
    dtype = _NUMPY_TYPES.get(tensor.Type())
    if dtype is None:
        raise ValueError(f"Unbekannter Tensortyp {tensor.Type()} bei {index}")
    raw = buffer.DataAsNumpy().tobytes()
    return np.frombuffer(raw, dtype=dtype).reshape(_tensor_shape(graph, index))


def _builtin_name(model, op) -> str:
    code = model.OperatorCodes(op.OpcodeIndex())
    builtin = max(code.BuiltinCode(), code.DeprecatedBuiltinCode())
    return _OP_NAMES.get(builtin, str(builtin))


def _options(op, options_class):
    table = op.BuiltinOptions()
    if table is None:
        return None
    options = options_class()
    options.Init(table.Bytes, table.Pos)
    return options


def _activation(value: int) -> str:
    if value not in _ACTIVATION_NAMES:
        raise ValueError(f"Nicht unterstuetzte Aktivierung {value}")
    return _ACTIVATION_NAMES[value]


def convert(model_path: Path) -> tuple[dict, bytes]:
    buf = model_path.read_bytes()
    model = tflite.Model.GetRootAsModel(buf, 0)
    graph = model.Subgraphs(0)

    constants: dict[int, np.ndarray] = {}
    ops: list[dict] = []

    for i in range(graph.OperatorsLength()):
        op = graph.Operators(i)
        name = _builtin_name(model, op)
        inputs = [op.Inputs(j) for j in range(op.InputsLength())]
        outputs = [op.Outputs(j) for j in range(op.OutputsLength())]

        if name == "DEQUANTIZE":
            data = _tensor_data(model, graph, inputs[0])
            if data is None:
                raise ValueError(f"DEQUANTIZE ohne Konstante in Op {i}")
            constants[outputs[0]] = data.astype(np.float16)
            continue

        entry: dict = {"op": name, "in": inputs, "out": outputs}
        if name == "CONV_2D":
            opts = _options(op, tflite.Conv2DOptions)
            entry["stride"] = [opts.StrideH(), opts.StrideW()]
            entry["padding"] = _PADDING_NAMES[opts.Padding()]
            entry["activation"] = _activation(opts.FusedActivationFunction())
            if opts.DilationHFactor() != 1 or opts.DilationWFactor() != 1:
                raise ValueError("Dilatation wird nicht unterstuetzt")
        elif name == "DEPTHWISE_CONV_2D":
            opts = _options(op, tflite.DepthwiseConv2DOptions)
            entry["stride"] = [opts.StrideH(), opts.StrideW()]
            entry["padding"] = _PADDING_NAMES[opts.Padding()]
            entry["activation"] = _activation(opts.FusedActivationFunction())
            if opts.DepthMultiplier() not in (0, 1):
                raise ValueError("Tiefenmultiplikator wird nicht unterstuetzt")
            if opts.DilationHFactor() != 1 or opts.DilationWFactor() != 1:
                raise ValueError("Dilatation wird nicht unterstuetzt")
        elif name == "MAX_POOL_2D":
            opts = _options(op, tflite.Pool2DOptions)
            entry["stride"] = [opts.StrideH(), opts.StrideW()]
            entry["filter"] = [opts.FilterHeight(), opts.FilterWidth()]
            entry["padding"] = _PADDING_NAMES[opts.Padding()]
            entry["activation"] = _activation(opts.FusedActivationFunction())
        elif name == "ADD":
            opts = _options(op, tflite.AddOptions)
            entry["activation"] = _activation(
                opts.FusedActivationFunction() if opts else 0
            )
        elif name == "PAD":
            paddings = _tensor_data(model, graph, inputs[1])
            if paddings is None:
                raise ValueError(f"PAD ohne konstante Paddings in Op {i}")
            entry["in"] = inputs[:1]
            entry["paddings"] = paddings.astype(int).tolist()
        elif name == "CONCATENATION":
            opts = _options(op, tflite.ConcatenationOptions)
            entry["axis"] = opts.Axis()
            entry["activation"] = _activation(opts.FusedActivationFunction())
        elif name == "RESHAPE":
            # Der Zielshape steht im Ausgabetensor; ein zweiter Eingang (die
            # Shape-Konstante) wird nicht gebraucht.
            entry["in"] = inputs[:1]
        elif name == "RELU":
            pass
        else:
            raise ValueError(f"Nicht unterstuetzte Op {name} (Index {i})")
        ops.append(entry)

    # Nur Tensoren, die als Aktivierung auftauchen, brauchen einen Shape.
    activation_ids = sorted(
        {t for op in ops for t in op["in"] + op["out"] if t not in constants}
    )
    tensors = {str(t): _tensor_shape(graph, t) for t in activation_ids}

    blob = bytearray()
    const_meta = {}
    for tensor_id in sorted(constants):
        data = constants[tensor_id]
        raw = data.astype("<f2").tobytes()
        const_meta[str(tensor_id)] = {
            "shape": list(data.shape),
            "offset": len(blob) // 2,
            "length": int(data.size),
        }
        blob.extend(raw)

    header = {
        "format": FORMAT,
        "input": graph.Inputs(0),
        "outputs": {
            graph.Tensors(graph.Outputs(k)).Name().decode(): graph.Outputs(k)
            for k in range(graph.OutputsLength())
        },
        "tensors": tensors,
        "constants": const_meta,
        "ops": ops,
    }
    return header, bytes(blob)


def write_asset(header: dict, blob: bytes, out_path: Path) -> None:
    header_bytes = json.dumps(header, separators=(",", ":")).encode("utf-8")
    if len(header_bytes) % 2:
        header_bytes += b" "
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("wb") as handle:
        handle.write(struct.pack("<I", len(header_bytes)))
        handle.write(header_bytes)
        handle.write(blob)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("assets/models/blazeface_short_range.bin"),
    )
    args = parser.parse_args()
    header, blob = convert(args.model)
    write_asset(header, blob, args.out)
    print(
        f"{args.out}: {len(header['ops'])} Ops, "
        f"{len(header['constants'])} Konstanten, {len(blob)} Byte Gewichte"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
