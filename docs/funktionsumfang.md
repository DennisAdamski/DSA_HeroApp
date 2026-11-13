# Funktionsumfang im Detail

Ausführliche Beschreibung der Funktionen, die bis November 2026 in der
[README](../README.md) standen. Die README fasst sie nur noch zusammen; neue
Detailbeschreibungen gehören in diese Datei oder in den passenden Fachplan.

## Heldenverwaltung

- Anlegen neuer Helden mit Roh-Startwerten fuer die acht DSA-Eigenschaften
- Persistenz aller Heldendaten inklusive Schema-Versionierung
- Separate Speicherung des Laufzeitzustands wie aktuelle LeP, AsP, KaP und Ausdauer
- Seed-Import von Beispielhelden aus `assets/heroes/`
- Optionaler eigener Heldenspeicherordner auf Windows, macOS und Linux
- Die Startseite merkt sich den zuletzt ausgewaehlten Helden und zeigt ihn
  direkt wieder in der Vorschau an

## Speicherung

- App-Einstellungen liegen immer lokal in einem separaten App-Ordner unter
  `Application Support` bzw. auf Windows in `AppData`
- Heldendaten nutzen standardmaessig einen eigenen Unterordner und koennen auf
  Desktop-Plattformen auf einen frei gewaehlten Ordner umgestellt werden
- Ein optionaler Konto-Login ist auf allen Plattformen verfuegbar. Ohne Login
  arbeitet die App weiter im lokalen Offline-Profil; mit Login nutzt sie ein
  getrenntes lokales Konto-Profil unter `Helden/accounts/<uid>` und spiegelt
  Helden sowie Laufzeitzustaende nach Firestore.
- Der Settings-Bereich `Konto & Sync` zeigt Loginstatus, letzten erfolgreichen
  Sync, offene Konflikte und einen manuellen Sync-Button. Bei Unterschieden
  zwischen Offline- und Konto-Daten entscheidet der Nutzer zwischen lokal,
  online oder beide behalten.
  Bei Offline-Helden erklärt der Vergleich, dass „Nur Lokal“ den Konto-Stand
  durch den Offline-Stand ersetzt oder einen fehlenden Konto-Held übernimmt.
  Speicherzeitpunkte erscheinen nur, wenn beide Seiten einen besitzen.
- Auf Windows nutzt der Konto-Sync bewusst die Firestore REST API statt des
  nativen `cloud_firestore`-Pluginpfads. Firebase Auth liefert dafür das
  ID-Token; Firestore Security Rules schützen die gleichen User-Dokumente.
- Auf Web-Zielplattformen liegen Einstellungen und Heldendaten stattdessen im
  browserlokalen Speicher; die UI zeigt dafuer den logischen Pfad
  `Browser-Speicher/...` an
- Custom-Kataloge werden im aktiven Heldenspeicher unter
  `custom_catalogs/<katalogversion>/<sektion>/<id>.json` gespeichert und
  koennen dadurch ueber einen synchronisierten Cloud-Ordner mitlaufen
- Ein ungueltiger benutzerdefinierter Heldenspeicherpfad fuehrt zu einem
  klaren Fehlerzustand statt zu einem stillen Fallback
- Standardpfade liegen direkt unter dem app-spezifischen Support-Ordner, also
  z. B. `.../DSA Heldenverwaltung/Einstellungen` und
  `.../DSA Heldenverwaltung/Helden`

## Uebersicht und Stammdaten

- **Bearbeiten** korrigiert Werte manuell ohne automatische AP-Buchung.
- **Steigern** öffnet eine eigene, heldenweite Steigerungsrunde. Geplante
  Änderungen werden erst mit **Änderungen übernehmen** gemeinsam wirksam.
  Der Inspektor zeigt AP-Reservierungen und die Historie. Einträge der laufenden
  Runde sind einzeln entfernbar, übernommene Einträge bleiben fest. Werden durch
  Entfernen Folgeeinträge ungültig, müssen diese vor der Übernahme korrigiert
  werden. Auf kleinen Bildschirmen ist die Historie im **Detailpanel** erreichbar.
