# Archiv — MAG-EFF und TRANK (Statustexte)

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

## MAG-EFF

- [ ] **MAG-EFF – Zauberwirkungen auf Charaktere im Kampf und Spielgeschehen integrieren.**
  Recherche und [Umsetzungsplan](../zaubereffekte_integrationsplan.md), Stand
  14.10.2026: Screening aller 288 Katalogzauber, priorisierte Wirkungen mit
  DSA-MCP-Belegen und sechs separat abnehmbare Arbeitspakete. Axxeleratus,
  Attributo, Armatrutz und die Fulminictus-Fremdgrundwirkung sind bereits
  vorhanden; der Ausbau beginnt mit Quellenprofilen und quellenbezogenen
  Effektinstanzen, danach Probenboni und empfangene Kampf-Mali.
  **Status: MAG-EFF-01 umgesetzt (14.10.2026) — Zauberprofile als
  `spell_effects.json` mit Validierung und Bestandsprotokoll, noch ohne
  Zahlenwirkung; MAG-EFF-02 im Kern umgesetzt (15.10.2026) — quellenbezogene
  `SpellEffectInstance`, Attributo als mehrere Quellen, Rest siehe
  Integrationsplan; MAG-EFF-03 teilweise umgesetzt (15.10.2026) — Blitz,
  Plumbumbarum, Adlerauge, Psychostabilis; Falkenauge und Ängste lindern
  (einmaliger Verbrauch) mit MAG-EFF-04 (teilweise) umgesetzt, Psychostabilis
  schlägt seine vorausbezahlte Dauer aus Zusatz-AsP vor; „laufende Kosten“
  entfallen (regelseitig nicht belegt, siehe Integrationsplan); offen sind
  die ereignisbasierten Profile (Ende-Gründe entfallen: Das Beenden eines
  Zaubers braucht keine Begründung, Entscheidung 16.10.2026);
  MAG-EFF-05 teilweise umgesetzt (15.10.2026) — Gardianum als Schutzvorrat,
  Heilung durch Balsam, Hexenspeichel und Lach dich gesund, Ruhe Körper als
  Schlafablauf; einfache Zauber Karnifilo und Seidenzunge;
  Duplicatus und Folgetick-Profile offen; MAG-EFF-06 geplant.** Befund: Armatrutz kennt die
  Regelgrenze ZfW/2 nicht, bei Axxeleratus fehlt nur die Athletik-Verdopplung
  für Sprints und Sprünge (Details im Integrationsplan).
  ARCH-04 liefert gemeinsame Herleitungen; ARCH-05/06 bilden die Grundlage
  für fachliche Schreibvorgänge und Speicherung, ARCH-07 begleitet Migration
  und Bedienprüfungen. MAG-EFF ist eine zusätzliche fachliche Aufgabe und
  ändert die Bedeutung der sieben ARCH-IDs nicht.

## TRANK

