# ARCH-06: Wiederanlauf zusammengehöriger Konfliktentscheidungen

Stand: 10.10.2026. Entwurfsstand zur Nutzerprüfung; noch nicht implementiert.
Ausgangspunkt: `03cb80ca` und die
[technische Abnahmeprüfung](../../arch06_abnahme.md).

## Auftrag und Abnahmeziel

Der Nutzer hat die Fortsetzung von ARCH-06 und anschließend die Ausarbeitung
des Wiederanlaufvertrags freigegeben. Die zwei reproduzierten Abbruchlücken
bei „Nur Lokal“ und „Beide behalten“ sind der konkrete Anlass. Der Vertrag
umfasst ebenso „Nur Online“ und „Automatisch“, wenn eine Heldenentscheidung
mehrere Dokumente betrifft.

Eine bereits gewählte Fassung bleibt nach Fehler, verlorener Antwort und
Neustart erhalten. Bogen und zugehöriger Zustand werden vollständig gemäß
dieser Entscheidung abgelegt. Eine lokale Kopie bekommt dauerhaft dieselbe
ID und ihren gesicherten Zustand. Wiederholung erzeugt weder weitere Kopien
noch zusätzliche Ressourcen- oder AP-Buchungen. Neue lokale oder entfernte
Änderungen werden ausdrücklich entscheidbar, bevor der Wiederanlauf sie
überschreiben könnte.

## Architekturentscheidung

Das vorhandene `Vorgangsjournal` wird um eine versionierte Vorgangsart für
Konfliktentscheidungen erweitert. Es bleibt lokal im Kontoprofil und enthält
die gewählten vollständigen Dokumentfassungen samt Wiederanlaufdaten.
Firestore, REST-Transport, Dokumentrevisionen und Krypto-Wire-Format bleiben
im bestehenden Vertrag. Es entsteht keine allgemeine Operationswarteschlange.

Andere Ansätze wurden anhand der Abbruchfenster eingegrenzt:

- Eine andere Schreibreihenfolge schützt jeweils nur eines der Dokumente.
  Ein alleiniger Vorab-Schreibzugriff auf die Kopie behebt den Verlust bei
  „Beide behalten“, aber nicht die Zustandsentscheidung von „Nur Lokal“.
- Atomare Remote-Batches würden Remote-Übergangszustände verhindern, benötigen
  aber einen neuen Transportvertrag für native und REST-Gateways sowie weiterhin
  einen lokalen Wiederanlauf. Das ist ein eigener, größerer Teilumfang.

Das Journal passt zum vorhandenen Import-Wiederanlauf. Konfliktentscheidungen
benötigen allerdings Online-Revisionen und laufen deshalb im Sync-Repository;
der bestehende lokale Import-Wiederanlauf führt diese Vorgangsart nicht aus.

## Dauerhafter Vorgang

Ein `SyncKonfliktVorgang` unter `lib/data/sync/` beschreibt einen vollständig
geplanten Entschluss. Das Format enthält mindestens:

| Angabe | Zweck |
|---|---|
| Art, Formatversion, Vorgangs-ID, Konto-ID, Zeitpunkt | Sichere Zuordnung und Erkennung unbekannter Formate |
| Ursprüngliche Konfliktart, Original-ID, gewählte Aktion | Wiederherstellung einer verständlichen offenen Entscheidung |
| Feste Kopie-ID bei „Beide behalten“ | Dieselbe Kopie bei jedem Versuch |
| Betroffene IDs und vollständige Zielfassungen von Bogen und Zustand | Wiederanlauf ohne erneute Regelauswertung oder Dreiwege-Zusammenführung |
| Lokale Ausgangsfassungen und ihre Inhalts-Hashes | Erkennen weiterer Nutzeränderungen und Erhalten der ursprünglichen Daten |
| Gelesene Online-Fassungen, Revisionen und Tombstone-/Fehlzustände | Prüfen, ob eine andere Änderung seit der Entscheidung eingetroffen ist |
| Bestätigte Remote-Ergebnisse je Dokument | Erkennen bereits erledigter Schritte und neue Basis nach Abschluss |

Ein fehlender Zustand, ein leerer Zustand und ein Remote-Tombstone sind
unterschiedliche Angaben. Unbekannte JSON-Felder in den Nutzdaten bleiben
über die vorhandenen Modell- und Feldschutzpfade erhalten. Unbekannte
Vorgangsarten, Versionen und Schritte bleiben unangetastet und werden als
offen gemeldet. Ein fehlerhafter Eintrag verhindert die Bearbeitung anderer
gültiger Vorgänge nicht, darf aber nicht still gelöscht werden.

