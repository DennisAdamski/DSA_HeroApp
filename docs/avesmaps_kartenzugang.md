# Kartenbild von Avesmaps einspielen

Ablauf für den Moment, in dem Avesmaps den Zugang zur Karten-API schickt
(Antwort auf Issue 7 im Avesmaps-Repository). Bis dahin zeigt die App die
Aventurien-Karte ohne Kartenbild: Papier, Landschimmer aus den Ortsdaten,
Orte, Route. Hintergrund und Entscheidungen stehen in
[reiseroute_plan.md](reiseroute_plan.md), der Hosting-Teil in
[web_deployment.md](web_deployment.md) unter „Kartenkacheln“.

## Stand (13.11.2026)

- Anfrage in Issue 7 abgeschickt: Serie `modern`, 16384 px, eigenes Hosting,
  nicht-kommerziell.
- Nicht-kommerzielle Nutzung bestätigt; die Lizenz des Ulisses-Kartenpakets
  verlangt sie.
- Hosting-Site `heldensync-karten` angelegt.
- In der App fertig:
  - Manifest und Kachelspeicher;
  - Konfiguration `firebase.karten.json`;
  - CSP der App-Sites (`img-src` und `connect-src` erlauben
    `https://heldensync-karten.web.app`);
  - Lizenzeintrag, Datenschutztext;
  - Werkzeug `tool/avesmaps_karte_kacheln.py` (mit synthetischem Bild getestet).
- Es fehlen nur die Schritte unten.

## Ablauf

### 1 · Zugang sofort nutzen

Der Zugang ist ein Link oder ein Schlüssel `avk_…`. Er hat eine Frist und eine
begrenzte Zahl an Abrufen, also gleich nach Erhalt einmal laden.

- Den Schlüssel nie ins Repository, in `docs/` oder in ein Skript legen. Am
  besten den Link im Browser öffnen.
- Im Paketfenster von Avesmaps „Paket laden“ wählen.
  - Serie: `modern` (ohne Beschriftung im Bild). Den Rest zeichnet die App selbst.
  - Größe: 16384 px; 32768 px nur, wenn z6 wirklich nötig ist, siehe unten.
- Das `paket.zip` **außerhalb** des Repositorys speichern, etwa in
  `~/Downloads`. Weder Paket noch Kacheln gehören ins öffentliche Repository.

### 2 · Kacheln schneiden

```bash
python -m pip install pillow            # einmalig; alternativ pyvips
python -I tool/avesmaps_karte_kacheln.py --paket ~/Downloads/paket.zip
```

Ergebnis unter `build/karten/` (`/build/` ist ignoriert):

- `aktuell.json`: Manifest, auf das die App zeigt.
- `<revision>/{z}/{x}/{y}.webp`: 512-px-Kacheln; `y` zählt von Norden.
- `<revision>/manifest.json`, `LIZENZ.txt`, `logo.<ext>`: Beigaben aus dem Paket.

Prüfen, bevor es weitergeht:

- Die Ausgabe nennt „1365 Kacheln (z0–5)“ bei 16384 px bzw. 5461 bei 32768 px.
- `aktuell.json` enthält `revision`, `maxZoom`, `nennung` und `lizenzUri`, dazu
  `logo`, wenn das Paket ein Logo hatte.
- `0/0/0.webp` öffnen: Das ist die ganze Karte, Norden oben.

Mögliche Fehler:

| Meldung | Ursache | Abhilfe |
| --- | --- | --- |
| „nicht eindeutig; bitte mit --bild wählen“ | Mehrere PNG im Paket | `--bild <name.png>` aus der genannten Liste. |
| „nicht quadratisch“ bzw. „keine Zweierpotenz“ | Andere Bildmaße als erwartet | Bei Avesmaps nachfragen oder das Werkzeug erweitern (auffüllen auf die nächste Zweierpotenz und die Einpassung im Manifest vermerken). |
| Speicherfehler bei 32768 px | Pillow lädt das ganze Bild | pyvips installieren (`pip install pyvips` samt libvips) oder `--max-zoom 5`. |
| Kein Logo im Manifest | Logo heißt im Paket anders | Dateinamen im ZIP prüfen; das Werkzeug sucht nach `logo` im Namen. |

### 3 · Erst auf einem Vorschaukanal testen

```bash
firebase hosting:channel:deploy karten-test --config firebase.karten.json
```

