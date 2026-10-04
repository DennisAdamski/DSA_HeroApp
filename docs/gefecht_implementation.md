# Erste Flutter-Version des Gefechts

Verbindliche Grundlage: `mockups/gefecht-plan.md` und der freigegebene
Umsetzungsplan vom 1. Oktober 2026. Die bisherige Kampfverwaltung bleibt erhalten.

## Teilpakete

1. Flüchtiger Zustand je Held und gemeinsame Freigaben unter `rules/derived`.
2. Einmalige Gefechtsproben über die gemeinsame Engine und das Protokoll.
3. Einstieg im Spielen-Bereich, responsive Gefechtsansicht, Aktionsdialoge.
4. Eigenes Ausrüstungspopup, verzögerte Waffenwechsel, bestehende Fachdialoge.
5. Regel-, Ablauf-, Speicher- und Layoutprüfungen sowie Abschlussreview.

## Grenzen der Automatisierung

Keine globale Phasenuhr und keine Speicherung laufender Gefechte. Ansagezeitpunkt,
Gegnervoraussetzungen, Zusatzaktionen, Ziehkontext und nicht abbildbare Manöver,
Magie- und Karmaregeln müssen ausdrücklich geprüft werden. Bekannte Sperren
bleiben dabei verbindlich. Dauerhafte Änderungen verwenden die bestehenden
Schreibwege auf dem frisch geladenen Helden.

Der Ausbau nach `1b79203` ist in `gefecht_next_plan.md` nachgeführt. Kontakt und
Angriffsart werden flüchtig erfasst. AT/PA und Ausweichen prüfen tatsächliche DK;
Finte wird nach einer Abwehr nicht in den nächsten Angriff übernommen. Fernkampf
verwendet numerische Entfernungsprofile, bestätigte Situation und Ladezustand.
Ein gewürfelter Schuss hält seine offene Munitionsübernahme bei Schreibfehlern,
statt eine zweite Probe zu verlangen. Sonderangriffe bleiben manuell geprüft.

Aufmerksamkeit übernimmt den vorhandenen festen INI-Wurf (einschließlich
Klingentänzer) und überspringt den Dialog. Das ist die gewünschte App-Regel;
WdS gewährt das Maximum erst beim Orientieren.

## Fortschritt

Die Umsetzung und ihre Prüfungen werden je Teilpaket hier nachgeführt.

- Zustand/Freigaben und einmaliger Probe-Modus implementiert. Erste Tests
  decken Umwandlung, INI-Fixierung, Ausweichsperren, SK-II-Paraden, Abbruch,
  Doppelbuchung und die bisherigen Probeaufrufer ab.
- Einstieg und responsive Ansicht implementiert. Die Rundenleiste läuft über
  die ganze Breite; Haltung, Gegner und DK stehen neben der direkten Ansage.
  Manöver sind suchbar und ihre Liste bleibt in der Höhe begrenzt. Auf dem
  Handy stehen Angriff, Manöver und Verteidigung vor Durchhalten.
- Ausrüstung und Fachdialoge verbunden: verzögerter Waffenwechsel, frische
  Slot-Auswahl, Rüstungskorrektur mit Konfliktprüfung, Schaden, Ressourcen,
  Wunden, Effekte und das bestehende Protokoll.

## Bedienung und bewusste manuelle Abläufe

„Gefecht läuft“ öffnet die erhaltene Sitzung ohne neuen INI-Wurf. Reguläre,
freie und Zusatzmarken bleiben getrennt. Die hohen INI-Boni werden bei der
ersten verbrauchten Marke fixiert. Zusätzliche Waffenaktionen benötigen eine
tatsächlich ausgeführte passende reguläre Aktion und eine verfügbare
Ausrüstungsoption. Schildkampf II erlaubt die zweite gewöhnliche Schildparade
nur nach einer ersten Schildparade; längere Handlungen verwenden dieses Budget
nicht. Umwandlung wird verbindlich bestätigt, Korrekturen sind separat.

