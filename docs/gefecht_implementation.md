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
  Handy stehen Angriff, Manöver und Verteidigung vor den Vitalwerten.
- Ausrüstung und Fachdialoge verbunden: verzögerter Waffenwechsel, frische
  Slot-Auswahl, Rüstungskorrektur mit Konfliktprüfung, Schaden, Ressourcen,
  Wunden, Effekte und das bestehende Protokoll.

## Bedienung und bewusste manuelle Abläufe

Die Gefechtskarte „Vitalwerte“ zeigt geschlossen nur LeP, aktivierte AsP und
vorhandene Wunden mit ihrer Körperzone. Auch unterdrückte Wunden bleiben
sichtbar, weil die Anzeige den gespeicherten Wundenzustand verwendet.
Geöffnet bleiben alle bisherigen Ressourcen-, Schadens-, Wunden- und
Effektfunktionen erreichbar. Eine stabile Heldenidentität erhält den
Aufklappzustand bei Ressourcenänderungen; die bisherige automatische Öffnung
bei Wundabzügen oder höchstens halben LeP gilt nur beim ersten Aufbau.

„Parade erlaubt?“ wird nicht mehr abgefragt. Für eine normale Nahkampfparade
genügen konkrete Angriffsart und gegnerische Finte, zusätzlich zur üblichen
DK-, Ausrüstungs- und Budgetprüfung. Ein bekanntes Paradeverbot bleibt gesperrt
und wird bei Änderungen anderer Kontextfelder erhalten. Fernkampf- und
Sonderangriffe bleiben manuell zu prüfen; Schildparaden benötigen weiterhin
den konkreten Schild-WM-Kontext.

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
konkreten Zielkontakt und Ansage. Allgemeines optionales Zielen wird separat
bezahlt und senkt den Ansagezuschlag nicht. „Zusatz-Zielen beginnen“ bucht reguläre
Aktionen; die
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

Die effektive Handbelegung wird zentral aus Kampftalent und Waffenart bestimmt.
Bogen und gewöhnliche Armbrust benötigen beide Hände, auch bei historischen
`isOneHanded: true`-Standardwerten. Die Waffenart Balestrina bleibt gemäß Arsenal
(DSA MCP 70) einhändig; ein frei geänderter Anzeigename allein genügt nicht für
diese Ausnahme. Wurfwaffen und unbekannte Waffen behalten ihre gespeicherte
Belegung. Es erfolgt keine Datenmigration. Anzeige, frische Handzuweisung,
Kampfmittelprofile und Zusatzmarken teilen diese Prüfung; widersprüchliche alte
Nebenhandkonfigurationen erlauben auch keine SK-II-Restmarke.

„Distanzklasse ändern“ ist ein eigener Einstieg mit eigener Richtungswahl
(eine/zwei DK annähern oder entfernen). Der normale Angriff bietet diesen
Wechsel nicht an. Der Dialog zeigt Finte, keine Schadensansagen. Die bestehende
AT-/Auftragsprüfung bezahlt eine AT und einen freien Schritt; aktuelle
Waffen-DK-Mali gelten dabei nicht. WdS 80 (DSA MCP 7041): zwei DK annähern +8,
eine DK entfernen +4, zwei DK entfernen +8; drei DK sind ausgeschlossen.
Der Wechsel verursacht keinen Schaden. Erfolgreiches Entfernen wirkt sofort,
Annäherung erst nach bestätigter fehlender gegnerischer Abwehr. Formular- oder
Probeabbruch verbraucht keine Marken; Misslingen verbraucht die bestätigten
Kosten ohne DK-Wechsel. Fehlende freie Schritte bleiben sichtbar gesperrt.

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

Die zusätzliche Testnotiz zum Zahlenfokus ist behoben. Vitalwerte und die
konkrete Paradeprüfung sowie waffenbezogene Handbelegung und der eigene
Distanzklassenwechsel und Meisterparade sind im Folgepaket umgesetzt.
Allgemeines optionales Zielen, komplexe Gegnerfolgen und globale INI-Phasen bleiben wie vereinbart
abgegrenzt. Ein nicht bestimmbarer tatsächlicher Distanz-TP-Modifikator erzeugt
keinen automatischen gebundenen Schadenswurf; unbrauchbare Entfernungsprofile
erhalten keine neue Freigabeausnahme. Gefechte bleiben flüchtig.