Lesbare unbekannte Einträge reservieren ihre angegebenen betroffenen IDs.
Sind diese IDs nicht sicher bestimmbar, bleibt normaler schreibender Sync
vorsorglich gesperrt und der Status nennt den Journaleintrag; lokale Bearbeitung
und das Prüfen anderer Journaleinträge bleiben möglich. Die Hive-Ablage muss
beschädigtes JSON je Eintrag isoliert melden können, statt beim Lesen des ersten
fehlerhaften Eintrags das gesamte Journal zu verlieren.

Der Vorgang wird vor dem ersten lokalen Überschreiben oder Remote-Schreiben
vollständig gespeichert. Scheitert diese Journalablage, beginnt kein
Dokumentschreibzugriff. Je Originalheld ist höchstens eine Entscheidung aktiv;
Doppelklick und Wiederholung verwenden diesen Vorgang. Die Kopie-ID wird einmal
bei der Vorbereitung vergeben und anschließend nur aus dem Journal gelesen.

## Vorbereitung der vier Entscheidungen

Vor der Planung werden laufende Uploads des Helden abgewartet. Lokale Werte
werden frisch geladen. Die Online-Revision des angezeigten Konflikts muss noch
gültig sein; hat sie sich geändert, wird der Konflikt aktualisiert, bevor ein
Entschluss gespeichert wird. Für den Zustand wird seine Online-Fassung ebenfalls
frisch geprüft. Nach dieser Vorprüfung schützen die Remote-Vorrevisionen weitere
Änderungen; eine gemeinsame Remote-Transaktion wird damit nicht behauptet.

| Aktion | Original | Kopie |
|---|---|---|
| Nur Lokal | Frischer lokaler Bogen und lokaler Zustand | Keine |
| Nur Online | Geprüfter Online-Bogen und Online-Zustand | Keine |
| Beide behalten | Geprüfte Online-Fassung | Frische lokale Fassung unter der einmal vergebenen Kopie-ID |
| Automatisch | Einmal berechnete, vollständig entschiedene Zusammenführung | Keine |

Für „Automatisch“ werden bestehende Zusammenführungsregeln und Feldentscheidungen
verwendet. Offene Werte verhindern die Vorbereitung. Der fertige Zielzustand
wird im Journal gespeichert; Wiederanlauf berechnet keine Zählerdeltas neu.

Die bestehende Sonderregel bei fehlendem Online-Zustand bleibt ausdrücklich:
Die frische lokale Fassung bleibt erhalten und kann danach angelegt werden.
Ein Online-Zustands-Tombstone ergibt die bestehende leere lokale Darstellung.
Gateways ohne Zustandsschnittstelle führen ausschließlich Bogenschritte aus.

Helden-Tombstones, lokale Löschkonflikte, Offline-Profilentscheidungen und
eigenständige Zustandskonflikte sind nicht Teil dieses Korrekturpakets. Sie
werden vor der Journalvorbereitung auf ihre bestehenden Pfade geleitet.

## Ausführung und Wiederholung

1. Alle betroffenen IDs werden für normalen Pull, Upload und stille
   Zusammenführung gesperrt. Die Sperre wird auch nach Neustart aus dem Journal
   rekonstruiert. Sie betrifft Original und Kopie; andere Helden laufen weiter.
2. Vor jedem Dokumentzugriff werden lokaler Stand und Online-Stand geprüft.
   Bei neuen, abweichenden Fassungen wird vor weiteren Überschreibungen gestoppt.
3. Bei „Beide behalten“ werden Kopiebogen und Kopiezustand zuerst lokal aus
   dem gesicherten Entschluss abgelegt. Das Original bleibt bis dahin erhalten.
4. Die geplanten Dokumente werden mit ihren geprüften Vorrevisionen übertragen
   und lokal vollständig abgelegt. Jeder bestätigte Remote-Schritt wird im
   Journal nachgeführt. An bereits identischem Zielinhalt wird nichts erneut
   angewandt; ein geänderter Zeitstempel allein ist keine neue Buchung.
5. Erst nach vollständiger Ablage werden Basisstände und Sync-Metadaten aller
   Dokumente nachgeführt. Scheitert ein Teil davon, bleibt der Vorgang offen.
6. Der Journaleintrag wird zuletzt entfernt. Erst dann enden Sperre und offene
   Entscheidung. Scheitert das Entfernen, ist ein erneuter Abschluss idempotent.

