# Paket 3: gemeinsame lokale Initiative — Entwurf zur Prüfung

Stand: 5. Oktober 2026. Architekturentwurf, noch keine Implementierung.
Der Nutzerauftrag verlangt die Gefechtsthemen nacheinander mit eigenen Commits.
Dieses Paket koordiniert Zeitpunkte und Runden bestehender flüchtiger Heldensitzungen.

## Zweck und Umfang

Eine gemeinsame Ansicht zeigt, wer in welcher INI-Phase handeln kann. Eigene
Helden werden ausdrücklich hinzugefügt; Gegner bekommen manuell Namen und INI.
Vorgeschlagene Grenze: eine aktive lokale Gruppe im aktuellen App-Prozess,
keine Cloud-Synchronisation, Speicherung, Gegnerressourcen oder Gegner-Regelengine.
Einzelgefechte ohne Gruppenmitgliedschaft behalten ihren bisherigen Ablauf.
Diese Teilnehmerwahl und der geringe Gegnerumfang sind Annahmen zur Nutzerprüfung.

## Quellen und fachliche Entscheidungen

WdS Chunks 7046/7047, MCP-Seite 82: reguläre AT zum eigenen Zeitpunkt, PA als
Reaktion auch davor. Eine umgewandelte zweite AT liegt bei aktueller INI−8,
nicht unter 0 und nach regulären Aktionen derselben Phase. Verzögerte Aktionen
verwenden bei Konkurrenz die höhere ursprüngliche INI. Gleiche Werte ohne
belegte Entscheidung werden ausdrücklich am Tisch geordnet.

Abwarten speichert höchstens eine tatsächlich reservierte reguläre Aktion.
Währenddessen sind weitere AT/PA gesperrt; eine erzwungene Abwehr verwirft die
Reserve vor ihrer eigenen Freigabe. Bei Schaden fordert die App nur auf ausdrückliche
Eingabe die belegte Selbstbeherrschungsprobe mit bestätigten SP an. Abbruch dieser
Probe beantwortet die Erhaltfrage nicht. Bewegung mit halber GS bleibt sichtbar
am Tisch zu beachten, weil keine räumliche Bewegungsverwaltung vorhanden ist.

## Bedienung

Der Gefechtskopf öffnet eine gemeinsame INI-Ansicht. Im Teilnehmerkopf stehen
„+ Held“ und „+ Gegner“. Helden benötigen eine eindeutige ID und aktuelle Werte;
Gegner Name und bestätigte INI. Hinzufügen während der Runde erfragt konkret,
ob ihr aktueller Zeitpunkt bereits verstrichen ist. Keine angenommene Gratisaktion.

Die Liste zeigt Runde, aktuelle Phase, reguläre und umgewandelte offene Zeitpunkte,
gebuchte Abschlüsse und Reserven. „Phase abschließen“ führt den Zeitpunkt weiter;
Gegneraktionen werden hier manuell bestätigt. Heldendialoge bleiben dieselben.
Nicht zeitgerechte aktive AT werden mit konkretem Grund gesperrt, reaktive PA
bleiben nach bestehenden Freigaben möglich. Freie Aktionen behalten ihre Budgets.
Unbekannte oder widersprüchliche Zeitpunkte erzeugen eine gezielte Entscheidung.

INI-Änderungen sortieren ausschließlich offene Zeitpunkte frisch. Gebuchte
Abschlüsse werden nicht rückgängig gemacht. Verschiebt sich ein offener Zeitpunkt
vor die bereits erreichte Phase, wird dessen Abwicklung am Tisch konkret geklärt;
die App erfindet weder eine nachgeholte Aktion noch einen Budgetverlust.

„Nächste Runde“ setzt nur die ausdrücklich verbundenen Heldensitzungen gemeinsam
zurück, über den bestehenden Rundenregelpfad. Laufende Proben oder ungeklärte
Schreibabschlüsse sperren dies. Lade-/Zielzeit, Ansagefolgemalus und Meisterparadebonus
bleiben gemäß ihren bisherigen Regeln erhalten. Eine Reserve überlebt, übrige
alte Marken werden nicht angesammelt. Austritt ist bei offenen Buchungen gesperrt.

## Architektur und Buchung

Neue unveränderliche Gruppentypen unter `lib/domain/`, reine Phasen-/Reserve-Regeln
unter `lib/rules/derived/gefecht_initiative_rules.dart`, flüchtiger Riverpod-Controller
unter `lib/state/`. Die Gruppenansicht liegt als eigenes Widget unter
`lib/ui2/gefecht/`; die bereits große Hauptansicht bekommt nur die kleine Einbindung.
Provider und UI übergeben aktuelle Heldensnapshots, sie rechnen keine INI selbst.

Jeder Abschluss bekommt eine stabile Auftrags-ID. Nur die erfolgreiche bestehende
Hero-Buchung bestätigt den Gruppenabschluss; Abbruch und wiederholte Callbacks
erzeugen weder Phase noch Kosten erneut. Reservieren bezahlt genau eine Quellmarke,
ohne eine ausgeführte AT/PA oder Ansagefolge vorzutäuschen. Das spätere Ausführen
verwendet frische Freigabe und echte Probe, aber bezahlt diese Quellmarke nicht erneut.
Ein Verfall gibt keine Marke zurück. Reserve und neue Rundenmarken bleiben getrennt.
Bestehende Ressourcen-/Munitionsschreibwege werden nicht ersetzt.

## Abnahme und Grenzen

Regeltests sichern Sortierung, Gleichstände, INI−8, nachträgliche INI-Senkung,
Reservepriorität, Rundenübertrag und Verlust. Provider-/Widgettests führen zwei
eigene Helden plus manuellen Gegner, freie Probe, reaktive PA, verzögerte AT,
Abbruch/Doppelcallback und gemeinsamen Rundenwechsel durch. Bezahltes Laden/Zielen
und bestehende Ansagefolgen müssen über die Gruppenrunde erhalten bleiben.
Analyse, relevante Tests, vollständige Suite, Format und LOC bleiben Pflicht.

Der Entwurf muss vor Produktcode bestätigt werden. Ein detaillierter
Implementierungsplan folgt nach dieser Prüfung. Paket 3 ist noch nicht erledigt;
Paket 4–6 und eine abschließende Bedienabnahme bleiben anschließend offen.
