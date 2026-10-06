# Weitere Gefechtspakete ab `3e42deb`

Ausführung: nacheinander, jeweils eigener Commit nach Analyse, relevanten Tests,
Format- und LOC-Prüfung. Abschließend vollständige Testsuite. Der Auftrag vom
4. Oktober 2026 umfasst die sechs vorgeschlagenen Themen und eine Bedienabnahme.
Die Gefechtsarbeit findet im angehängten Worktree `gefecht-folgepakete` statt;
Inventarisierung und uncommittete Nutzernotizen im ursprünglichen Checkout bleiben
unverändert. Keine Veröffentlichung, kein automatischer Merge.

## 1. Optionales Zielen

Bestätigter Bedienumfang: gewünschte Erleichterung 0–4 im Fernkampfdialog,
reguläre bezahlte Vorbereitung mit dem vorhandenen Zielauftrag. WdS Chunk 7089
(MCP-Seite 98) und Übersicht 7324 (Seite 200): zwei Aktionen pro Punkt,
mit Scharf-/Meisterschütze eine. Ansage- und Gezielter-Schuss-Zuschläge dürfen
nicht gesenkt werden. WdS 7082 (Seite 95): Unterbrechung verwirft bezahlte Zielzeit.

Architektur: `GefechtAuftrag` hält die gewählte Erleichterung, `Gefechtszielstand`
bindet sie neben der Ansage an den vorhandenen Waffen-/Geschoss-/Zielnachweis.
`gefecht_zielen_rules.dart` enthält Dauer, zulässige Erleichterung und Prüfung;
`gefecht_laden_rules.dart` bezahlt die gemeinsame Dauer und erhält die Wahl im
frischen Schussauftrag. Keine Änderung des Inventarschreibwegs und keine neue
Persistenz. Die tatsächlich abbaubare Erschwernis wird vor dem Schuss frisch
berechnet; fehlende Zielzahlung sperrt weiterhin.

- [x] Regeltests zuerst rot: Dauer 0–4, SF, Obergrenze, getrennte Ansage,
  gesperrter vorzeitiger Schuss, Ziel-/Profilbindung und aktueller Zuschlag.
- [x] Vorhandenen Zielpfad erweitern und Tests grün ausführen.
- [x] Widgettest: Auswahl, reguläre Zahlung über Runden, Probeabbruch,
  Doppelcallback und einmalige Munitionsübernahme.
- [x] Dokumentation, Analyse, relevante Tests, Format/LOC, eigener Commit.

Prüfstand 4. Oktober 2026: Analyse ohne Befund; Formatprüfung über 1002 Dateien
ohne Änderung; CI-Screen-LOC (21 Dateien) und Gefechts-LOC (25 Dateien) grün.
Der zusätzlich geprüfte gesamte UI2-Baum hat weiterhin die bekannte, unveränderte
Überschreitung `karto_abenteuerblatt.dart` mit 803 Zeilen. Zehn Regeltests,
echter Zahlungs-/Schussablauf und bestehende Dialog-Layoutmatrix sind grün.
Das unabhängige Review ergab keine schwerwiegenden Befunde; die empfohlenen
Lesbarkeitskorrekturen und der explizite Gezielter-Schuss-Test sind umgesetzt.
Die abschließende vollständige Suite besteht mit 3394 Tests und drei bestehenden
übersprungenen Tests. Sie läuft mit `--concurrency=1` und eigenem
`DSA_MCP_DATA_DIR`: Der vorherige parallele Wiederholungslauf scheiterte außerhalb
des Gefechts an einer gesperrten gemeinsamen Regelindex-Cachedatei. Beide betroffenen
Testdateien bestehen nacheinander ebenfalls (neun Tests). Es wurde dafür kein
Produktionscode geändert.

Bewusste Grenze: Eine am Tisch festgestellte Störung des Zielens wird ausdrücklich
über „Handlung abbrechen“ eingegeben; keine automatische Erkennung von Gegneraktionen.
Inventarschreibweg und persistierte Heldenmodelle bleiben unverändert.

## 2. Folgen misslungener Ansagemanöver

Flüchtiger, sichtbarer Folgemalus aus tatsächlicher misslungener Buchung.
WdS 6985 (MCP-Seite 60): gesamte freiwillige und geforderte Ansage auf Proben
bis einschließlich nächster Angriffs-/Abwehraktion; freie Proben erhalten ihn,
Orientieren beendet ihn; Klingentänzer halbiert. Abbruch verändert ihn nicht.
Überschneidung mehrerer Folgen, Fachprobenpfade und FK-Abgrenzung sind geprüft.

