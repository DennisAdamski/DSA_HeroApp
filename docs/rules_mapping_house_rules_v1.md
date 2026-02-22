# House Rules v1 Mapping (DSA Excel)

Quelle: `Charaktersheet_DSA_mit_Hausregeln Hexe.xlsx`

## Implementierte Kernwerte

- LeP Max
  - Sheet: `Eigenschaften`
  - Excel-Hinweis: Formelbereich um `O20/P20`
  - App: `baseLeP = CEIL((KO + KO + KK) / 2)`, dann `+ mods.lep + bought.lep + min(level,21)`

- Au Max
  - Sheet: `Eigenschaften`
  - Excel-Hinweis: Formelbereich um `O21/P21`
  - App: `baseAu = CEIL((MU + KO + GE) / 2)`, dann `+ mods.au + bought.au + 2 * min(level,21)`

- AsP Max
  - Sheet: `Eigenschaften`
  - Excel-Hinweis: Formelbereich um `P22`
  - App: `baseAsp = CEIL((MU + IN + CH) / 2)`, dann `+ mods.asp + bought.asp + 2 * min(level,21)`

- KaP Max
  - Sheet: noch nicht eindeutig gemappt
  - App MVP: deterministischer Platzhalter `max(0, mods.kap + bought.kap)`

- MR
  - Sheet: `Eigenschaften` (MR-Berechnungsblock)
  - App: `baseMr = ROUND((MU + KL + KO) / 5)`, dann `+ mods.mr + bought.mr + ROUND(min(level,21) / 3)`

- Ini-Basis
  - Sheet: `Nahkampf`/`Rechner`-Bezug, Kernformel analog im Attributsatz
  - App: `CEIL((MU + MU + IN + GE) / 5) + mods.iniBase`

- GS, Ausweichen
  - MVP als Platzhalter mit Modifikator-Additionen (`base=0`) bis exakte Zellzuordnung fertig ist.

## Rundungsregeln

- Alle Formeln nutzen Dart-`ceil()`/`round()` entsprechend der aktuell gemappten Excel-Formeln.
- Negative Endwerte werden auf `0` geklemmt, wo es sich um Ressourcen-Maxima handelt.

## Wichtige Hinweise

- Farbmarkierungen (`B4C6E7`, `E7E6E6`) werden nicht allein fuer die Logik genutzt.
- Zellen werden explizit pro Formelbereich gemappt.
