# Audit: Erweiterung und Ueberarbeitung des Regelwerks

Dieses Audit beschreibt den Umsetzungsstand des PDFs
`Erweiterung und Überarbeitung des Regelwerks.pdf` im Katalog
`house_rules_v1`.

## Status-Matrix

| Kapitel | Seiten | Status | Pack-ID | Hinweise |
|---|---|---|---|---|
| 1. Kleinere Hausregeln | 2-4 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | Viele Punktregeln ohne dediziertes Datenmodell oder Regelmodul. |
| 2.1 Allgemein | 5-9 | implementiert | `regelwerk_ueberarbeitung_v1.general_sf` | `Berufsgeheimnis Perpetuatoren` und `Furchtlos` als opt-in-Hausregeln im Katalog. |
| 2.2 Nahkampf | 10-12 | teilweise implementiert | `regelwerk_ueberarbeitung_v1.combat` | `Offensiver Distanzklassenwechsel`, `Offensiver Kampfstil`, `Seitenwechsel`, `Tierkampf`, `Zweihändiger Kampf I-III` umgesetzt; Seite 11 bleibt manuell nachzupruefen. |
| 2.3 Fernkampf | 14 | teilweise implementiert | `regelwerk_ueberarbeitung_v1.combat` | `Handmagazin`, `Häuserkämpfer`, `Nahkampfschütze`, `Pfeilhagel` umgesetzt; Seite 13 blieb in der Textextraktion leer. |
| 2.4 Magie | 15-16 | implementiert | `regelwerk_ueberarbeitung_v1.magic` | `Arkane Sensitivität I/II`, `Astralbrand`, `Überwältigende Zauberkraft`, `Zaubersänger` katalogisiert. `Ottogaldr` bleibt unmodelliert, weil nur referenziert. |
| 2.5 Geweiht | 16-17 | teilweise implementiert | `regelwerk_ueberarbeitung_v1.karmal` | `Göttlicher Begleiter` katalogisiert; `Göttlicher Zorn` ist ohne Liturgie-Katalog aktuell nicht modelliert. |
| 2.6 Empathie | 17-18 | implementiert | `regelwerk_ueberarbeitung_v1.general_sf` | `Gefühle Aufnehmen`, `Große Seelenheilung`, `Gefühle vermitteln`, `Nähe` katalogisiert. |
| 3. SF-Aenderungen | 18-20 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | `Niederwerfen` und `Reiterkampf` sind derzeit nicht als separate Regelmodule verdrahtet. |
| 4. V oraussetzungen zum spaeteren Erwerb von Vorteilen | 21 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | Kein Vorteilskauf-Modell im aktuellen Katalog/Rules-Layer. |
| 5. Koerperliche Talente | 22-23 | als Paket verschoben | `regelwerk_ueberarbeitung_v1.talents_learning` | Baseline auf `Wege der Helden.pdf` S. 316 zurueckgefuehrt; PDF-Abweichungen per Pack-Overlay. |
| 6. Lehrmeister | 24 | teilweise implementiert | `regelwerk_ueberarbeitung_v1.system` | 20-%-Rabatt und Dukatenformel existieren bereits in `learn_rules.dart`, sind aber noch kein paketgeschaltetes Regelmodul. |
| 7. Spezialisten | 24 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | Kein separates Talent-Spezialistenmodell vorhanden. |
| 8. Liturgiekenntnis & Karmalquesten | 25 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | Keine gottspezifische Liturgiekenntnis-/Karmalquestenlogik im Rules-Layer. |
| 9. Mittellaender+ | 25-26 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | Keine Rassenvariante oder Vorteilskombinatorik dafuer modelliert. |
| 10. Runen & Zauberzeichen | 27-29 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | Kein Runen-/Zauberzeichen-Katalog mit passender Laufzeitlogik vorhanden. `Infinitum-Runen` bleiben bei `epic_rules_v1.magic_sf`. |
| 11. Investitionen | 30 | nicht modelliert | `regelwerk_ueberarbeitung_v1.economy` | Keine Wirtschafts-/Investitionslogik im Projekt. |
| 12. Auswirkungen magischer Modifikationen | 31 | nicht modelliert | `regelwerk_ueberarbeitung_v1.system` | Reine Auslegungsregeln ohne bestehendes Modell. |

## Baseline- und Overlay-Strategie

- Betroffener Bereich: nur `Körperliche Talente` in `assets/catalogs/house_rules_v1/talente.json`
- Offizielle Baseline: `Wege der Helden.pdf`, S. 316 (`Körperliche Talente` alle Spalte `D`)
- Overlay-Pack: `regelwerk_ueberarbeitung_v1.talents_learning`
- Hausregel-Abweichungen per Patch:
  - `Akrobatik -> A*`
  - `Athletik -> C`
  - `Gaukeleien -> C`
  - `Schleichen -> C`
  - `Sich Verstecken -> C`
  - `Skifahren -> B`
  - `Singen -> C`
  - `Stimmen Imitieren -> C`
  - `Tanzen -> B`
  - `Taschendiebstahl -> C`
  - `Zechen -> B`

## Querverweise und bewusste Nicht-Uebernahmen

- `Rittmeister` bleibt bei `epic_rules_v1.combat_sf`, weil die definierende Quelle `Epische Stufen.pdf` ist und das Regelwerks-PDF nur darauf verweist.
- `Infinitum-Runen` bleiben bei `epic_rules_v1.magic_sf` aus demselben Grund.
- `Ottogaldr` wurde nicht katalogisiert, weil das PDF nur auf die zugehoerige SF verweist und keine eigenstaendige Regeldefinition liefert.

## Offene Audit-Hinweise

- PDF-Seite 11 und PDF-Seite 13 waren in der Textextraktion leer und muessen fuer einen vollstaendigen Audit manuell oder per Zweitworkflow verifiziert werden.
- `Nähe` ist anhand der extrahierbaren Textstelle katalogisiert; der Fließtext im PDF endet vor der eigentlichen Wirkungsbeschreibung abrupt.