Finte und Wuchtschlag sind unabhängige Ansagen (Standard 0), zusätzlich zur
weiteren Erschwernis. Ihre Summe ist durch TaW und AT begrenzt; Waffentalent,
Finte-BE und Schildführung werden geprüft. Ohne erlernte SF gilt die über
`excelRound` gerundete halbe Wirkung, mit SF die volle Wirkung. Feste
Manöverzuschläge, Schildzuschläge und Waffenmeister-Erleichterungen werden
genau einmal angewandt. Normaler Angriff und Sturmangriff erlauben beide
Ansagen gleichzeitig. Der Sturmangriff benötigt auch die Abwehraktion,
GS mindestens 4 und eine konkrete Bestätigung für vier Schritt Anlauf.

Ein erfolgreich gebuchter Angriff hält Kampfmittelidentität, Waffenname und
Finte-Abwehrmalus. `gefechtsSchadensfolgeFuerAuftrag` klassifiziert zentral
unterstützten Waffenschaden, keinen Schaden oder manuelle Folgen. Normaler
Angriff, Finte, Wuchtschlag, Sturmangriff, Hammerschlag, Todesstoß, Gezielter
Stich und Niederwerfen behalten eingefrorenes Schadensprofil und TP-Bonus.
Entwaffnen und Umreißen liefern keinen Schaden. Unbekannte Manöver und manuelle
Probevarianten erhalten eine ausdrückliche manuelle Schadensfolge; gebundene
Finte-/TP-Metadaten bleiben dabei erhalten, ohne gewöhnlichen Schaden vorzugeben.
`gefechtsSchadenFuerAngriff` liefert für schadenslose/manuelle Folgen `null`.
Nur unterstützter Waffenschaden bietet einen Schadensbutton; andere Folgen
werden nach Abwicklung am Tisch einzeln abgeschlossen. Beides entfernt nur
die zugehörige Auftrags-ID. Mehrere offene
Treffer bleiben erhalten; ein späterer Fehlschlag löscht keinen Treffer. Ein allgemeiner
Schadenswurf erhält keinen alten Bonus; Waffenwechsel verändert das eingefrorene
Profil nicht. Fehlgeschlagene oder doppelt zurückgemeldete Angriffe erzeugen
keinen zusätzlichen Erfolgsbonus. Offene Munitionsübernahme erhält das Ergebnis.
Gegnerische Abwehr und weitere Manöverfolgen bleiben am Tisch: insbesondere
verlangt Hammerschlag die manuelle Verdreifachung der gesamten TP einschließlich
TP-Ansage; Todesstoß verlangt konkrete Klärung von RS/Schild/Wundfolgen.
Die zentrale Kombinationstabelle unterscheidet erlaubt, verboten und einzeln
zu klären; eine bloße Beschreibung ist keine automatische Kombinationsfreigabe.
Gebundener FK-Schaden ersetzt den TP-Anteil des gespeicherten Vorschau-Distanzbands
genau einmal durch den Anteil der eingegebenen Schussentfernung, für beide Hände.
Geschoss-, Effekt- und übrige Vorschauanteile bleiben erhalten; der Ansagebonus
kommt einmal hinzu. Kann das tatsächliche Band nicht bestimmt werden, hält der
Ergebnisbinder Waffenidentität und Ansagebonus mit einer manuellen Schadensfolge
fest und bietet keinen automatischen Schadenswurf. Die bestehende Schussfreigabe
bei fehlendem Entfernungsprofil wird dadurch nicht aufgehoben.
Ganze Formularabschnitte besitzen stabile Identitäten: wechselnde Hinweise,
Modifikatoren und Entscheidungen erhalten Tastaturfokus und Cursor bei
mehrstelliger Eingabe sowie beim Wechsel zwischen ungültigen und gültigen Werten.

