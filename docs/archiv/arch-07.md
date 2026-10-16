# Archiv — ARCH-07 Nutzerabläufe und Datenmigrationen absichern (Umsetzungsstand, Befunde)

Archiv der Architektur-Roadmap, Stand 16.10.2026. Dies ist der unveränderte Wortlaut des früheren Roadmap-Abschnitts; die Roadmap ([architecture_roadmap.md](../architecture_roadmap.md)) führt nur noch Status und offene Punkte. Verweise wie „Teilstand (3)“ in Code, CLAUDE.md und anderen Dokumenten beziehen sich auf diesen Text.

---

## ARCH-07 — Nutzerabläufe und Datenmigrationen absichern

**Ist-Zustand:** Regel-, Domain-, Daten-, Provider- und Widgettests sind bereits
getrennt vorhanden. Die CI prüft unter anderem Analyse, Tests und einen
Web-Release-Build. Für den Umbau braucht es zusätzlich gezielte Nachweise über
vollständige Abläufe, alte Datenformate und unterbrochene Synchronisierung.

**Ziel:** Repräsentative Bestandshelden und kritische Nutzerabläufe sichern die
schrittweise Weiterentwicklung ab. Die Trennung der Testverantwortlichkeiten aus
der [Teststrategie](../test_strategy.md) bleibt erhalten.

**Einstieg:** `test/domain/hero_sheet_model_test.dart`,
`test/data/hero_actions_import_export_test.dart`,
`test/data/syncing_hero_repository_test.dart`, `test/state/advancement_session_test.dart`,
`test/ui/smoke/widget_test.dart` und `.github/workflows/flutter-tests.yml`.

- [x] Kleine, anonymisierte bzw. synthetische Bestandsfixtures mit erwarteten
  Ergebnissen anlegen: normale, magische/karmale und epische Helden, eigene
  Textmerkmale, gleichnamige Ausrüstung und ältere Schema-Versionen.
- [x] Den Ablauf „importieren → steigern → ausrüsten → Spielaktion → schließen
  → wieder öffnen → exportieren“ auf Erhalt der gespeicherten Daten absichern.
  Tests für jede neue Migration direkt im jeweiligen Modellumbau ergänzen.
- [x] Unterbrochenen Sync, Wiederholung und Konflikte zweier Geräte reproduzierbar
  testen; automatisierte Prüfungen und nötige manuelle Plattformprüfungen in der
  Teststrategie sowie der CI nachvollziehbar verorten.

**Abnahme:** Jede eingeführte Migration hat einen Bestandsfall und einen Test
für erneutes Laden ohne weitere Veränderung. Kritische Abläufe prüfen reale
Speicher-/Ladegrenzen. Erwartungen für Regelwerte stehen in Regeltests, während
UI-/Ablauftests Navigation, Persistenz und Fehlerbehandlung prüfen. Abgedeckte
Plattformen und verbleibende manuelle Prüfungen sind ausdrücklich dokumentiert.

**Abhängigkeiten / offene Entscheidungen:** Vor ARCH-02/03 mit Fixtures beginnen
und alle Aufgaben begleiten. Umfang echter Integrationstests, Geräteauswahl und
CI-Ausführung anhand der betroffenen Plattformpfade konkretisieren.

**Umsetzungsstand 27.09.2026 — Grundausstattung fertig.** Die drei
Unterpunkte sind erledigt; der Hauptpunkt bleibt offen, weil ARCH-07 jede
weitere Aufgabe begleitet (neue Migration → neue Fixture). Branch
`task/2026-09-27-arch07-bestandsfixtures`, Commits `2c82021` (Sync-Fakes
ausgelagert), `1878edd` (`buildHeroComputedSnapshot` als reine Funktion,
verhaltensneutral), `a4f13ff` (Fixtures, Domain), `16a9e53` (Regelwerte,
Ausrüstung), `bb73400` (echter Hive-Ablauf) und der Abschluss-Commit mit dem
Zwei-Geräte-Sync und dieser Dokumentation.

