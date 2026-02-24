Lege hier eine oder mehrere Heldendateien als `.json` ab.

Beim App-Start werden alle Dateien unter `assets/heroes/` mit Endung `.json`
automatisch eingelesen.

Unterstuetzte Formate:
- Export-Bundle (`kind: "dsa.hero.export"`) mit `hero` + `state`
- Direktes `HeroSheet`-JSON (State wird dann als leer angenommen)