FK-Ansage: Grenze TaW, bei Meisterschütze FK; halbe TP normal, volle TP bei
Scharf-/Meisterschütze. Zusätzlich bezahlt werden gerundete halbe Ansageaktionen,
bei Scharfschütze zwei weniger (mindestens eine), bei Meisterschütze genau eine.
`Gefechtszielstand` bindet die Zahlung an Waffe, Geschoss, vollständiges Profil,
konkreten Zielkontakt und Ansage. Allgemeines optionales Zielen senkt den
Ansagezuschlag nicht. „Zusatz-Zielen beginnen“ bucht reguläre Aktionen; die
Handlung hält den ursprünglichen Schussauftrag über Runden fest. „Fortsetzen“
bezahlt weitere Zielzeit. Erst „Schuss ausführen“ prüft aktuelle Ausrüstung,
Angaben und eigenes Schussbudget erneut. Der ursprüngliche Auftrag bindet Waffe,
Geschoss, Zielkontakt und Ansagen; DK und Sitzungskontext stammen dagegen aus
dem aktuellen Gefecht. Ein abgebrochener Probedialog erhält den DK-Wechsel
während Zielen und die bezahlte Vorbereitung ohne neue Zahlung. Beim gebuchten Schuss wird der
Zielstand verbraucht; Rundenschritte erhalten ihn.

### Laden und Vorbereiten (3. Oktober 2026)

Geführte Fernkampfwaffen beider Hände bieten „Laden / Vorbereiten“. Ein unbekannter
anfänglicher Ladezustand muss konkret bestätigt werden. Ein bereits bekannter
entladener Zustand kann nicht durch ein neues „Ja“ die Ladezahlung umgehen.
Ein veralteter Ladestand nach Waffen-/Geschossprofilwechsel ist unbekannt und
kann im Schussdialog ausdrücklich frisch bestätigt werden. Ein passender
bekannter entladener Zustand hat weiterhin Vorrang vor Formulareingaben.
Ladung gehört zur physischen Waffen-ID, bleibt beim Wechsel derselben Waffe
zwischen Händen erhalten und wird nie auf eine andere ID übertragen.

`Gefechtshandlung.vorbereitung` hält Kampfmittel-/Geschoss-ID, Profilkey,
bezahlte Aktionen und ursprüngliche Dauer. Laden verwendet bei jedem Fortsetzen
die aktuelle effektive Combat-Ladezeit einschließlich Effekten/Waffenmeister.
`Rest = max(0, aktuelle Dauer − bezahlt)`; geänderte Dauer und erhaltene Zahlung
werden angezeigt. Vollständig bezahltes Laden wirkt auch bei leerem Budget ohne
weitere Marke. Nur reguläre Marken bezahlen Laden/Zielen, keine freien Aktionen,
SK-II- oder anderen Zusatzparaden. Unterbrochene Vorbereitung erstattet keine
Aktionen und überträgt keinen Fortschritt. Geänderte Profile, Geschosse, Bestände,
fehlende stabile IDs/Munition und andere Zielkontakte erklären konkrete Sperren.
Ladebindung ignoriert ausschließlich die veränderbare Basisladezeit; Zielbindung
verwendet unverändert das komplette Task-2-Waffenprofil samt Bestand.

Schnellladen Armbrust erhält echt gerundete drei Viertel der Basisladezeit,
statt drei Viertel abzuziehen: Basis4→3, Basis8→6, Basis5→4. Eine bereits besessene
SF zusammen mit Axxeleratus spart zusätzlich eine Aktion. Schnellladen wirkt
bei effektiver Rüstungs-BE nach Rüstungsgewöhnung bis einschließlich 4, sowohl
besessen als auch durch Axxeleratus verliehen. Bei BE 5 entfallen Schnellladen
und der Kombinationsbonus; Schnellziehen bleibt unverändert. Waffenmeister wird
weiterhin genau einmal in der zentralen Vorschau gerechnet.

Bezahltes fertiges Zielen bleibt als bereiter Schuss sichtbar. Kampfgespür kann
danach eine verbliebene PA spontan umwandeln: kein Refund, Umwandlungszuschlag
und INI−8 bleiben. Laufende Resthandlungen und offene Munitionsübernahme sperren
diese Umwandlung weiterhin. Ohne passende SF bleibt späte Umwandlung gesperrt.