- Eigenschaften, Talente und Zauber erscheinen als kompakte Kacheln. Auf breiten
  Fenstern stehen die Basiswerte neben den Eigenschaften und die AP-Bilanz
  rechts über dem Verlauf. Talente bieten zusätzlich **+ Spezialisierung**:
  der Erwerb nutzt die Vorschau und reserviert AP, bis die Runde übernommen wird.
  Zauberkacheln bieten ausschließlich Wertsteigerungen.
- Für Talente, Sprachen, Schriften und Zauber zeigt der Steigerungskatalog nur Einträge, die der Held bereits auf dem Bogen
  führt — auch solche, die eingeblendet, aber noch nicht aktiviert sind. Alles
  Weitere kommt je Kategorie über **Talent, Sprache oder Schrift erlernen**,
  **Zauber erlernen** bzw. **Sonderfertigkeit erwerben** aus einem
  durchsuchbaren Erwerbsblatt. Die Auswahl führt direkt in den
  Steigerungsdialog: Aktivieren und Steigern sind ein Schritt, der Zielwert ist
  frei wählbar und die Aktivierungskosten sind enthalten. Sucht man in der
  Hauptliste ins Leere, führt ein Hinweis mit demselben Suchtext ins Erwerbsblatt.
- Bei **Sonderfertigkeiten** zeigt ein Fähigkeitenbaum Sonderfertigkeiten und
  Manöver mit ihren Voraussetzungen, einschließlich UND-/ODER-Verknüpfungen.
  Filter trennen Kampf, Allgemein, Magie und Karma; die Suche erhält zugehörige
  Vorstufen. Knoten zeigen Erwerbsstatus und AP-Kosten und öffnen Details zum
  Vormerken. Getrennt lernbare Manöver werden pro passendem Kampftalent erworben.
  Die geöffneten Details zeigen außerdem die verfügbaren Beschreibungen und
  Regeltexte, Originalvoraussetzungen, Variantenkosten, Kampfboni und Quellen.
  Geschützte Texte nutzen die Katalogfreischaltung aus den Einstellungen.
- Magische und karmale Sonderfertigkeiten werden in Auswahl und Fähigkeitenbaum
  ohne passende Befähigung standardmäßig ausgeblendet. **Unpassende
  Sonderfertigkeiten anzeigen** überschreibt dies dauerhaft je Held. Bereits
  erworbene oder vorgemerkte Fähigkeiten bleiben sichtbar; fehlende Vorstufen,
  Eigenschaften oder AP blenden zukünftige Ziele nicht aus. Der Schalter ändert
  keine Erwerbsvoraussetzungen und erhält laufende Steigerungsentwürfe.
- Unter **Eigenschaften** zeigt die Basiswerte-Karte die Summen vor der Runde
  und nach den vorgemerkten Änderungen. Der Eigenschaftsdialog zeigt live die
  zusätzliche Wirkung des Zielwerts sowie bisher begrenzte Talente, Kampftalente
  und Zauber, die dadurch weiter steigerbar werden. Diese Auskunft beschreibt
  den regeltechnischen Spielraum unabhängig von den noch verfügbaren AP.

- Pflege von Name, Rasse, Kultur, Profession und Biografiedaten
- Verwaltung von AP, Stufe, Ressourcen und textbasierten Modifikatoren
- Katalogbasierte Auswahl von Vorteilen und Nachteilen in der Übersicht;
  gespeichert wird weiterhin kompatibel in den Textfeldern des Helden
- Berechnung effektiver Startwerte und Eigenschaftsmaxima
- Gefuehrte AP-Steigerung fuer Eigenschaften und kaufbare Grundwerte
- Abenteuer-Sondererfahrungen fuer Eigenschaften und Grundwerte werden direkt in den Steigerungsdialogen angezeigt und beim Steigern verbraucht
- Parsing von Modifikator-Texten aus Vor-/Nachteilen sowie R/K/P-Feldern,
  inklusive Standardnamen wie Hohe Lebenskraft, Astralmacht oder Kurzatmig