Nach verlorener Antwort kann die Remote-Revision bereits fortgeschritten sein.
Der Wiederanlauf liest das Dokument: Entspricht sein Inhalt exakt der gesicherten
Zielfassung, gilt der Schreibschritt als erledigt. Andernfalls darf nur auf einer
noch gültigen gespeicherten Vorrevision geschrieben werden. Eine bloß ähnliche
Fassung oder dieselbe Helden-ID genügt nicht. Bei unklarer Darstellbarkeit eines
fremden Formats wird die Änderung als Konflikt erhalten.

Lokal ist ein Schritt wiederholbar, solange sein Stand der Ausgangsfassung oder
der Zielfassung entspricht. Eine dritte Fassung ist eine neue Änderung. Auch
wenn das Journal nach erfolgreichem Schreiben noch nicht aktualisiert wurde,
erkennt der Inhalt den bereits erledigten Schritt. Geplante Zeitstempel werden
für Wiederholungen beibehalten.

## Neue Änderungen und Parallelität

Neue lokale Bearbeitung darf weiterhin lokal gespeichert werden. Sie wird
während eines offenen Vorgangs nicht automatisch übertragen. Der Wiederanlauf
erkennt die dritte Fassung und überschreibt sie nicht. Lokale Schreibzugriffe,
Listener-Übernahmen und Wiederanlaufschritte desselben Helden müssen innerhalb
des Repositorys nacheinander laufen: Zwischen Prüfung und Schreiben darf kein
zweiter Zugriff vorbeiziehen. Für Original und Kopie werden Sperren in stabiler
ID-Reihenfolge genommen. Bestehende gebündelte Zustandsuploads werden davor
abgewartet; interne Schritte dürfen sich nicht erneut in dieselbe Sperre einreihen.

Online-Listener dürfen betroffene IDs melden, sie aber nicht außerhalb des
Vorgangs lokal übernehmen. Ein CAS-Fehler führt zum erneuten Lesen und dann
entweder zur Erkennung eines bereits erledigten Schreibens oder zur sichtbaren
neuen Entscheidung. Ein Netzfehler erhält den bisherigen Entschluss unverändert.

Bei einer neuen abweichenden Fassung wird der offene Vorgang zusammen mit der
frischen Änderung als Konflikt angezeigt. Die bisher gewählte Fassung bleibt
als Vergleichsseite erhalten, selbst wenn ihr Bogen bereits erfolgreich
übertragen wurde. Keine automatische Zählerzusammenführung beseitigt diese
Frage. Ein neuer Entschluss ersetzt den bisherigen Journaleintrag erst nach
erfolgreicher dauerhafter Ablage. Bereits angelegte Kopien und deren neue
Änderungen bleiben erhalten; dieselbe Kopie-ID wird weiterverwendet. Neue
Kopiedaten werden bei einer erneuten Entscheidung in den Vergleich einbezogen.
Wurde bereits eine Kopie angelegt und die neue Entscheidung verlangt keine
Kopie, bleibt sie als selbstständiger Held erhalten. Sie wird weder gelöscht
noch durch den neuen Entschluss überschrieben. Eine geänderte Kopie bekommt
vor einem weiteren Schreibzugriff eine eigene sichtbare Feldentscheidung.

## Start, Status und Grenzen

`AppStartupGate` reicht das bereits geöffnete `HiveVorgangsjournal` an
`SyncingHeroRepository` weiter. Der Import-Wiederanlauf bleibt vor dem Sync.
Sync-Vorgänge werden beim Konto-Sync vor normalem Pull/Push aufgenommen. Auch
die früh startenden Listener warten auf die Journalinitialisierung und respektieren
die Sperren. Ein nicht erreichbares Netz lässt die App mit lokalem Stand starten;
der Vorgang bleibt offen und der Sync-Status nennt den ausstehenden Abschluss.

Fehler werden über den vorhandenen Sync-Status und die Konfliktkarte angezeigt.
Eine noch offene Entscheidung darf nicht als erfolgreicher Gesamtabgleich
gelten. Ein blockierter Wiederanlauf nennt die neu geänderten Daten. Reine
Netzfehler erfordern keine erneute Nutzerentscheidung; der nächste Abgleich
versucht denselben Vorgang erneut. Ein unbekannter Eintrag bleibt sichtbar.

Das lokale Journal macht den eigenen Wiederanlauf verlässlich. Andere Geräte
können während zweier getrennter Remote-Schreibzugriffe vorübergehend eine
Zwischenfassung lesen. Kontoübergreifende atomare Sichtbarkeit wäre ein eigener
Remote-Vertrag; sie wird mit diesem Entwurf nicht zugesichert. Lösch-, Avatar-
und Begleiterabläufe behalten ihre dokumentierten Grenzen. Die vollständige
ARCH-06-Abnahme bleibt anschließend separat anhand aller Kriterien zu prüfen.

## Zuständigkeiten und betroffene Dateien