Munition wird ausschließlich beim tatsächlich gewürfelten Schuss übernommen.
Doppelte Probe-Callbacks buchen einmal. Fehlgeschlagene Übernahme erhält Probe,
Ergebnis und offenen Schuss; Retry würfelt nicht erneut. Abschluss entlädt nur
die betreffende Waffe und konsumiert das eingefrorene Geschoss einmal über den
frischen Ausrüstungsschreibweg. Ein gewürfelter Schuss besitzt keinen Abbruchbutton;
der Abbruchguard und die erneute Endkampfprüfung erhalten die offene Übernahme.

Kampfgespür erlaubt spätes Umwandeln ohne pauschalen Zeitpunktdialog. Verbrauchte
reguläre Marken werden auf die neue Verteilung angerechnet; bereits verbrauchte
Quellmarken erzeugen keine weitere umgewandelte Aktion. Aufmerksamkeit reicht
nicht nach eigener Attacke. Schild verbietet PA→AT; Waffenverbote und INI−8
bleiben bindend. Defensiver Kampfstil wird nur bei konkreter Rundenbeginnansage
aktiviert. Aktiver Klingentänzer und BE≤2 kennzeichnen seine eigenen Fähigkeiten;
spontane Umwandlung stammt weiterhin aus aktivem Kampfgespür, auch bei BE>2.
Inkonsistente Daten mit Klingentänzer ohne Kampfgespür ergänzen keine Voraussetzung
stillschweigend (WdS 75/82; MCP 7030/7046/7047).

Manöver zeigen Katalogtext, Voraussetzungen und Zielwert. Eindeutig bezifferte
Katalogzuschläge werden getrennt automatisch angewendet, freie Zusatzwerte
beginnen bei 0. Variable Zuschläge und nicht automatisierte
Kosten/Folgen werden bestätigt. Bekannte Lern-, Talent-, Waffen- und
Gegnersperren (einschließlich Hammerschlag) bleiben verbindlich. Die vollständige
Manöverwirkung am Gegner wird nicht simuliert. Abwehrmanöver verbrauchen PA;
Gegenhalten verwendet dabei AT ohne hohen INI-Paradebonus (WdS 69–70, DSA-MCP).
Aktuelle Kopf-INI-Verluste kommen zusätzlich zu den bereits berechneten Wundmali
zur Anwendung. Waffenmeister-Erleichterungen werden ausdrücklich im Dialog zur
Prüfung genannt; zusätzliche freigegebene Manöver erweitern die Waffenfreigabe.

Orientieren wird regelgeführt: zwei Aktionen und IN-Probe mit Kriegskunstbonus,
mit Aufmerksamkeit eine Aktion ohne Probe. Das Ergebnis übernimmt INI-Maximum
und rückgewinnbare Kampfverluste automatisch. Position + Orientieren nach freiem
Ausweichen bezahlt gemäß Hausregel eine Aktion. Ungeklärte Korrekturen müssen
zuerst zugeordnet werden; Wund-/Zaubermali bleiben erhalten. Freies
Ausweichen verliert vier INI, bei Erfolg wird Position erforderlich; gezieltes
Ausweichen berücksichtigt DK und verliert bei Misslingen zwei INI. Rückweichen
und weitere Gegnerfolgen bleiben manuell.

Zauber und Liturgiekenntnis stammen aus gelernten Heldendaten und dem aktuellen
Katalog; die Probe benutzt die gemeinsame Engine. Zauber werden zu Beginn
einmal ausgewertet; ihre Wirkung tritt nach der bestätigten Dauer ein.
Liturgieprobenzeitpunkte werden anhand des konkreten Profils bestätigt. KaP/AsP-Kosten und Wirkungen
werden über die vorhandenen Ressource-/Effektdialoge geführt. Fehlende Katalog-
oder Probeninformationen erhalten einen manuellen Zielwert, keine angenommene Formel.

## Verifikation

Regel-, State-, Probe- und Widgettests prüfen Umwandlung, hohe INI, Haltung,
Ausweichvarianten, Zusatzaktionen, Schildparaden, bekannte Manöversperren,
Aufmerksamkeit/Klingentänzer, Abbruch, doppelte Ergebnisbuchung und Navigation.
Die Ausrüstungstests verwenden den echten Bestandsadapter und einen zweiten
Schreibweg: verschobene Slots, neue fremde Daten und unbekannte Felder bleiben
erhalten. Bei Speicherfehlern bleiben Abschluss und Aktionsmarke offen.

