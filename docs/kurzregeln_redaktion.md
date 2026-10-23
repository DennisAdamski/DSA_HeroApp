# Kurzregel-Kompendium (SPIEL-04, Option C)

Kleines, mitgeliefertes Nachschlagewerk aus **eigenen Kurzfassungen** häufiger
Spielregeln. Es läuft offline auf allen Plattformen (auch Mobil) und braucht
weder die Wissensbasis (`index.sqlite`) noch eine Netzverbindung. Es ergänzt
den Regel-Nachschlag ([spielmodus_konzept.md](spielmodus_konzept.md) 2.4) als
Reiter „Kurzregeln“ vor dem Reiter „Wissensbasis“. Der Einstieg erscheint wie
der übrige Regelnachschlag erst nach dem Entsperren der Katalog-Inhalte.

## Aufbau

| Baustein | Ort |
| --- | --- |
| Katalogdatei (Top-Level-Liste) | `assets/catalogs/house_rules_v1/kurzregeln.json` |
| Modell mit Quellenprüfung | `lib/catalog/kurzregel_def.dart` (`KurzregelDef.probleme`) |
| Lader und Entschlüsselung | `lib/catalog/kurzregel_loader.dart` (`ladeKurzregeln`, `parseKurzregeln`) |
| Suche (Umlaute egal, Titel vor Text) | `lib/rules/derived/kurzregel_suche_rules.dart` |
| Provider | `lib/state/kurzregel_providers.dart` (hängt nur am Katalogpasswort) |
| Oberfläche | `lib/ui/screens/workspace/kurzregeln_panel.dart`, Reiter in `rules_lookup_dialog.dart` (`RegelnNachschlagDialog`) |
| Prüfskript | `tool/check_kurzregeln.py` |

Die Regelrechnung der App liest kein Feld des Kompendiums. Es ist reiner
Nachschlagetext und hängt nicht am Heldenkatalog (`RulesCatalog`),
Hausregel-Paketen oder Regelprofilen.

## Eintragsformat

Klartext: `id` (eindeutig), `titel`, `thema` (`kampf`, `zustaende`, `wunden`,
`proben`, `fernkampf`, `reiten`, `umgebung`, `heilung`, `magie`),
`schlagworte`, `quellen`, `hausregel_quelle`.
Verschlüsselt (v3, `PROTECTED_FIELDS`): `kurztext`, `hinweise` (Liste),
`hausregel_text`.

- **Offizielle Regel und Hausregel sind getrennte Felder.** `kurztext` und
  `hinweise` beziehen sich auf DSA 4.1 (samt Errata); `hausregel_text` nennt
  nur die Abweichung durch Hausregeln, `hausregel_quelle` den Beleg. Die
  Oberfläche zeigt beides in getrennten Blöcken („Offizielle Regel (DSA 4.1)“
  und „Hausregel“).
- **Quellenpflicht.** `quellen` enthält je Beleg Buch und Seite
  (`<Buch>, S. <Seite>`). Der Lader verwirft Einträge ohne Beleg; der
  Katalogtest (`test/catalog/kurzregel_katalog_test.dart`) schlägt dann an und
  kennt nur die Buchnamen der Liste im Test (Tippfehlerschutz).
- **Gedruckte Seiten.** Der DSA-MCP liefert die PDF-Seite; sie liegt bei
  Basisregelwerk, Wege des Schwerts und Wege der Zauberei **um 1 über der
  gedruckten Seite** (belegt an Querverweisen wie „Orientieren, Seite 55“ oder
  „Spontane Modifikationen, Seite 18ff.“). Belegt wird mit der gedruckten
  Seite; bei einem neuen Buch den Versatz zuerst an einem Querverweis prüfen.
- **Eigene Worte, kurz.** Keine Abschriften; `check_kurzregeln.py` warnt ab
  700 Zeichen im Kurztext (nur im Klartextentwurf prüfbar).
- Ohne Passwort zeigt die Liste Titel, Thema und Beleg; die Texte bleiben
  gesperrt (kein Chiffretext in der Oberfläche).
- **Hausregeln.** Die Hausregel-Pakete unter
  `assets/catalogs/house_rules_v1/packs/` ändern nur Sonderfertigkeiten und
  Vor-/Nachteile, keine Kernregeln. Die Kern-Hausregeln (Wunden, Ausweichen,
  Kritische Treffer, Reiterkampf, Niederwerfen, Zauberreihenfolge) stehen im
  Hausregel-PDF „Erweiterung und Überarbeitung des Regelwerks“ (S. 2–4,
  18–21) und im Dokument „Zeit, Magie & Balancing“. Ideensammlungen ohne
  Beschluss (etwa „Mindestschaden“) wurden bewusst nicht aufgenommen.

## Redaktionsablauf (lokal, mit DSA-MCP und Passwort)

1. Eintrag mit `dsa-rules` (`search_rules`, `get_context`) recherchieren:
   Buch und gedruckte Seite notieren, nur DSA 4.1 und die Hausregeln
   abgleichen. Hausregel-PDFs mit `sources: ["hausregeln"]` durchsuchen.
2. Eintrag in eigenen Worten in `kurzregeln.json` ergänzen (Klartext).
3. `python tool/check_kurzregeln.py` – Quellenpflicht, Themen, Länge.
4. `python tool/encrypt_catalog_fields.py --format v3` (Passwort aus
   `docs/Passwort.env`, nie ausgeben oder committen). Bereits verschlüsselte
   Felder bleiben unberührt, nur neue Klartextfelder werden verschlüsselt.
5. `python tool/check_kurzregeln.py --require-encrypted` und
   `flutter test --no-pub --concurrency=1 test/catalog`.
6. Erst jetzt committen – nie die Klartextfassung (CLAUDE.md Regel 13).
   Klartextentwürfe gehören nicht ins Repo (am besten außerhalb ablegen).

## Stand (23.10.2026)

- 67 Einträge: Proben 5, Kampf 36 (Grundlagen, 19 Manöver, Glück und Patzer),
  Fernkampf 6, Magie 5, Zustände 4, Reiten 4, Wunden 3, Umgebung 2, Heilung 2.
- Quellen: Basisregelwerk, Wege des Schwerts, Wege der Zauberei, Errata WdS.
- Bewusst ohne Eintrag: **Furcht** (DSA 4.1 regelt sie nur über einzelne
  Zauber und Wesen, nicht als allgemeinen Zustand) und **Paralyse** (nur als
  Zauberwirkung). Betäubung, Schmerz, Erschöpfung und Kampfunfähigkeit sind
  enthalten.
- Nicht aufgenommen, weil selten am Tisch: Klingenwand, Windmühle, Formation,
  Waffe zerbrechen, Tod von Links, Schildspalter, Festnageln, Doppelangriff,
  Klingensturm, Trefferzonensystem, Waffenloser Kampf, Kälte- und Hitzeschaden,
  Krankheiten und Gifte.
- Ein Hinweis zum Fernkampf-Eintrag: Im Buch weichen Text und Tabelle bei den
  Zuschlägen für Schüsse ins Kampfgetümmel voneinander ab; der Eintrag folgt
  dem Text und nennt die Abweichung.
- Späterer Aktualisierungsweg über Firestore (Lesen für bestätigte Konten,
  Schreiben nur Betreiber, Regel in `firestore.rules`) ist bewusst nicht Teil
  dieses Pakets; das Asset bleibt die Offline-Basis.