Der Befehl gibt eine HTTPS-Adresse für die Vorschau aus. Damit lokal starten (lokal
greift keine CSP, die Header der Karten-Site gelten aber):

```bash
flutter run -d chrome --web-port=5000 --dart-define=KARTEN_KACHELN=<Vorschau-URL>
```

Sichtprüfung:

- **Standort-Kachel:** Die Lageskizze zeigt das Kartenbild. In der Ecke stehen Logo,
  „Kartenmaterial © Ulisses Spiele · …“ und „Ortsdaten: Avesmaps“.
- **Vollbild über die Skizze:**
  - Zoom von ganz Aventurien bis z5 scharf, darüber vergrößert;
  - Kachelgrenzen ohne Haarrisse;
  - beim Zoomen zuerst grobe Platzhalter, dann scharf.
- **Mit avesmaps.de vergleichen** bei z2, z4 und z6:
  - Orte liegen auf den Siedlungen des Bilds;
  - Markengrößen, Namensgrößen und Saum passen.

  Abweichungen in `lib/ui2/karte/karto_karten_stil.dart` nachstellen.
- **Rechtliches → Lizenzen:** Der Eintrag „Aventurienkarte (Ulisses-Kartenpaket,
  Bearbeitung Avesmaps)“ erscheint, aber nur in Builds mit `KARTEN_KACHELN`.
- **Ohne Netz bzw. mit falscher Adresse:** Die Karte fällt auf Papier zurück, ohne
  Fehlermeldung.
- **Browser-DevTools:** keine CSP- oder CORS-Fehler für `heldensync-karten`.

### 4 · Live schalten

```bash
firebase deploy --config firebase.karten.json --only hosting
curl -sI https://heldensync-karten.web.app/aktuell.json   # Cache-Control: no-cache
curl -sI https://heldensync-karten.web.app/<revision>/0/0/0.webp
#   Cache-Control: … immutable, Access-Control-Allow-Origin: *
```

Danach die Adresse in die App-Builds eintragen und über den normalen Weg
(PR nach `test`, Abnahme, `main`) ausliefern:

- **`.github/workflows/flutter-tests.yml`:** im Web-Release-Build
  `--dart-define=KARTEN_KACHELN=https://heldensync-karten.web.app` zu den übrigen
  `--dart-define`s.
- **`tool/deploy_web.ps1`:** dieselbe Zeile für manuelle Deploys.

Dann die Doku nachziehen: in [reiseroute_plan.md](reiseroute_plan.md) C3 auf
„umgesetzt“ setzen, in [architecture_roadmap.md](architecture_roadmap.md) die
Reiseroute-Zeile anpassen und den Stand oben in dieser Datei aktualisieren.

## Später

- **Neue Kartenfassung bei Avesmaps:** Neues Paket über einen neuen Zugang laden und
  Schritt 2 bis 4 wiederholen; kein Codewechsel nötig.
  - Die neue Revision bekommt eigene Pfade, `aktuell.json` zeigt darauf.
  - Alte Revisionen in `build/karten/` liegen lassen, solange noch offene Sitzungen
    sie nutzen könnten; ein Deploy ersetzt die ganze Site.
- **Kosten:** Das Projekt läuft im Blaze-Tarif (wegen Cloud Functions). Hosting ist
  dort frei bis 10 GB Speicher und 360 MB Transfer am Tag, darüber kostet es 0,026 $ je GB
  Speicher und 0,15 $ je GB Transfer (Stand 11/2026).
  - Die Freigrenzen gelten für das ganze Projekt, also für die Karten-Site zusammen mit
    Test und Produktion.
  - Kacheln: geschätzt 70 MB bei 16384 px, rund 270 MB bei 32768 px.
  - Eine Sitzung lädt etwa 0,5 MB (Kachel) bis 5–10 MB (viel Zoomen im Vollbild);
    wiederkehrende Besuche kommen dank `immutable` aus dem Browser-Cache.
  - In der Konsole die Aufbewahrung alter Releases der Karten-Site begrenzen (etwa
    auf 2). Jedes behaltene Release zählt zum Speicher.
  - Nach dem Start die Nutzung beobachten. Optional ein Budget-Alarm in der Google
    Cloud Console.
- **Vektorlagen:** Das Paket kann auch SVG mit den Ebenen Wege, Gebiete und
  Landschaften enthalten. Das wäre eine spätere Option, etwa für Reichsgrenzen, und
  braucht dieselben Lizenzpflichten.