## Meisterparade im Folgepaket (4. Oktober 2026)

`gefecht_meisterparade_rules.dart` prüft die eigene Ansage getrennt von freier
Erschwernis und gegnerischer Finte. Die gemeinsame Auftragsfreigabe enthält
den endgültigen Zielwert sowie den verbrauchten alten Bonus und die neue Ansage.
Die einmalige Buchung übernimmt beides atomar: Erfolg erzeugt einen Bonus in
Ansagehöhe, Misslingen keinen. Verkettete Meisterparaden verbrauchen zuerst den
alten Bonus. Dialog-/Probeabbruch verändert ihn nicht. Er gilt für die nächste
eigene Angriffs- oder Abwehraktion, einschließlich DK, Gegenhalten, gezieltem
Ausweichen und tatsächlicher Zusatzabwehr. Freies Ausweichen, Hilfsaktionen,
Rundenwechsel und bezahltes Laden/Zielen verbrauchen ihn nicht. Der tatsächliche
Schuss verwendet den dann aktuellen Bonus. Keine TP-/Finte-Wirkung und kein
Überschreiben des separaten Mirakelbonus; Beenden/Neustart verwirft beide.

Die Grenze folgt dem TaW und der PA des konkreten Kampfmittels vor eigener
Ansage, Gegnerfinte und Situationszuschlägen. Gelernte SF, effektive Rüstungs-BE
nach Rüstungsgewöhnung höchstens 4, Katalog-/Paradeverbote und der Ausschluss
von Kettenwaffen/Zweihandflegeln bleiben verbindlich (WdS 69, Chunk 7014).
Parierwaffen verwenden das vorhandene kombinierte PA-Profil mit Linkhandpflicht.
Für Schilde ist SK II nötig. Weil das Modell keinen eigenen Schild-TaW kennt,
verlangt eine positive Schildansage eine konkrete, am Tisch festgelegte numerische
„Zulässige Schild-Ansagegrenze“. Die Hauptwaffe liefert dafür keinen angenommenen
TaW. Zusätzlich gilt die aktuelle Schild-PA, einschließlich bekannt entfallenem
Schild-WM gegen Kettenstab/Kettenwaffe/Peitsche (WdS 71). Das Eingabefeld bleibt
im flüchtigen Auftrag; Nullansage verlangt keine erfundene Grenze.

Der Bonus ist in der Ansicht und in den Modifikatoren sichtbar. Eine manuelle
Sonderaktion kann ausdrücklich als einzelne Angriffs-/Abwehraktion eingeordnet
werden; erst ihre bestätigte Buchung verbraucht den Bonus. Sonstige manuelle
Handlungen und Fachproben sind keine automatische Kampfeinordnung.

Historischer Umfang vor Paket 2: Nach einer gebuchten misslungenen Meisterparade
zeigt `gefecht_meisterparade.dart`
Ansage, Treffer und konkreten manuellen Folgemalus: gesamte Ansage auf alle
Proben einschließlich freier Aktionen bis einschließlich nächster eigener AT/PA;
Orientieren beendet, Klingentänzer halbiert aufgerundet (WdS 59/69, Chunk 6985).
Die allgemeine Fehlmanöverfolge bleibt wie vereinbart manuell. Es entsteht keine
globale automatische Malusverwaltung.

Die neuen Regeln und tatsächlichen UI-Buchungen werden in
`gefecht_meisterparade_rules_test.dart` und `gefecht_meisterparade_test.dart`
geprüft: Ansagegrenzen, Lern-/BE-/Waffen-/Schildsperren, Finte, Bonusketten,
Abbruch/Doppelcallback, frische Ausführung, Runden/Hilfsaktionen, FK-Vorbereitung,
DK/Gegenhalten/Ausweichen, manuelle Abschlüsse und stabiler Zahlenfokus.
Die bisherigen Nebenhand-Lade-/Distanzschadensfixtures verwenden die belegte
Balestrina-Ausnahme. Der Handwechseltest führt dabei denselben Typ vor und nach
dem Wechsel; eine gewöhnliche Armbrust erhält keine Nebenhandfreigabe.