## Talente und Sprachen

- Verwaltung allgemeiner Talente, Kampftalente und Meta-Talente
- Validierung von AT/PA-Aufteilungen bei Kampftalenten
- Unterstuetzung fuer Talentspezialisierungen, Sondererfahrungen, Begabungen und strukturierte Talent-Sonderfertigkeiten
- Steigerungsdialog fuer Talente mit Live-AP-Kosten, SE-Verbrauch, manueller Komplexitaetskorrektur und Lehrmeister-Rabatt
- AP-Steigerung für Kampftalente im eigenen Steigerungsmodus
- Eigener Bereich fuer Sprachen und Schriften auf Basis von Katalogdaten

## Kampf

- Im Bereich Spielen startet „Gefecht beginnen“ eine flüchtige Sitzung je Held;
  die bisherige Kampfverwaltung bleibt erreichbar. Navigation erhält die Sitzung,
  Beenden oder ein App-Neustart verwirft sie.
- Die Gefechtsansicht führt Runden, INI, Umwandlung, Haltung, DK und getrennte
  Aktionsmarken. „Prüfen“ verlangt eine Bestätigung; erkannte Sperren bleiben
  verbindlich. Ausrüstung wechselt im eigenen Popup, längere Ziehhandlungen
  werden erst nach Abschluss wirksam.
- Proben, Ressourcen, Wunden und Effekte verwenden die bisherigen Fachwege.
  Meisterparade erfragt eine eigene Ansage und erleichtert bei Erfolg einmalig
  die nächste Angriffs-/Abwehraktion. Misslungene unterstützte Nahkampf-Ansagen
  setzen einen sichtbaren Folgemalus bis einschließlich nächster AT/PA oder
  Orientieren. Gegnerische Trefferfolgen bleiben manuell. Bei positiver
  Schildansage wird die am Tisch geklärte Grenze erfragt.
  Optionales Zielen baut bis zu vier Punkte anderer Fernkampfzuschläge ab und
  bezahlt dafür reguläre Aktionen; Ansage und Gezielter Schuss bleiben unverändert.
  [Umfang und Prüfungen der ersten Version](docs/gefecht_implementation.md)
  dokumentieren die verbleibenden manuellen Regeln.

- Pflege von Nah- und Fernkampfwaffen in einer gemeinsamen Kampfkonfiguration
- Unterstuetzung fuer Nebenhand, Parierwaffen, Schilde und Ruestungen
- Kampfvorschau mit AT, PA, TP, INI, Ladezeit, Distanzstufen und Geschossen
- Aktionskarte fuer beidhändigen Kampf mit Falsche-Hand-Mali, Doppelangriff und Zusatzaktionen aus Beidhändigem Kampf beziehungsweise Parierwaffen
- Verwaltung aktiver Manoever und katalogbasierter Kampf-Sonderfertigkeiten
- Kampf-Sonderfertigkeiten und Manöver bleiben als getrennte Katalogquellen modelliert; die Kampf-UI filtert Doppelungen anhand der Manöver-Namen aus
- Waffenmeister-Baukasten mit Voraussetzungen, Boni und Vorschau der Wirkung
- Beruecksichtigung waffenloser Kampfstile und freigeschalteter Manoever

## Magie

- Verwaltung gelernter Zauber inklusive Repruesentation, Tradition und Begabung
- Automatische Aktivierung des Magie-Bereichs ueber AE/AsP-Modifikatoren aus
  Rasse, Kultur, Profession oder Vorteilen mit optionalem manuellem Override
