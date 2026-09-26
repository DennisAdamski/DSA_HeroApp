# Gesichtserkennung für Avatare

Die App richtet beschnittene Avatarflächen (Heldenmarke, Album, Header,
Gruppen-Thumbnail) am erkannten Gesicht aus. Erkannt wird mit Googles
**BlazeFace Short Range** aus dem MediaPipe Face Detector (Apache 2.0). Das
Netz rechnet in reinem Dart (`lib/data/avatar_gesicht/`), damit Windows,
macOS, Linux, iOS, Android und Web ohne native Bibliothek und ohne CDN
dasselbe Ergebnis liefern.

## Dateien

| Datei | Zweck |
|---|---|
| `convert_blazeface.py` | `.tflite` → `assets/models/blazeface_short_range.bin` |
| `reference_outputs.py` | Sollwerte der offiziellen Laufzeit → `test/fixtures/avatar_gesicht/` |
| `assets/models/LICENSE_blazeface.txt` | Herkunft und Apache-2.0-Lizenz des Modells |

Das Asset ist ein JSON-Kopf mit der Op-Folge plus alle Gewichte als float16.
Die `DEQUANTIZE`-Ops des Originals löst der Konverter auf. Der Dart-Kern
kennt deshalb nur `CONV_2D`, `DEPTHWISE_CONV_2D`, `ADD`, `RELU`,
`MAX_POOL_2D`, `PAD`, `RESHAPE` und `CONCATENATION`; jede andere Op lässt den
Konverter abbrechen.

## Neu erzeugen

Nur bei einem bewussten Modellwechsel. Die Fixtures werden **nie** angepasst,
nur damit ein roter Golden-Test wieder grün wird: dann rechnet der Dart-Kern
falsch.

```bash
python -m venv .venv && .venv/bin/pip install numpy tflite ai-edge-litert pillow
curl -LO https://storage.googleapis.com/mediapipe-models/face_detector/blaze_face_short_range/float16/latest/blaze_face_short_range.tflite
.venv/bin/python tool/avatar_gesicht/convert_blazeface.py --model blaze_face_short_range.tflite
.venv/bin/python tool/avatar_gesicht/reference_outputs.py \
    --model blaze_face_short_range.tflite \
    --mona-lisa <Mona Lisa, z. B. 500px-Thumbnail von Wikimedia Commons> \
    --ludwig <Ludwig XIV. von Rigaud, z. B. 500px-Thumbnail>
```

Die Testvorlagen sind gemeinfreie Gemälde (Mona Lisa, Leonardo da Vinci;
Ludwig XIV., Hyacinthe Rigaud). Wikimedia liefert Thumbnails nur in festen
Breiten, z. B. 330 oder 500 px.

Nach einem Modellwechsel muss `kAvatarGesichtDetektorVersion` in
`lib/data/avatar_gesicht/avatar_gesichtserkennung.dart` steigen, damit die
lokalen Caches (`avatar_gesicht_v1`) neu erkennen.