### Integrationstestnachtrag nach PR #208 (4. Oktober 2026)

Der zusätzliche Test in `gefecht_meisterparade_test.dart` durchläuft die echte
Ansicht, Auftragsfreigabe, Probeengine und Providerbuchung: erfolgreiche reguläre
Schild-Meisterparade mit Ansage 3, frischer Nahkampfangriff mit Finte 1, danach
zulässige zusätzliche Schildparade mit Schildkampf II. Der Bonus erhöht Prüfung,
Dialogzielwert und tatsächliches Probenziel genau einmal um 3. Dialog-/Probeabbruch
erhalten Bonus und alle Budgets. Bei doppeltem Abschlusscallback zählt der Test
genau eine Zusatzbuchung und eine Bonusentfernung, ohne eine weitere reguläre PA
zu verbrauchen. Nur das Würfelergebnis und die Callbackwiederholung sind steuerbar;
der Produktionspfad bleibt unverändert. Prüfungen und aktueller Remote-CI-Stand
sind im [Folgeplan](gefecht_next_plan.md#testnachtrag-nach-pr-208-4-oktober-2026)
nachgeführt; frühere Abnahmeergebnisse bleiben historische Nachweise.

## Optionales Zielen (weiteres Paket 1)

Im Fernkampfdialog beginnt „Optionales Zielen: Erleichterung (0–4)“ bei 0.
„Zielen beginnen“ bezahlt zwei reguläre Aktionen je gewünschtem Punkt, mit
talentgebundener Scharf-/Meisterschütze-SF eine. Eine zusätzliche FK-Ansage
bezahlt ihre bisherige eigene Dauer zusätzlich; ihre Erschwernis und die des
Gezielten Schusses werden nicht reduziert (WdS 7089/7324, MCP-Seiten 98/200).
Aktuelle Entfernung, bestätigte Zielsituation, Kampfgetümmel und weitere
Erschwernis begrenzen den Abbau; es entsteht kein Bonus über den Abbau des
vorhandenen Gesamtzuschlags hinaus. Heldenmali und andere Boni bleiben separat.

Der vorhandene flüchtige Zielauftrag bindet beide Wahlen an Waffe, Geschoss,
vollständiges Profil und benannten Kontakt. Fortsetzen zahlt über Runden;
vorzeitiger Schuss bleibt gesperrt. Ein geänderter Situationszuschlag wird vor
dem Schuss neu berücksichtigt. Probeabbruch erhält Zahlung und Schussbudget;
„Handlung abbrechen“ verwirft die Zielzeit ohne Rückzahlung. Eine Störung des
Zielens wird über diesen expliziten Abbruch geführt (WdS 7082, MCP-Seite 95).
Die bestehenden Munitions-/Retry-/Doppelcallbackschutzwege bleiben unverändert.

Regel- und echte Widgettests prüfen getrennte Dauer, aktive talentgebundene SF,
Zahlung über Runden, Ziel-/Profilwechsel, aktuellen Zuschlag, Probeabbruch,
Abbruch ohne Refund und genau einen Schuss-/Munitionsabschluss. Die vorhandene
Layoutmatrix deckt den erweiterten Dialog in vier Breiten, Hell/Dunkel und mit
Tastatur ab. Es gibt keine neue Gefechtspersistenz oder Inventarschnittstelle.

## Folgen misslungener Ansagen (weiteres Paket 2)

Der bestätigte Umfang vom 5. Oktober 2026 ergänzt die zuvor manuelle eigene
Fehlmanöverfolge. WdS Chunk 6985, MCP-Seite 60: freiwillige und geforderte Ansage
erschweren alle Proben bis einschließlich der nächsten eigenen AT/PA. Aktiver
Klingentänzer halbiert aufgerundet; die vorhandene Aktivprüfung berücksichtigt
die BE-Grenze. Der neue flüchtige `ansageFolgemalus` entsteht ausschließlich bei
einer tatsächlich gebuchten misslungenen unterstützten Nahkampf-Ansage. Eindeutige
feste Katalogzuschläge sowie bereits verwendete Schild-/Waffenmeister-Anpassungen
werden berücksichtigt; Gegnerfinte, Umwandlung, Distanz und weitere freie
Situationszuschläge erzeugen keine eigene Ansagefolge.

Die gemeinsame Auftragsprüfung zeigt den Malus einmal in Zielwert und
Modifikatoren. Freie Aktionen, allgemeine Fachproben, Wirken, Orientieren und
Störungsproben erhalten ihn ebenfalls. Schadens- und INI-Würfe bleiben getrennt.
Der nächste tatsächliche AT/PA-Abschluss trägt den alten Malus noch, entfernt
ihn und setzt gegebenenfalls danach die neue misslungene eigene Ansage. Auch
zusätzliche Abwehren und Gegenhalten verwenden ihre vorhandene fachliche
Kampfeinordnung. Freies Ausweichen, Laden, Zielen und Rundenwechsel erhalten
die Folge. Abbruch erhält Malus und Budget; doppelte Abschlussmeldungen buchen
weiterhin nur einmal. Orientieren beendet ihn beim abgeschlossenen Einsatz,
auch wenn die IN-Probe misslingt; ein Probeabbruch beendet ihn nicht.

Die vorhandenen einzelnen bestätigten manuellen AT/PA können die Folge
beenden, auch bei ausdrücklich bestätigten Kosten 0. Mehrteilige manuelle
AT/PA oder Fachproben mit manueller Kampfeinordnung bleiben wie zuvor gesperrt.
Manuelle Aktionen erzeugen mangels strukturierter eigener Ansage keine neue
automatische Folge. Variable Katalogtexte werden nicht neu interpretiert.
Fernkampf-Sonderansagen erzeugen ohne belegte Grundlage keine Nahkampffolge,
können aber als nächste AT einen vorhandenen Malus tragen und beenden.
Gegnerische Trefferfolgen, globale Phasen und persistierte Heldenwerte sind
weiterhin getrennt. Prüfstand und Paketabschluss stehen im Folgeplan.

## Vorgaben statt Pflichtfelder (5. Oktober 2026)

Auf Nutzerwunsch ersetzen sichtbare, jederzeit änderbare Vorgaben die frühere
Regel „Standardwerte sind keine Bestätigung“. `gefecht_vorgaben_rules.dart`
belegt nur unbekannte Angaben: Angriffsart Nahkampf, gegnerische Finte 0,
Zielsituation im Fernkampf 0, Platz zum Ausweichen und wirksamer Schild-WM.
Ein ausdrückliches „Nein“ bleibt erhalten. Die Regelmodule behandeln `null`
unverändert als fehlende Angabe; Vorgaben entstehen nur beim Gefechtsstart,
beim Kontakt-/Gegnerwechsel und nach jeder Abwehr (die Angriffsdaten des
abgewehrten Angriffs fallen auf die Vorgaben zurück, Zielsituation und
Entfernung des eigenen Ziels bleiben). Start-DK ist die DK der geführten
Hauptwaffe: Nahkampf, wenn sie ihn führt oder keine Nahkampfwaffe geführt wird,
sonst die erste Klasse in H/N/S/P (App-Konvention). Ausweichen verwendet ohne
eigene Angabe die Gegnerzahl der Rundenleiste. Bewusst ohne Vorgabe bleiben
Ladezustand und Schussentfernung, weil eine falsche Annahme Schüsse freigäbe.
Die zuletzt angegebene Zahl aufrechterhaltener Zauber gilt für das Gefecht.

Hinweise allein ergeben „Bereit“ (sie sperrten die Ausführung schon zuvor
nicht); „Prüfen“ bleibt fehlenden Angaben und offenen Entscheidungen
vorbehalten. Der pauschale Fernkampfhinweis und die Bestätigung der Art einer
freien Aktion entfallen, weil die Einzelprüfungen sie abdecken. Bekannte
Sperren (Paradeverbot, kein Platz, DK-Abstand, ungeladene Waffe,
Kampfunfähigkeit) bleiben verbindlich. Prüfung:
`test/rules/gefecht_vorgaben_rules_test.dart`; bestehende Erwartungen zu
gelöschter Finte wurden bewusst auf die Vorgabe 0 umgestellt.

## Begegnung, gemeinsame Initiative und Folgepakete (5. Oktober 2026)

Umfang laut [Abschlussentwurf](gefecht_abschluss_entwurf.md): Die lokale
Begegnung (`state/gefecht_begegnung_provider.dart`) führt mehrere Gegner mit
stabiler ID, Name, LeP, RS und INI. Eine Heldensitzung wählt ihren Gegner
ausdrücklich; der Wechsel verwirft Angriffsdaten und alte Zielzahlungen.
Gewöhnliche Treffer werden nach bestätigter misslungener Abwehr einmalig
übertragen: SP = max(0, TP − RS), direkte SP umgehen den RS (WdS S. 56).
Die gemeinsame Initiative verbindet ausdrücklich gewählte Helden; Zeitpunkte
werden aus frischen INI-Werten abgeleitet, reguläre Aktionen gehen
umgewandelten derselben Phase vor, eine verzögerte Aktion hält höchstens eine
bezahlte Reserve (WdS S. 82). Ohne Teilnahme bleibt das Einzelgefecht
unverändert.

Weitere Module: Klingenwand/Klingensturm mit getrennten Teilproben und genau
einer Quellmarke (`gefecht_klingen_rules.dart`), Patzerkontrolle,
Patzertabelle und Bruchtest mit eingefrorenen Würfen und frischem
BF-Schreibweg ohne automatische Entfernung (`gefecht_patzer_rules.dart`;
Hausregel: bestandener kritischer Bruchtest erhöht den BF nicht), bestätigte
Gegenproben für Entwaffnen/Umreißen (`gefecht_manoeverfolgen_rules.dart`) und
der Fulminictus als erste belegte Fremdwirkung (`gefecht_fremdwirkung_rules.dart`).
Eine natürliche 20 auf Nahkampf-AT/PA öffnet die Patzerkontrolle und sperrt
weitere Aktionen bis zur Klärung. Ohne offene Folge zeigt die Ansicht nur den
Einstieg „Bruchtest“; die Erklärung steht im Bruchtestdialog. Die neuen
Gefechtskarten lösen die Gefechtsbrücke erst beim Bedienen auf.

## Aktionsdialog (Vervollständigung G2, 5. Oktober 2026)

Der Aktionsdialog ordnet Eingaben nach Wichtigkeit: Kampfmittel, Status und
Zielwert, Distanzklasse als Chipreihe mit ausgeschriebenen Namen (bei Schüssen
ausgeblendet), Ansagen, Fernkampf- und Abwehrkontext, „Weitere Erschwernis“.
Zahlenfelder haben −/+ (`gefecht_zahlfeld.dart`); das Textfeld bleibt Quelle der
Wahrheit, Ansagen enden bei 0, die Erschwernis darf negativ werden.
Zielwertanteile, Modifikatoren, Manöverbeschreibung, Katalogtext und Quelle
stehen eingeklappt unter „Berechnung und Regeltext“
(`gefecht_dialogabschnitte.dart`). Bestätigte Entscheidungen bleiben als
angehakte Kachel sichtbar und lassen sich zurücknehmen. Der Hauptknopf nennt
den Zielwert („Würfeln · 14“) und erhält den Fokus.

Erschwernisse werden nur noch an einer Stelle erfasst: Für AT, PA, Ausweichen,
Zauber und Talente zeigt der Probendialog den „Situativen Modifikator“
schreibgeschützt mit „Im Gefecht festgelegt.“ (`kGefechtsprobenMitFestemModifikator`
in `ui/bridges/karto_gefechts_bruecke.dart`, Parameter `modifikatorGesperrt` in
`probe_dialog.dart`). Zuvor war dort ein zweiter Zuschlag mit umgekehrtem
Vorzeichen möglich. Eigenschafts-, INI- und Schadenswürfe behalten das Feld.
Der Grundzielwert manueller Sonderaktionen ist tatsächlich optional: ohne Wert
wird die Aktion ohne Probe gebucht. Prüfung:
`test/ui2/spielen/gefecht_dialog_bedienung_test.dart`.

## Ansicht und Handy (Vervollständigung G3, 5. Oktober 2026)

Jeder Aktionsknopf (`gefecht_aktionsknopf.dart`) zeigt rechts „Würfeln ·
Zielwert“, „Angabe fehlt“, „Klären“ oder „Gesperrt“ und darunter den
wichtigsten Grund aus `gefechtsHauptgrund` (Sperre vor fehlender Angabe vor
Entscheidung vor Hinweis, `gefecht_freigabe_rules.dart`). Gesperrte Knöpfe
bleiben antippbar, der Dialog erklärt alle Gründe. `gefecht_anordnung.dart`
ordnet die Abschnitte: schmal Vitalwerte, Angriff, Verteidigung, Manöver,
Magie, weitere Aktionen (mit Abwarten), Begegnung (Gegner, gemeinsame
Initiative), Ausrüstung; breit dieselben Gruppen in zwei bzw. drei Spalten.
Unter 744 Pixeln hält eine feste Schnellleiste (`gefecht_schnellleiste.dart`)
Attacke, Parade, Ausweichen und „Neue Runde“ erreichbar; sie nutzt dieselben
Prüfungen und denselben Guard wie die Abschnittsknöpfe. Fehler einer Aktion
erscheinen als schließbarer Hinweis oben in der Ansicht statt als Snackbar.
Finte und Wuchtschlag öffnen aus der Manöverliste „Angreifen“, weil sie dort
als Ansage geführt werden. Die Spielansicht bietet „Gefecht beginnen /
Gefecht läuft“ zusätzlich als hervorgehobene Schnellaktion. Schnellleiste,
Rundenwechsel, Vitalwerte und Ausrüstung stehen in `gefecht_ansicht_teile.dart`
(`part` der Ansicht). Prüfung: `test/ui2/spielen/gefecht_ansicht_bedienung_test.dart`
und die erweiterte Layoutmatrix.

## Talentproben im Gefecht (Vervollständigung G4, 5. Oktober 2026)

„Probe“ (Kopfleiste, Schnellleiste, Strg/Cmd+K innerhalb des Gefechts) öffnet
eine durchsuchbare Auswahl aller geführten Nicht-Kampftalente mit TaW* und der
acht Eigenschaften (`gefecht_probenwahl.dart`). AT, PA und Zauber laufen über
ihre eigenen Gefechtsaktionen. Danach wählt der Spieler den Zeitbedarf nach
WdS S. 55 (`gefecht_talent_rules.dart`): ohne Aktion (Reaktion), freie Aktion,
eine Aktion (Vorgabe für Talente; die meisten geforderten Proben wie
Körperbeherrschung) oder Talenteinsatz über geplante Aktionen. Ein
Talenteinsatz wird zu Beginn gewürfelt; übrig behaltene TaP* verkürzen die
Dauer (mindestens eine Aktion, App-Konvention), der Rest bleibt als Handlung
mit „Fortsetzen“ offen. Die Erschwernis wird im Dialog erfasst; jede Probe
trägt Ansagefolgemalus und einen passenden Mirakelbonus. Abbruch bucht nichts.

TaW* stammt für Probensuche und Gefecht aus `talent_probe_rules.dart`
(`talentProbenwertFuer`: TaW + Modifikator + eBE aus Kampf-BE bzw. der
vorübergehenden Talentansicht + Inventarbonus, epische KK-Halbierung,
Spezialisierung). Damit erhalten auch die Selbstbeherrschung bei Störung
und Liturgiekenntnis die bisher fehlenden Anteile. Die Probenbauer liegen in
`rules/derived/probe_request_rules.dart`; `ui/screens/shared/probe_request_factory.dart`
exportiert sie unverändert für alle bisherigen Aufrufer. Prüfung:
`test/rules/gefecht_talentprobe_rules_test.dart`,
`test/ui2/spielen/gefecht_talentprobe_test.dart`.

## Lage und benannte Aktionen (Vervollständigung G5, 5. Oktober 2026)

`gefecht_lage_rules.dart` leitet aus LeP und AuP die Lage ab (WdS S. 11,
MCP 6860): LeP ≤ 5 kampfunfähig (keine Kampfaktionen, kein Zaubern, kaum
Talente), LeP ≤ 0 Lebensgefahr, AuP 0 handlungsunfähig. Die Ansicht zeigt sie
zusammen mit der wundbedingten Kampfunfähigkeit als Banner. Nur die
wundbedingte Kampfunfähigkeit sperrt Aktionen (unverändert); die LeP-Lage
bleibt ein Hinweis, weil Sonderregeln am Tisch fallen und Helden ohne
gespeicherten Zustand 0 LeP zeigen.

„Aktion wählen“ bei den weiteren Aktionen bietet die benannten Handlungen aus
WdS S. 55 (MCP 6970/6971, `gefecht_aktionskatalog_rules.dart`): als freie
Aktion Rufen, Schritt, Drehen, Fallenlassen, Artefakt aktivieren und Sich zu
Boden werfen (GE-Probe; misslungen 1W6 INI in der Sitzung und 1W6 AuP frisch
im Heldenzustand, AuP nicht unter 0; danach liegend), Bewegen als eine Aktion
(AT, PA, Schildparade und gezieltes Ausweichen dieser Runde +4) und Sprinten
als zwei Aktionen (keine Angriffs- oder Abwehraktion dieser Runde). Beide
Rundenmarken (`bewegt`, `gesprintet`) setzt der Rundenwechsel zurück. Der
allgemeine Knopf „Freie Aktion“ bleibt für Sonstiges. Prüfung:
`test/rules/gefecht_aktionskatalog_rules_test.dart`,
`test/ui2/spielen/gefecht_aktionswahl_test.dart`.

## Inventar und Begleiter (Vervollständigung G6, 5. Oktober 2026)

„Inventar · Gegenstand benutzen“ in der Ausrüstungskarte zeigt das Inventar
gruppiert nach Verbrauchsgütern, am Körper, Gepäck und beim Begleiter
(`gefecht_inventar_rules.dart`); kampfverknüpfte Einträge erscheinen nur zur
Orientierung. Verbrauchsgüter und magische Gegenstände lassen sich benutzen
(WdS S. 55, MCP 6971): griffbereit eine Aktion, Gürteltasche 10, Rucksack 20
Aktionen (Vorbelegung aus „Wo getragen“), eine gelungene FF-Probe halbiert
die Zeit (aufgerundet, App-Konvention), ein getragenes Artefakt kostet eine
freie Aktion. Die erste Aktion wird sofort bezahlt; längere Benutzungen
bleiben als Handlung mit Gegenstandsverweis offen. Erst beim Abschluss fragt
die App, ob ein Stück abgebucht wird.

Die Abbuchung (`inventar_verbrauch_rules.dart`) folgt der ARCH-03-Entscheidung:
`menge` hat Vorrang, der Freitext `anzahl` folgt, wenn er dieselbe Zahl zeigt
oder allein die Menge trägt; eine unklare Menge wird nie geraten. Geschrieben
wird frisch über `HeroActions.updateHero` und `mitGeaendertemInventarEintrag`
(Treffer über den Inhalt, Fehler bei zwischenzeitlicher Änderung); bei 0
bleibt der Eintrag stehen, bei offener Steigerungsrunde wird nichts geändert.

Der Abschnitt „Begleiter“ (`gefecht_begleiter.dart`) zeigt je Begleiter Typ,
INI, RS/BE, MR, LeP-/AuP-/AsP-Maxima, Geschwindigkeiten und Angriffe mit
wirksamer AT/PA (`begleiter_kampfprofil_rules.dart`, auch vom klassischen
Begleiter-Tab genutzt) sowie Sonderfertigkeiten und Vertrautenmagie. Nur
Anzeige, keine Proben und keine LeP-Zählung. Prüfung:
`test/rules/gefecht_inventar_rules_test.dart`,
`test/ui2/spielen/gefecht_inventar_test.dart`.