- Globale Leiteigenschaft fuer magische Regeneration im Magie-Bereich
- Anzeige von Verfuegbarkeit, Lernkomplexitaet und heldenspezifischen Anpassungen
- Steigerungsdialog fuer Zauber mit Fremdrepr.-, Hauszauber-, manueller Komplexitaetskorrektur und Lehrmeisterlogik
- Eigener Ritual-Bereich mit Ritualkategorien, Ritualkenntnissen und Ritualen
- Pflege magischer Sonderfertigkeiten mit Beschreibung und aktiver Zaubereffekte
- Laufende Zaubereffekte (Axxeleratus, Attributo, Armatrutz) mit optionaler
  Wirkungsdauer in Kampfrunden, Spielrunden oder laengeren Zeiteinheiten samt
  manuellem Countdown; der Armatrutz addiert seinen erzauberten RS zur
  getragenen Ruestung, ohne Behinderung zu erzeugen

## Workspace und Regeneration

- Vitalwerte enthalten neben LeP, Au, AsP und KaP auch Erschoepfung und Ueberanstrengung mit direkter manueller Anpassung
- Rast-Aktion als Lagerfeuer-Symbol oben rechts in den Vitalwerten fuer Ausruhen, Schlafphase und Bettruhe
- Strukturierte Regenerationslogik fuer LeP, Au und AsP inklusive KO-/IN-Proben und Umweltmodifikatoren
- Dauerhafte Verwaltung von Erschoepfung und Ueberanstrengung im `HeroState`
- Optionaler Fullrestore fuer lange Abwesenheiten: alle Vitalwerte auf Maximum und keine Wunden mehr
- Vorschau und Sammeluebernahme der Rast-Ergebnisse direkt im Workspace
- „Schaden erhalten“ in den Vitalwerten und als Schnellaktion der Spielansicht: TP abzueglich RS, Trefferzone per Auswahl oder W20, Wundvorschlag aus den Wundschwellen samt Angriffsmodifikator (die Wundzahl entscheidet der Nutzer), Zusatzwuerfe der Zone, Ausdauerschaden (TP(A)) und ein nachvollziehbarer Protokolleintrag
- Wunden wirken nach Gesamt- und Zonensystem (Hausregel, WdS S. 58 und
  108 f.): allgemeine Abzuege plus die Zone, Armwunden nur auf die Waffe
  in diesem Arm (Schwert- bzw. Schildarm, Linkshaender beruecksichtigt),
  Eigenschaftsverluste nur auf Proben; Hinweise zu dritten Wunden und
  zum Kopf-INI-Wurf
- Tablet-Layouts fuer iPad und breite Fenster: Icon-Rail im Portrait, permanenter Inspector im Landscape und ein kompakter zweizeiliger Workspace-Header mit aktivem Bereich, Bildausschnitt und Kernwerten
- Proben-Schnellsuche in der Workspace-AppBar: durchsucht Eigenschaften, Kampfwerte, Talente und Zauber des Helden und oeffnet direkt den Probendialog inklusive Wuerfelprotokoll
- Wuerfelprotokoll mit Filter-Chips nach Probeart (Eigenschaft, Talent, Zauber, Kampf) und sessiontauglichem Umfang von 50 Eintraegen
- Regel-Nachschlag mit Reiter "Kurzregeln": mitgeliefertes, offline und auf allen Plattformen nutzbares Kompendium aus eigenen Kurzfassungen (Buch- und Seitenbeleg je Eintrag, Hausregeln getrennt, verschluesselt; `docs/kurzregeln_redaktion.md`)
- Regel-Nachschlag auf Desktop und Web: FTS5-Volltextsuche read-only auf der Index-Datenbank des dsa-rules MCP-Servers mit waehlbaren Quellkategorien; Desktop liest sie vom lokalen Standardpfad, Web nutzt sqlite3-WASM/IndexedDB nach einmaligem Datei-Upload der `index.sqlite` (Konzept in `docs/spielmodus_konzept.md`)

## Inventar, Chroniken, Kontakte und Abenteuer