Bestätigter und umgesetzter Umfang (5. Oktober 2026): Nahkampf-Ansagemanöver
setzen den Folgemalus nur beim tatsächlichen misslungenen Abschluss. Die nächste
gebuchte AT/PA erhält ihn noch und beendet ihn; eine dort neue misslungene Ansage
setzt anschließend ihre eigene Folge. Freie und Fachproben erhalten ihn ebenfalls,
Schadenswürfe nicht. Orientieren beendet ihn nach Abschluss; Abbruch und wiederholte
Callbacks ändern nichts. Fernkampf-Sonderansagen bleiben ohne belegte Grundlage
ausgenommen. Elf neue Regeltests und der echte Fehl-AT-/Ausweichen-/PA-Ablauf
prüfen diese Grenzen. 51 relevante Tests sind grün. Das unabhängige Review hat
keine offenen Laufzeitbefunde. Die bestehende Sperre mehrteiliger manueller
AT/PA bleibt erhalten; es entsteht keine neue Freigabe für unbekannte Abläufe.
Abschlussprüfung: Analyse ohne Befund, vollständige Suite 3406 bestanden und drei
bestehende Ausnahmen (`--concurrency=1`, eigener Regelindex-Cache). Formatprüfung
über 1004 Dateien ohne Änderung, CI-Screen-LOC (21 Dateien), Gefechts-LOC (25)
und die erweiterte Widgettestdatei innerhalb 700 Zeilen. Die bekannte unveränderte
breite UI2-Überschreitung des Abenteuerblatts (803 Zeilen) bleibt offen.
Der erste Gesamtlauf deckte eine bestehende Identitätsprüfung beim misslungenen
Orientieren ohne Folgemalus auf; der unveränderte Zustand wird wieder direkt
zurückgegeben. Nach Korrektur sind die betroffenen Tests und die gesamte
Wiederholung grün. Paket 2 ist als eigener Commit abgeschlossen, ohne Push/Merge.

## 3. Globale Initiative und Phasen

Bestehende Grenze: gemeinsame lokale, flüchtige Teilnehmerliste ohne neue
Persistenz. INI-Änderungen wirken sofort auf offene Zeitpunkte. WdS 7046/7047
(Seite 82): verzögerte Aktion, Verlust bei Abwehr, höchstens eine Reserve über
Runden; umgewandelte Attacke INI−8 nach regulären Aktionen derselben Phase.
Teilnehmerwahl und gegnerischer Datenumfang sind als offene Nutzerentscheidung
erfragt. Dieses neue Teilsystem benötigt vor Umsetzung einen konkreten Entwurf.

## 4. Komplexe Manöverabläufe

Entwaffnen/Umreißen zuerst als abgeschlossene Gegenproben-/Folgenabläufe;
Klingenwand/Klingensturm anschließend mit eigenen geteilten Proben. Kein
gewöhnlicher Waffenschaden für schadenslose Manöver. Gegnerfolgenumfang ist
erfragt; Quellen und konkreter Satz unterstützter Manöver sind vor Umsetzung
einzeln festzulegen.

## 5. Patzer und Bruchtests

Konkrete Folgewürfe aus tatsächlich festgestelltem Patzer bzw. Bruchtestanlass.
Hausregel 25819: bestandener Bruchtest nach kritischem Treffer erhöht BF nicht.
Waffenänderungen ausschließlich über den dann vorhandenen frischen Schreibweg;
mit der parallelen Inventarisierung abgleichen. Keine ungefragte Entfernung
einer zerbrochenen Waffe. Tabellen und unterstützte Probenarten erst belegen.

## 6. Magie-/Karmagrenzen und Bedienabnahme

Jeweils einzelne belegte Profile schließen; permanente Kosten, fremde Ziele
und Repräsentationsausnahmen nur bei vollständigem Kontext. Konkrete erste
Profile anhand der vorhandenen Katalogdaten und Quellen auswählen, nicht aus
Beschreibungsschlagwörtern automatisieren. Abschließende Ablaufprüfung mit
mehreren Angriffen, Waffenwechsel, Laden über Runden und unterbrochenem Zauber.

## Stand der Pakete 3–6 (5. Oktober 2026)

Die Pakete 3–6 sind mit dem bestätigten Umfang „mehrere Gegner mit Name, LeP,
RS und INI flüchtig führen“ umgesetzt und im [Abschlussentwurf](gefecht_abschluss_entwurf.md)
sowie in `gefecht_implementation.md` beschrieben: lokale Begegnung und
gemeinsame Initiative mit Reserve, Klingenwand/Klingensturm, Entwaffnen/Umreißen
mit Gegenprobe, Patzer und Bruchtest sowie der Fulminictus als erste
Fremdwirkung. Weitere Magie-/Karmaprofile bleiben einzeln zu belegen.

## Fortschritt und Grenzen

Die Reihenfolge ist verbindlich; offene fachliche Entscheidungen sind keine
bereits implementierten Pakete. Regelberechnungen bleiben unter `lib/rules/derived`,
UI und Provider verwenden gemeinsame Freigaben. Jeder Paketabschluss hält Tests,
Commit und bewusst offene Grenzen fest. Neue Funktionen werden mit Dart-Docs
erklärt, Dateien bleiben innerhalb des 700-Zeilen-Richtwerts.