- [ ] **TRANK — Trankdefinitionen aus den Regelbüchern in einen Katalog übernehmen.**
  Angeregt am 15.10.2026 durch den Verbrauch von Gegenständen: Der Dialog
  „Anwenden“ (`VitalwirkungAnwenden`, `Vitalwirkung` am Inventareintrag,
  Schreibweg in `docs/schreibpfade_inventar.md`) kennt bisher nur eine vom
  Nutzer eingetragene Vorbelegung (LeP/AsP/AuP/Wunden). Ziel: die
  wichtigsten Tränke und Heilmittel mit ihren Regelwerten als Katalog
  (Split-JSON unter `assets/catalogs/house_rules_v1/`, geschützte
  Wirkungstexte wie bei Zaubern verschlüsselt) bereitstellen, damit Inventar,
  Kauf/Anlegen und Anwenden daraus vorbelegen, statt Werte frei zu tippen.
  Vorgehen: (1) Screening mit dem DSA-MCP – erste Fundstellen: *Wege der
  Alchimie* (2. Aufl. 2012; Rezepturen, Probe, Wirkung, z. B. S. 35–37),
  *Stäbe, Ringe, Dschinnenlampen* (Spagyrik S. 95, Wundpulver S. 108), *Wege
  der Zauberei* (Alchimie-Probe und Qualitätsstufen S. 62 f.), dazu die
  Hausregeln „Epische Stufen“ (Tränke brauen S. 29); Belege je Eintrag mit
  Buch und Seite, nichts ohne Beleg. (2) Auswahl der **wichtigsten**
  Definitionen (Heil-, Kraft- und Ausdauertränke, Gegengifte, Verbände und
  Wundpulver) – kein Vollimport aller Rezepturen. (3) Datenmodell: Name,
  Gruppe, Quelle, Wirkung je Qualitätsstufe (A–F) bzw. ausdrücklich
  gewürfelte Wirkung (Würfelausdruck als Vorschlag, wie bei `Vitalwirkung`),
  Wirkungsdauer, Preis/Gewicht, Haltbarkeit; nur additiv an
  `HeroInventoryEntry` anbinden (`jsonSchluessel`, Eintrag in
  `unbekannte_verschachtelte_felder_test.dart`, Hash-Pins beachten).
  (4) Anbindung: Katalogauswahl im Inventareditor füllt `vitalwirkung` vor;
  der Anwendungsdialog behält die Nutzerentscheidung (nichts wird geraten
  oder automatisch gebucht). (5) Abgrenzung: Brauen, Rezepturenerwerb und
  Labor sind **nicht** Teil dieses Pakets; Wirkungen über Zeit oder auf
  Eigenschaften folgen erst, wenn MAG-EFF-Instanzen (Dauer, Ende-Gründe)
  dafür wiederverwendbar sind. Offene Produktentscheidungen: Katalogpaket
  einzeln oder im Basiskatalog; Umgang mit Qualitätsstufen im Dialog;
  Hausregel-Abweichungen als eigenes Paket.

  **Status: Teilstand 1 umgesetzt (15.10.2026) — Katalog, Modell und
  Editoranbindung.** `assets/catalogs/house_rules_v1/alchimika.json`
  (Manifest-Schlüssel `alchimika`, `AlchimikumDef` in
  `lib/catalog/alchimikum_def.dart`, `RulesCatalog.alchimika`) enthält sechs
  Mittel mit Beleg (Buch, gedruckte Seite, Chunk-ID): Heiltrank, Pastillen
  gegen Erschöpfung, Restorarium, Schlaftrunk, Antidot (alle *Wege der
  Alchimie* 2012, S. 55–59) und Wundpulver (*Stäbe, Ringe, Dschinnenlampen*
  S. 107). Qualitätsstufen A–F mit Würfelausdruck (`2W6+4`), Wunden-Regel
  („je 7 LeP eine Wunde“, WdA S. 56, Basisregelwerk S. 197) und kurzer eigener
  Wirkungsbeschreibung. Im Inventareditor übernimmt „Aus Katalog: Tränke &
  Heilmittel“ (`alchimika_auswahl_dialog.dart`, Regeln in
  `rules/derived/alchimika_rules.dart`, `mitAlchimikum`) Name, Typ, Beschreibung,
  Richtpreis und die Vorbelegung; `Vitalwirkung` trägt dafür die neuen
  additiven Felder `lepWurf`/`aspWurf`/`aupWurf`/`lepProWunde`. Der Dialog
  „Anwenden“ zeigt den Wurf als Hinweis am Feld und die Wunden-Regel; gewürfelt
  und gebucht wird weiter nur, was der Nutzer eingibt. **Entscheidungen
  (Annahmen, bei Bedarf korrigieren):** Basiskatalog statt eigenem Paket;
  Qualität C vorgewählt (Preisangabe der Regelbücher), Stufe M nicht wählbar
  (Meisterentscheid); die Wirkungstexte sind kurze eigene Zusammenfassungen
  und **unverschlüsselt**, weil kein Buchtext kopiert wird (Verschlüsselung
  bräuchte das Katalogpasswort); kein Würfelknopf. **Offen:** Kraft-, Zauber-
  und Mut-Elixiere (Wirkung auf Eigenschaften, braucht MAG-EFF-Instanzen),
  Verbandszeug und Heilkräuter (Heilkunde-Probe, Zoo-Botanica), Hausregel-
  Abweichungen als Paket. (Eine eigene UI2-Katalogauswahl ist nicht nötig: Die
  Verwaltung beider Oberflächen nutzt denselben Inventareditor mit
  „Aus Katalog: Tränke & Heilmittel“; erst ein UI2-eigener Editor bräuchte sie.)

  **Teilstand 2 umgesetzt (16.10.2026) — Elixiere der Tugenden über
  MAG-EFF-Instanzen.** `alchimika.json` führt jetzt die acht Elixiere der
  Gruppe Virtutica (Mut, Klugheit, Intuition, Charisma, Fingerfertigkeit,
  Gewandtheit, Konstitution, Körperkraft; *Wege der Alchimie* 2012, S. 39–43,
  Chunks 2827–2834) mit je sechs Stufen. Eine Stufe trägt `eigenschaften`
  (Kürzel, Zahl, Dauer, Einheit; `AlchimikumEigenschaft`), **nur** wo das
  Regelwerk alle drei ausdrücklich nennt. Nachwirkungen nach Ablauf („am
  nächsten Tag …“), Gruppen („alle geistigen Eigenschaften“), AuP-Wirkungen,
  Talentabzüge und Nachteile stehen als Text mit dem Zusatz „nicht berechnet“.
  Am Inventareintrag merkt `HeroInventoryEntry.alchimikum`
  (`AlchimikumBezug`: ID, Stufe; nur bei Belegung) das Katalogmittel; die Werte
  bleiben im Katalog. „Anwenden“ im Inventareditor und im Gefechtsinventar
  öffnet bei einem Elixier den Dialog „Einnehmen“
  (`elixier_einnehmen_dialog.dart`); der Ablauf `ElixierEinnehmen` legt je
  Eigenschaftsänderung eine `SpellEffectInstance` (`effectId` = Katalog-ID des
  Mittels, `quelle` = „Qualität X“) mit eigener Dauer an, mit Protokolleintrag
  in einem Dokument. Gerechnet wird über `effektiveTempAttributeMods`: **Elixiere
  addieren sich** (das Regelwerk nennt keine Höchstwertregel; anders als beim
  Attributo). Dauern zählt der Nutzer wie bei Zaubern manuell herunter, nichts
  endet automatisch. Eine Dauer „halber Tag“ ist als 12 Stunden erfasst. **Offen:**
  Mutelixier-Brechreiz ohne Basiliskum, Kleptomanie und Mibelsucht (Nachteile
  auf Zeit), Mehrfachanwendung desselben Elixiers (Regelwerk-Meisterhinweise
  nur als Text), Zauberelixiere und Wandlungselixiere, Heilkräuter/Verbandszeug.