- Direkt bearbeitbares Inventar als kompakte Tabelle fuer Ausruestung und sonstige Gegenstaende inklusive magischer und geweihter Markierungen
- Dukatenstand im Inventar mit direkter Eingabe sowie +/- Schritten fuer Dukaten, Silbertaler und Kreuzer
- Freie Chroniken mit Titel und Beschreibung
- Verbindungen/Kontakte mit Ort, Sozialstatus, Loyalitaet, Beschreibung und optionaler Abenteuer-Zuordnung
- Abenteuer als Chip-Uebersicht mit fokussierter Detailansicht; neue Abenteuer, Notizen und Personen werden jeweils ueber Popups angelegt oder bearbeitet
- Abenteuer pflegen Status (`Aktuell` oder `Abgeschlossen`), weltliche und aventurische Start-/Enddaten, ein aktuelles aventurisches Datum, abenteuerbezogene Notizen und Personen direkt in der Detailansicht
- AP-Belohnung, fest zugeordnete Sondererfahrungen, Dukaten und Abschluss-Beute werden gesammelt im gefuehrten `Abschliessen`-Dialog gepflegt und anschliessend atomar in AP, SE-Pools, Dukatenstand und Inventar uebernommen
- Ein Abschluss kann fachlich sicher wieder zurueckgenommen werden; Abenteuer-Beute bleibt dabei bewusst vom Kampf-Inventar entkoppelt

## Datenimport und Kataloge

- Import und Export kompletter Helden als JSON-Bundle
- Gruppen-Snapshots und Firestore-Sync uebertragen Avatarbilder nur als
  kompakte, quadratische Vorschaubilder um das erkannte Gesicht; wenn kein
  kleines Thumbnail erzeugt werden kann, erscheint auf anderen Geraeten
  stattdessen der Platzhalter
- Beschnittene Avatarflaechen (Heldenmarke, Album, Workspace-Header) richten
  sich automatisch am Gesicht aus. Die Erkennung (BlazeFace, Apache 2.0)
  rechnet in reinem Dart auf dem Geraet, auch im Web. Neue Bilder tragen
  das Ergebnis am Galerieeintrag und synchronisieren es mit; ein manueller
  Header-Ausschnitt hat weiterhin Vorrang
- Konto-Sync fuer Helden speichert Avatar-Dateien selbst noch nicht remote.
  Bildreferenzen bleiben erhalten; fehlende lokale Dateien werden in der UI
  wie bisher als Platzhalter behandelt.
- Konfliktbehandlung beim Import vorhandener Helden
- Katalogdaten aus `assets/catalogs/house_rules_v1/`
- `vorteile.json` und `nachteile.json` katalogisieren die WdH-Uebersichten
  sowie paketgesteuerte Hausregel-Ergaenzungen mit Kosten-, Marker- und
  Quellenmetadaten, aber ohne wörtliche Langregeltexte
- Katalogeintraege koennen strukturierte Herkunfts- und Freischaltmetadaten
  (`ruleMeta`) fuer offizielle Regeln, Hausregeln, Quellbelege und epische
  Opt-in-Inhalte tragen
- Epische Helden waehlen je eine geistige und eine koerperliche
  Haupteigenschaft; diese beiden steigern sich ohne den epischen
  AP-Aufschlag und sind ueber `AP und Level > Stern-Symbol` nachtraeglich
  korrigierbar
- Von den Haupteigenschafts-Boni rechnet die App die eBE-Halbierung bei
  KK-Talenten und bei KO die halbierte SB-Erschwernis beim Unterdruecken
  von Wunden (die halbierte Erschoepfung erscheint als Hinweis); die
  IN-Finte erscheint als Hinweis in der Kampfvorschau. Alle uebrigen Boni
  sind in der Heldenuebersicht ausdruecklich als `manuell` gekennzeichnet
- Breite Datenlisten lassen sich unter `Einstellungen > Darstellung` sowie im
  Kopf des Talente-Tabs zwischen automatischer, Tabellen- und Kartenansicht
  umschalten