- **Fixtures:** neun Bestandshelden unter `test/fixtures/heroes/` (normal,
  magisch, karmal, episch, Freitext-Merkmale, gleichnamige Ausrüstung,
  handgeschriebener Altstand ohne Schemaversion, Schemaversion 27 mit
  Historie und eine Variante mit unbekannter Steigerungsart). Die Regeln zu
  Unveränderlichkeit, Formatwächter-Hashes und Aktualisierung der Regelwerte
  stehen in der [Teststrategie](../test_strategy.md#bestandsfixtures-arch-07).
- **Ablauf:** `test/data/bestandsheld_ablauf_test.dart` mit echtem Hive über
  Neustart und Export hinweg, dazu Import → Neustart → Export für jede Fixture.
- **Zwei Geräte:** `test/data/sync_zwei_geraete_test.dart` mit gemeinsamer
  Cloud, Netzabbruch mitten im Abgleich, verlorener Antwort, Neustart (auch mit
  echtem Hive) und allen drei Konfliktauflösungen einschließlich gebundenem
  Zustand. Das Test-Fake hasht dafür jetzt wie die echten Gateways
  (`heroContentHash`) und prüft auch bei Zuständen die Vorrevision.
- **Prüfungen:** `flutter analyze` ohne Befund, vollständige Suite grün.
  Plattformabdeckung und verbleibende manuelle Prüfungen stehen in der
  Teststrategie; die CI braucht keine Änderung.

**Befunde.** Das Paket ist verhaltensneutral: Die Tests halten das heutige
Verhalten mit dem Kommentar `Befund ARCH-07-Bx` fest, behoben wird in eigenen
Aufträgen.

| ID | Risiko | Befund | Nachweis | Folgeauftrag |
|---|---|---|---|---|
| B1 | hoch | Der Inspector schreibt Dauermodifikatoren nach `persistentMods`. Ist `statModifiers` leer, spiegelt `HeroSheet.fromJson` sie dorthin; `derived_stats.dart` zählt beides, die Kampfvorschau nur `persistentMods`. Nach jedem Laden stehen die Werte doppelt (f07: LeP 36 statt 34), im Sync folgt ein zusätzlicher Upload. | Domain-, Regel- und Sync-Test (f05, f07) | Sofortfix empfohlen, vor ARCH-02 |
| B2 | mittel | Entfernt man die erste von zwei gleichnamigen Waffen, erbt die zweite deren Inventardaten (Wert, Beschreibung, Gewicht). | `bestandshelden_ausruestung_test.dart` | ARCH-03 |
| B3 | mittel | Umbenennen einer Waffe verliert ihre Inventardaten. | `bestandshelden_ausruestung_test.dart` | ARCH-03 |
| B4 | niedrig | Ohne Konto stempelt `HiveHeroRepository` `lastModified` nur, wenn es fehlt; geladene Objekte bringen ihren Stempel mit, er bleibt der des ersten Speicherns. Mit Konto stempelt `SyncingHeroRepository` korrekt. Die Konfliktansicht zeigt dadurch nach dem Anmelden veraltete Zeiten für Offline-Helden. | `bestandsheld_ablauf_test.dart` | ARCH-06 oder Kleinfix |
| B5 | mittel | Eine unbekannte Steigerungsart (`kind`) wirft beim Laden und macht den ganzen Helden unlesbar — etwa nach einem Export aus einer neueren App-Version. | Domain-Test (f08b) | Versionsstrategie vor ARCH-02 |
| B6 | mittel/hoch | Unbekannte Felder gehen bei `fromJson`/`toJson` verloren. Ein Gerät mit älterer App überschreibt per Sync die neueren Felder. | Domain-Test | Versionsstrategie vor ARCH-02/03 |
| B7 | mittel/hoch | Nahkampf-AT/PA der Kampfvorschau rechnen mit eigenen Modifikatoren (`combat_rules.dart`: `persistentMods`, Textmodifikatoren, `tempMods`). Wundabzüge fehlen nachweislich, obwohl AT-Basis und Initiative sie enthalten; laut Code fehlen dort auch benannte und Inventar-Modifikatoren (nicht eigens getestet). | Regeltest (f01, f04 mit Wunde) | eigener Regelauftrag, Bezug ARCH-04 |
| B8 | mittel | Offline geänderte Laufzeitwerte (LeP, AsP, Wunden …) lädt `syncNow` nicht hoch: `_syncHeroStates` überträgt nur Zustände, die online noch fehlen. Erst die nächste Zustandsänderung mit Verbindung holt sie nach; wechselt man vorher das Gerät, sieht es den alten Stand. | `sync_zwei_geraete_test.dart` | eigener Sync-Auftrag, Bezug ARCH-06 |
| B9 | niedrig/mittel | `_mergeEntry` baut verknüpfte Inventareinträge aus dem Slot neu auf und übernimmt nur eine feste Feldliste. Typ (`typ`) und Träger (`traegerTyp`, `traegerId`) gehen bei jedem Speichern verloren, obwohl der Inventareditor den Träger auch für verknüpfte Einträge anbietet. | `bestandsheld_ablauf_test.dart` (f01) | behoben (Kleinfix, siehe Aktualisierung) |
| B10 | hoch | Nach dem Übernehmen eines Online-Stands merkte sich die Sync-Basis den Hash des Schreibers. Konnte diese Version den Stand nicht verlustfrei darstellen, lud ein bloßer Abgleich die verkürzte Fassung ohne Konflikt hoch und löschte fremde Felder auf allen Geräten. | `sync_app_versionen_test.dart` | behoben (`192cf41`) |
| B11 | mittel | Der Angriffsdialog der Begleiter baute einen bearbeiteten Angriff neu auf und setzte die gekauften AT/PA-Steigerungen (`steigerungAt`/`steigerungPa`) auf 0 zurück; die ausgegebenen AP blieben gebucht. | `test/ui/begleiter/begleiter_angriff_test.dart` | behoben (Kleinfix, `a8bde70`) |
| B12 | mittel | Ein verknüpfter Inventareintrag mit unbekannter Quelle (`source`) galt über den Ersatz `manuell` als manueller Eintrag; der Abgleich legte für seinen Slot einen zweiten, verknüpften Eintrag an. | `unbekannte_verschachtelte_felder_test.dart` (Inventarabgleich) | behoben (minimal abgesichert, `9d2aeaa`) |
| B13 | mittel | Ein Waffenslot mit unbekannter Kampfart fiel auf Nahkampf zurück; Verweismigration und Abgleich verwarfen seine Geschosse samt Inventardaten, Mengenänderungen liefen ins Leere. | `unbekannte_verschachtelte_felder_test.dart`, `bestandsheld_ablauf_test.dart` | behoben (Kleinfix, `9d2aeaa`) |

**Aktualisierung 27.09.2026:** B1 (`d5f111c`), B7 (`de36df2`), B8
(`20102a0`), B4 (`9eebf93`) sowie B5/B6 (`6be321c`) haben Fix-Commits.
B2/B3 sind im ARCH-03-Teilstand oben behoben. Bei B6 bleiben unbekannte
Felder *innerhalb* verschachtelter Objekte ungeschützt; der Fix bewahrt
unbekannte Felder oberster Ebene und unbekannte Steigerungsarten. Nächster
Architekturschritt ist die Versions- und Sync-Kompatibilität für neue
verschachtelte Felder, bevor ARCH-03 über den B2/B3-Teilfix hinausgeht.

**Aktualisierung 28.09.2026:** B6 deckt jetzt auch die Ausrüstung ab
(`f28cb1a`); andere verschachtelte Modelle bleiben ungeschützt, siehe den
ARCH-03-Teilstand vom 28.09.2026. B10 ist mit `192cf41` behoben, B9 ist neu
und gehört zu ARCH-03.

**Aktualisierung 28.09.2026 (B9):** Vorgezogen als Kleinfix, weil jedes
Speichern Daten verlor. `_mergeEntry` (`inventory_sync_rules.dart`) baut
verknüpfte Einträge nicht mehr aus dem Slot neu auf, sondern ändert den
bestehenden Eintrag per `copyWith`; aus dem Slot kommen nur Identität,
magisch/geweiht, `istAusgeruestet` (Ausrüstung) und `anzahl` (Geschosse).
Der Test in `bestandsheld_ablauf_test.dart` setzt an f01 Typ und Träger,
speichert, ändert den Kampf und prüft nach dem Neustart. Die Fixtures und
Hash-Pins bleiben unverändert, keine trägt Typ oder Träger.

**Aktualisierung 28.09.2026 (verschachtelte Modelle):** B6 deckt jetzt alle
verschachtelten Modelle von Held und Zustand ab, siehe ARCH-03-Teilstand
„Alle verschachtelten Modelle“. Neu ist B11, als Kleinfix behoben, weil
jedes Bearbeiten eines Begleiterangriffs gekaufte Steigerungen verlor.

**Aktualisierung 28.09.2026 (Aufzählungswerte):** B6 bewahrt jetzt auch
unbekannte Aufzählungswerte und Wundzonen, siehe ARCH-03-Teilstand
„Unbekannte Aufzählungswerte“. B12 und B13 traten erst mit dem Ersatzwert
zutage und sind mit `9d2aeaa` behoben: B12 minimal (der Eintrag deckt seinen
Slot ab und bleibt unverändert), B13 über `MainWeaponSlot.fuehrtGeschosse`,
das auch eine unbekannte Kampfart als geschossführend behandelt.

**Abdeckungsaudit neuer Modelle (16.10.2026).** Geprüft wurde, ob jedes seit der
Grundausstattung additiv eingeführte Modell die ARCH-07-Anforderungen erfüllt
(Schlüsselliste, Erhalt unbekannter Felder, unverändertes JSON nach erneutem
Laden). `test/domain/unbekannte_verschachtelte_felder_test.dart` führt dafür
67 Modelle in einer Tabelle (`_pruefeModelle`), darunter `HeroRegelProfil`,
`HeroRegelProfilPaket`, `HeroHerkunftsModifikator(en)`, `HeroMerkmal`,
`SpellEffectInstance`, `AlchimikumBezug`, `Vitalwirkung`, `ReittierAusbildung`,
`VertrautenBindung`, `BegleiterZustand` und `ZustandsBuchung`; `ArtefaktDaten`
deckt `unbekannte_ausruestungsfelder_test.dart` ab. Der Vollständigkeitswächter
im selben Test fängt jedes weitere Modell ab, die Hash-Pins aus
`bestandshelden_kompatibilitaet_test.dart` halten die Bestandsfixtures
unverändert. Migrationen mit Bestandsfall und Reload-Test: Herkunft
(`herkunft_migration_test.dart`, `herkunft_sync_test.dart`), Merkmale
(`merkmal_migration_test.dart`), Inventarverweise
(`bestandshelden_ausruestung_test.dart`). **Keine Lücke gefunden**, es wurden
keine Tests ergänzt. Gesamtsuite: 6177 bestanden, 3 übersprungen, 0 fehlgeschlagen.
Der Hauptpunkt bleibt bewusst offen (begleitend); verbleibend sind die
manuellen Plattformprüfungen aus der Teststrategie (Web/IndexedDB, native
Pfade, `file_picker`, Live-Firebase).