Das Raster prüft 390/820/1200/1440 Pixel in Hell/Dunkel mit echten Karto-Schriften,
hoher INI und offenen Aktions-/Ausrüstungspopups. Aufnahmen lassen sich reproduzieren:

```powershell
flutter test test/ui2/spielen/gefecht_visual_test.dart --dart-define=GEFECHT_SCREENSHOT_DIR=<Verzeichnis>
```

Stand der Abnahmeprüfung: `flutter analyze` ohne Befund, 332 relevante Tests
bestanden, zusätzlich acht Rastertests mit 24 gerenderten Zuständen. Bestehende
Kampfverwaltung und bisherige Probendialoge sind in der Regression enthalten.

Die Abschlusskorrektur trennt die zusätzliche SK-II-Schildparade von regulären
Reaktionen: Sie kann weder Position noch gezieltes Ausweichen bezahlen. Zauber
werden bei vollständig bezahlter Dauer sofort genau einmal ausgewertet; Abbruch
vor der Auswertung verbraucht auch bei zwei Aktionen keine Marke. Beide Fälle
sind durch zuerst fehlschlagende Regressionstests abgesichert.

Abschlussreview vom 2. Oktober 2026: drei relevante Befunde behoben. Zusätzlich
zu Budget und Zauberabschluss schützt eine gemeinsame Sperre bestehende
Resthandlungen vor neuen kurzen/längeren Zaubern und manuellen Aufträgen. Nur
der ausdrückliche Fortsetzen-Pfad darf die bestehende Handlung weiterführen.
Regel-/Ablaufregressionen einschließlich verzögerter Zauberproben und Abbrüchen
bestehen; `flutter analyze` meldet keine Probleme. Die dokumentierten manuellen
Grenzen bleiben Bestandteil dieser ersten Version.

### Waffen-SF und Ziehen (Folgepakete 3a/3b)

Defensiver Kampfstil und talentgebundene Manöver werden über stabile IDs gelesen.
Waffenmeister reduziert den bestätigten Manöverzuschlag automatisch einmal.
Halbschwert benötigt die bestätigte Führung; Klingenwand/-sturm werden nicht als
einfache Einzelprobe abgewickelt. Bekannte Kataloglängen über zwei Schritt und
improvisierte Waffen sperren Umwandlungen; fehlende Profile bleiben manuell.
Das Ziehpopup fragt Trageposition, Griffbereitschaft und freie Hände.
Schnellziehen vom Gürtel/Arm/Brust bezahlt eine freie Marke; Rücken und Schild
erhalten die WdS-Dauer. Schilde vom Rücken sind eigene Nebenhandhandlungen.

### Zauber und Karma (Folgepakete 4a–4c)

Die frühere Endprobe für Zauber ist ersetzt: Ergebnis am Anfang einfrieren,
Dauer bezahlen, dann Kosten/Folgen übernehmen. Erfolg bindet volle Dauer;
Misserfolg halbe Dauer aufgerundet, mit Zauberkontrolle eine Aktion.
Störung verwendet Selbstbeherrschung mit Konzentrationsstärke; zusätzliche
Auswirkungen auf ZfP* bleiben ausdrücklich am Spieltisch geprüft.
Mirakel/Liturgien nutzen die Hausregel-Kulteigenschaften und separate Profile.
Liturgiezeitpunkt, konkrete Dauer und permanente Kosten sind manuell bestätigt.
Der Wirkabschluss verwendet den vorhandenen frischen Zustandsweg und bestehende
Armatrutz-/Attributo-Dialoge. Kosten und unterstützte Effekte sind ein Write;
Wiederholung einer übernahme erzeugt keinen zweiten Wurf. Separate Kostenübernahme
im Ressourcendialog merkt sich die Buchung bis zum Folgenabschluss.
Alle neuen Wirk-, Wiederholungs- und Mirakelbonusdaten bleiben flüchtig.