- Textlastige Spalten der Haupttabellen lassen sich am rechten Rand ihres
  Tabellenkopfs verbreitern; die Breiten werden geraeteweit gespeichert und
  koennen je Tabelle zurueckgesetzt werden
- Hausregeln werden als global aktivierbare Paket-Manifeste geladen; eingebaute
  Pakete liegen unter `assets/catalogs/house_rules_v1/packs/`, importierte
  Pakete im Heldenspeicher unter `house_rule_packs/<version>/<packId>/`
- Eingebaute Pack-Manifeste muessen zusaetzlich explizit in `pubspec.yaml`
  als Flutter-Assets eingetragen sein, damit sie in den Einstellungen
  waehlbar werden
- Importierte Hausregel-Pakete koennen direkt in
  `Einstellungen > Hausregeln > Hausregelverwaltung oeffnen` angelegt,
  bearbeitet, importiert, exportiert und geloescht werden
- Der In-App-Editor bietet eine strukturierte Patch-Oberflaeche plus
  einen JSON-Tab fuer das vollstaendige Manifest; eingebaute Pakete bleiben
  schreibgeschuetzt und koennen nur als Vorlage geklont werden
- Settings-Bereich `Katalogverwaltung` zum Einsehen aller Basisdaten sowie zum
  Anlegen, Bearbeiten und Loeschen synchronisierbarer Custom-Eintraege
- Der Settings-Bereich nutzt adaptive Unterseiten: auf schmalen Layouts als
  Drilldown-Navigation, ab Tablet-Landscape mit linker Bereichsliste und
  rechter Detailansicht
- Settings-Bereich `Rechtliches` fuer Autor-, Fanprojekt-, Marken- und
  Rechtehinweise zu DSA und Ulisses Spiele
- Hero-Exporte koennen benoetigte Custom-Katalogeintraege mitsenden, damit
  referenzierte Hausregeln beim Import direkt wieder aufloesbar sind
- Reisebericht-Daten liegen bewusst separat unter
  `assets/catalogs/reiseberichte/house_rules_v1/` und gehoeren nicht zur
  editierbaren Settings-Katalogverwaltung
- Aufbereitung der Runtime-Kataloge aus Excel-Quellen ueber Skripte in `tool/`

## Entwicklungsplanung

Eine offene Entwicklungsplanung bleibt beim Wechsel zu **Held verwalten**
erhalten. Die Verwaltung ist zum Ansehen zugänglich. Vor einer Bearbeitung
erscheint die Warnung, dass die geplante Entwicklung verloren geht:
**Abbrechen** erhält den Plan, **Planung verwerfen und bearbeiten** verwirft
ihn und ermöglicht die Änderung. Geplante Steigerungen werden dabei nicht
übernommen. Das gilt auch für direkte Aktionen wie das Hinzufügen eines
Inventargegenstands; eine laufende Planübernahme bleibt geschützt.

Im Magiebereich der Entwicklungsplanung lassen sich **Repräsentationen** erwerben
und **Ritualkenntnisse** aktivieren oder steigern. Kosten, Voraussetzungen und
bestätigte Meisterentscheide gehören zur Planung; gespeichert wird erst beim
Übernehmen der Runde. **Magische Tradition einrichten** ergänzt im Magie-Editor
enthaltene oder bereits vorhandene Kenntnisse ohne zusätzliche AP. Derselbe
Dialog wird beim Erfassen von Voll-/Halbzauberer angeboten.
Eine gemeinsame Ritualkenntnis je Tradition kann mehrere Ritualgruppen versorgen.
Alte eigene Werte werden erst nach ausdrücklicher Auswahl angebunden.
Details und Abgrenzungen: [Magische Kenntnisse](docs/magische_kenntnisse.md).

## Gefecht im Detail