- `lib/data/sync/sync_konflikt_vorgang.dart`: Journalformat und sichere Decodierung.
- `lib/data/sync/konflikt_wiederanlauf.dart`: wiederholbare Dokumentschritte mit
  lokalen Prüfungen und Remote-Vorrevisionen; keine fachlichen Berechnungen.
- `lib/data/hive_vorgangsjournal.dart`: beschädigte Einzelwerte erhalten und
  beim Lesen isoliert melden, soweit der heutige JSON-Lesepfad dies erfordert.
- `lib/data/syncing_hero_repository.dart` und dessen Zusammenführungsteil:
  Planung, Journalanbindung, Sperren, Konfliktstatus und normale Sync-Pfade.
  Neue Verantwortung wird in eigene kleine Dateien ausgelagert.
- `lib/ui/screens/app_startup_gate.dart`: vorhandenes Profiljournal injizieren.
- Sync-Status/Controller und Konfliktkarte: ausstehenden oder blockierten
  Abschluss zeigen; Erweiterung nur, soweit vorhandene Angaben nicht genügen.
- `test/test_support/sync_geraete.dart`: Journal über `neustart()` erhalten.
- Tests unter `test/data/`: dauerhafte Abbruchproben und echte Hive-Neustarts.
- CLAUDE.md, Roadmap, Speichervertrag, technische Übersicht, Abnahmebericht und
  Teststrategie: tatsächlichen Teilstand und offene Grenzen gemeinsam nachführen.

Regelberechnungen bleiben bei ihren bisherigen Regelmodulen. Das Journal und
der Wiederanlauf dürfen weder Schaden neu berechnen noch AP oder Ressourcen
aus gespeicherten Deltas erneut buchen.

## Verbindliche Prüfungen für die spätere Umsetzung

| Fall | Erwartung |
|---|---|
| Beide Abbruchproben aus der Abnahme | „Nur Lokal“ endet bei 21 LeP; Kopie behält 21 LeP |
| Nur Online: Abbruch nach lokalem Bogen vor Zustand | Online-Fassung wird vollständig fortgesetzt oder sichtbar blockiert |
| Automatisch: Abbruch nach Bogen vor Zustand | Gesicherter Zielzustand wird einmal übernommen; Deltas werden nicht neu verrechnet |
| Abbruch vor/nach jedem lokalen, Remote-, Journal-, Basis- und Metadatenschritt | Wiederanlauf erhält Daten und die gewählte Zuordnung |
| Verlorene Antwort bei Original und Kopie, wiederholter Aufruf/Doppelklick | Dieselbe Vorgangs- und Kopie-ID; keine Zusatzbuchung |
| Neue Online-Revision oder Tombstone vor bzw. während Wiederanlauf | Kein blindes Überschreiben; sichtbarer Konflikt mit erhaltenem Entschluss |
| Neue lokale Änderung an Original oder Kopie | Kein Datenverlust; neue Fassung bleibt erhalten und entscheidbar |
| Listener, schneller Zustandsklick und `syncNow` während der Entscheidung | Kein konkurrierender Zugriff auf eine gesperrte ID |
| Netz dauerhaft nicht erreichbar | Lokaler Start möglich, offener Abschluss bleibt sichtbar und dauerhaft |
| Journal nicht schreibbar, unbekanntes Format, fehlerhafter Einzelvorgang | Kein ungesicherter Dokumentschreibzugriff oder stilles Entfernen |
| Fehlender Zustand, leerer Zustand, Zustandstombstone, Gateway ohne Zustände | Die jeweils definierte Sonderbehandlung bleibt erhalten |
| Echte Hive-Boxen schließen und neu öffnen | Vorgang, Zielfassungen, IDs und Sperren überstehen den Neustart |
| Transporttests nativ und REST | Revision und Fehlervertrag bleiben kompatibel |

Mindestens `flutter analyze`, relevante serielle Sync-/Ablauf-/Widgettests und
die Transporttests laufen nach Umsetzung. Für das umfangreiche Sync-Paket wird
anschließend die vollständige Suite seriell ausgeführt. Manuelle Geräte- und
Live-Firebase-Prüfungen werden nur als erfolgt angegeben, wenn sie tatsächlich
durchgeführt wurden. Ein Commit folgt nur auf erfolgreiche relevante Prüfungen.

## Freigabestand

Dieser Entwurf konkretisiert den freigegebenen Lösungsansatz. Er enthält noch
keinen Implementierungscode und behauptet keine behobenen Abbruchlücken. Nach
Nutzerprüfung entsteht daraus der Implementierungsplan mit Reihenfolge,
konkreten Tests und Abschlussnachweisen.