## Hauptwaffe und Nebenhand

Das Ausrüstungspopup bietet beide Handrollen, Waffen in beiden Händen und
Schilde/Parierwaffen in der Nebenhand. Leer führt über bestätigtes Wegstecken.
Ziehhandlungen speichern ihre Zielhand flüchtig und wechseln erst beim frischen
Abschluss. Doppelbelegung, Zweihandkonflikte und geänderte Ziele sperren sichtbar.

Abwehrdialoge zeigen das verwendete Kampfmittel: Schild vor zulässiger
Parierwaffe vor Hauptwaffe. Hauptwaffen- und Parierwaffenparade sind getrennt;
Nebenhandwaffen verwenden ihre eigene Vorschau einschließlich Falsche-Hand-Mali.
Schild-eBE ist enthalten, der AT-WM einer Parierwaffe wirkt nicht auf Haupt-AT.
Zusatzattacken/-paraden zeigen das konkrete Mittel und den berechneten Zielwert.
Die Probeengine erhält AT/PA statt einer allgemeinen Eigenschaftsprobe. Das
flüchtige Rundenmodell merkt Ausrüstungspaar, reguläres Abwehrmittel und Ansage.
Eine Zusatzmarke steht nur nach der passenden regulären Aktion mit derselben
Ausrüstung zur Verfügung; Schild-/Parierwaffenparaden benötigen jeweils vorher
dieselbe Abwehrart. Rundenwechsel löscht die Bindung, erhält laufende Handlungen.
SK-II-Zusatzparaden bezahlen keine reguläre Dauerhandlung. Zwei PW-Paraden
bleiben ohne Ansage und Umwandlung. Doppelangriff/geteilte Pools bleiben manuell.

WdS 71 (DSA MCP 7015–7017), Errata WdS S.3–4 (25631), geprüft 2026-10-02:
Schildführung sperrt einschlägige Manöver auch mit der Hauptwaffe; Finte/Ausfall
erhalten den belegten Zusatz, kleine Schilde die Finte-Ausnahme. Schildparaden
fragen je Angriff, ob der Schild-WM wirkt; bei Kettenwaffe/-stab oder Peitsche
entfällt nur der WM, nicht SF/Heldenanteile. Fernkampf-Munitionsabschluss verwendet
die gewählte Waffen-ID auch für eine normale Nebenhandwaffe.

Manuell bleiben improvisierte bzw. zugleich als Schild/Parierwaffe verwendete
Sonderprofile und Bruchtests. Tod von Links wird bei fehlendem Angriffsprofil des
bestehenden Parierwaffen-Eintrags erklärt gesperrt; es wird kein Hauptwaffen-AT
als Ersatz erfunden. Ein vollständiges eigenes Angriffsprofil erfordert eine
Waffe mit Talent und Waffenwerten im vorhandenen Waffeninventar.

Nach Zusatzparaden werden Finte, Angriffsart, Paradeverbot und die gegnerische
Schild-WM-Ausnahme gelöscht. Auch gesperrte Kampfmittel bleiben im Dialog
darstellbar und erklären ihre fehlenden Voraussetzungen, ohne einen Wurf zuzulassen.

## Gemeinsame Freigabe und Bedienung (3. Oktober 2026)

`pruefeGefechtAuftrag` unterscheidet Sperrgründe, fehlende Angaben, offene
Entscheidungen und Hinweise. Dieselbe Prüfung läuft in Aktionsliste, Dialog und
erneut mit aktuellen Heldendaten unmittelbar vor Ausführung. Der allgemeine
Pflichthaken entfällt; Hinweise allein sperren keine Aktion. Konkrete manuelle
Entscheidungen werden einzeln bestätigt. Ungültige Zahlen, Dauer/Kosten,
fehlender manueller Zielwert und fehlende tatsächliche Distanz stehen unmittelbar
beim deaktivierten Ausführen-Button.