Die Gefechtsansicht führt Orientieren, Gegner-/Distanzkontext, Ziehen und
bestätigte Zauber-/Karmahandlungen über gemeinsame Regelprüfungen. Laufende
Gefechte bleiben flüchtig; Ressourcen und unterstützte Folgen werden über
bestehende frische Schreibwege übernommen. Regelquellen und manuelle Grenzen:
[Gefechtsausbau](docs/gefecht_next_plan.md), [Implementierung](docs/gefecht_implementation.md).

Manöver lassen sich nach Angriff, Verteidigung oder Sonstige, Lernstand und
bekannten Sperren filtern. Finte, Wuchtschlag und Fernkampfansage haben getrennte
Eingaben; ohne die ersten beiden SF wirkt die aufgerundete halbe Ansage.
Tastaturfokus und Cursor bleiben auch bei wechselnden Hinweisen erhalten.
Unterstützte Schadenangriffe bieten einen eigenen, waffengebundenen Schadenswurf.
FK-Schaden verwendet das Band der eingegebenen Schussentfernung; lässt es sich
nicht bestimmen, muss der TP-Distanzanteil am Tisch geklärt werden.
Entwaffnen und Umreißen erzeugen keinen Schaden; ungeklärte Varianten verlangen
eine manuelle Abwicklung ohne vorgegebenen Waffenschaden. Jede Angriffsfolge wird
einzeln abgeschlossen. „Schaden würfeln“ bleibt eine allgemeine Probe. FK-Ansagen verlangen bezahlte
zusätzliche Zielzeit: „Zusatz-Zielen beginnen“ und „Fortsetzen“ bezahlen reguläre
Aktionen über Runden, danach führt „Schuss ausführen“ den gehaltenen Auftrag aus.
Optionales Zielen wird mit „Zielen beginnen“ auf demselben Weg bezahlt und baut
bis zu vier Punkte anderer Zuschläge ab; FK-Ansage und Gezielter Schuss bleiben.
Aktuelle DK und Sitzungskontext bleiben beim Schuss und bei Probeabbruch erhalten.
„Laden / Vorbereiten“ erfragt einen unbekannten Anfang pro geführter Fernkampfwaffe.
Nach einem Profilwechsel kann der unbekannte Ladezustand auch im Schussdialog
frisch bestätigt werden. Eine passend bekannte ungeladene Waffe bleibt gesperrt.
Bezahlte Ladezeit bleibt bei geänderter Dauer erhalten; Waffen- oder Geschosswechsel
übertragen keinen Fortschritt. Munition wird einmal beim ausgeführten Schuss
übernommen. Ein Speicherfehler bietet Übernahme-Retry ohne erneuten Wurf.
Kampfgespür erlaubt spontane Umwandlung unter Erhalt aller verbrauchten Marken.

Ausführbare Aktionen benötigen konkrete Angaben
und gegebenenfalls einzelne manuelle Entscheidungen; Regelhinweise allein
sperren keine Probe. Freie Zusatzwerte starten bei 0, feste Katalogzuschläge
werden getrennt einmal angewendet. Eine später geleerte oder ungültige
FK-Zahleingabe bleibt offen, auch nach Waffenwechsel. Distanzklassen stehen
mit vollständigem Namen in Rundenleiste und Aktionsdialog.
„Distanzklasse ändern“ öffnet einen eigenen Dialog für Annäherung/Entfernung
um eine oder zwei Klassen, mit Finte, ohne Schaden und mit AT plus freiem Schritt.
Der normale Angriff enthält keine DK-Wechselwahl.

Im Gefecht sind Haupt- und Nebenhand ausdrücklich wählbar; Ziehen und
Wegstecken wirken erst nach ihrer bestätigten Dauer.
Bogen und gewöhnliche Armbrust belegen auch bei alten einhändigen Standardwerten
beide Hände. Die Waffenart Balestrina bleibt einhändig; Wurfwaffen behalten ihre
Metadaten. Unzulässige Nebenhandbelegungen sperren auch Zusatzaktionen.
