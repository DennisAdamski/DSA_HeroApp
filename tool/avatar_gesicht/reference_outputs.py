#!/usr/bin/env python3
"""Erzeugt die Referenz-Fixtures fuer den Golden-Test der Dart-Erkennung.

Rechnet `blaze_face_short_range.tflite` mit Googles offizieller Laufzeit
(`ai-edge-litert`) auf einer festen Eingabe und schreibt nach
`test/fixtures/avatar_gesicht/`:

- `<name>.jpg`: verkleinerte Testvorlage fuer den Ende-zu-Ende-Test.
- `<name>_128.rgb`: die Netzeingabe als rohes RGB (128 x 128 x 3, uint8),
  mittig letterboxed. Der Golden-Test normiert sie selbst auf [-1, 1] und
  prueft damit den Rechenkern unabhaengig vom Bilddekoder.
- `<name>_128_referenz.json`: alle 896 Score-Logits und die Regressoren der
  staerksten Anker als Sollwerte.

Die Vorlagen sind gemeinfreie Gemaelde (Wikimedia Commons, Reproduktionen
zweidimensionaler Werke ohne eigenen Schutz):

- Mona Lisa, Leonardo da Vinci (Nahportraet, erster Durchlauf).
- Ludwig XIV., Hyacinthe Rigaud (Ganzkoerper, zweiter Durchlauf).

Aufruf:
    python tool/avatar_gesicht/reference_outputs.py \
        --model blaze_face_short_range.tflite \
        --mona-lisa mona_lisa.jpg --ludwig ludwig_xiv.jpg

Benoetigt `numpy`, `pillow` und `ai-edge-litert` (pip). Die Fixtures werden
nur neu erzeugt, wenn sich das Modell bewusst aendert — nie, damit ein
fehlschlagender Test wieder gruen wird.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from PIL import Image

OUT_DIR = Path("test/fixtures/avatar_gesicht")
TOP_ANKER = 24


def letterbox_rgb(image: Image.Image) -> np.ndarray:
    width, height = image.size
    scale = 128 / max(width, height)
    new_w, new_h = round(width * scale), round(height * scale)
    resized = image.convert("RGB").resize((new_w, new_h), Image.BILINEAR)
    canvas = Image.new("RGB", (128, 128), (0, 0, 0))
    canvas.paste(resized, ((128 - new_w) // 2, (128 - new_h) // 2))
    return np.asarray(canvas, dtype=np.uint8)


def run_model(model_path: Path, rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    interpreter = Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    input_index = interpreter.get_input_details()[0]["index"]
    outputs = {d["name"]: d["index"] for d in interpreter.get_output_details()}
    tensor = rgb.astype(np.float32) / 127.5 - 1.0
    interpreter.set_tensor(input_index, tensor[None])
    interpreter.invoke()
    regressors = interpreter.get_tensor(outputs["regressors"])[0]
    logits = interpreter.get_tensor(outputs["classificators"])[0, :, 0]
    return regressors, logits


def save_jpeg(source: Path, target: Path, width: int) -> None:
    image = Image.open(source).convert("RGB")
    height = round(image.height * width / image.width)
    image.resize((width, height), Image.LANCZOS).save(target, quality=80)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--mona-lisa", required=True, type=Path)
    parser.add_argument("--ludwig", required=True, type=Path)
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    save_jpeg(args.mona_lisa, OUT_DIR / "mona_lisa.jpg", 240)
    save_jpeg(args.ludwig, OUT_DIR / "ludwig_xiv.jpg", 300)

    rgb = letterbox_rgb(Image.open(OUT_DIR / "mona_lisa.jpg"))
    (OUT_DIR / "mona_lisa_128.rgb").write_bytes(rgb.tobytes())

    regressors, logits = run_model(args.model, rgb)
    top = np.argsort(-logits)[:TOP_ANKER]
    referenz = {
        "quelle": "ai-edge-litert, blaze_face_short_range.tflite (float16)",
        "logits": [round(float(v), 5) for v in logits],
        "regressoren": {
            str(int(i)): [round(float(v), 4) for v in regressors[i]]
            for i in top
        },
    }
    (OUT_DIR / "mona_lisa_128_referenz.json").write_text(
        json.dumps(referenz, indent=1) + "\n", encoding="utf-8"
    )
    print(f"Fixtures in {OUT_DIR} geschrieben; staerkster Anker {int(top[0])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