Die Manöverliste kombiniert Suchtext, Alle/Angriff/Verteidigung/Sonstige,
„Nur erlernte“ und „Ohne bekannte Sperre“. Gemischte AT/PA gehören in beide
Kategorien. Passive SF erhalten keine ausführbare Attacke; bekannte aktive
Katalogeinträge ohne Typ werden ausdrücklich über ihre stabilen IDs zugeordnet.
Schildparade wird nur bei einem grundsätzlich nutzbaren geführten Schildprofil
angezeigt; situative Budget- und Gegnersperren bleiben sichtbar. Handgemenge,
Nahkampf, Stangenwaffen und Piken ersetzen die sichtbaren Einzelbuchstaben.

Paketprüfung: 86 Regel-/Widget-/Ablauftests einschließlich 390/820/1200/1440
Pixeln, Hell/Dunkel und geöffneter Tastatur bestanden. Getrennte Ansagen,
Ergebnisboni, spontane Umwandlung und Laden gehören zu den Folgepaketen.

Der Paketreview zeigte eine abweichende Aktionszuordnung bei Formations-Parade
und Seitenwechsel ohne Katalogtyp. Die Ausführung verwendet nun dieselben
Kategorien einschließlich der ID-Fallbacks wie die Liste; Verteidigung hat bei
gemischten AT/PA Vorrang. Zwei Regressionen laden die echten Split-Einträge,
prüfen den PA-Zielwert mit gegnerischer Finte und die ausschließliche PA-Buchung.
Ein Widgettest aktiviert Kategorie und beide Statuschips und prüft die tatsächlich
verbleibenden Manöver. Der erweiterte Paketlauf umfasst 89 bestandene Tests.

## Gesamtabnahme des elfteiligen Ausbaus (4. Oktober 2026)

Alle drei Implementierungspakete und ihre unabhängigen Reviews sind abgeschlossen.
Der Gesamtreview fand zusätzlich Fokusverlust bei dynamischen Formularabschnitten,
eine unwirksame Ladungsbestätigung nach Profilwechsel und Distanz-TP aus dem
gespeicherten statt dem tatsächlichen Schussband. Die gemeinsame Korrektur
`81cece0` behebt alle drei mit echten Regressionen; der gezielte Abschlussreview
meldet keine offenen Befunde. Die erhaltenen Schild-eBE-Testwerte wurden separat
als `aac4425` committed.

Frische Abschlussprüfungen: 255 Gefechtsregressionen und 454 relevante
Gefecht-/Kampf-/Ladezeitprüfungen bestanden. Die vollständige Suite besteht mit
3.318 Tests und drei bestehenden übersprungenen Tests. Analyse und beide
LOC-Prüfungen sind ohne Befund; der vollständige CI-Formatcheck prüft 991 Dateien
ohne Änderungsbedarf. Die Layoutmatrix umfasst 390/820/1200/1440 Pixel,
Hell/Dunkel und Tastatur; die schmale Fernkampfansicht wurde zusätzlich visuell
geprüft.

Der letzte veröffentlichte GitHub-Stand `90967bb` scheiterte am Formatcheck;
Tests und Android-Build wurden übersprungen, LOC und Firebase-Preview bestanden.
Die drei Formatblocker sind lokal korrigiert. Ein neuer Remote-Lauf steht für
die noch lokalen Commits aus; lokale Prüfungen gelten nicht als Remote-CI-Erfolg.

Die zusätzliche Testnotiz zum Zahlenfokus ist behoben. Waffenbezogene
Zweihändigkeit, ein eigenständiger Bedienpfad für Distanzklassenwechsel und die
später ergänzten Notizen zu Vitalwerten, Parade-Abfrage und Meisterparade sind
im [Folgeplan](gefecht_next_plan.md) separat vorgemerkt. Allgemeines optionales
Zielen, komplexe Gegnerfolgen und globale INI-Phasen bleiben wie vereinbart
abgegrenzt. Ein nicht bestimmbarer tatsächlicher Distanz-TP-Modifikator erzeugt
keinen automatischen gebundenen Schadenswurf; unbrauchbare Entfernungsprofile
erhalten keine neue Freigabeausnahme. Gefechte bleiben flüchtig.
