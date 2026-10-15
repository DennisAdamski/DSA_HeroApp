# Zaubereffekte im Kampf und Spielgeschehen – Integrationsplan

Stand: 14.10.2026. Roadmap-ID: **MAG-EFF**. Status: **Recherche und Vorschlag für spätere Umsetzung**.

## Ziel und Umfang

Zauber sollen ihre tatsächlich nutzbaren Auswirkungen auf einen Charakter sichtbar und, soweit eindeutig regelbasiert, berechenbar machen: Eigenschaften, Kampfwerte, Proben, Ressourcen, Wunden, Handlungsmöglichkeiten, Wahrnehmung und Bewegung. Betrachtet werden alle Repräsentationen, positive und negative Wirkungen, selbst gewirkte und von anderen empfangene Zauber sowie Wirkungen außerhalb des Kampfes. Ein Held muss einen Zauber nicht kennen, um sein Ziel sein zu können.

Dieser Auftrag erstellt ausschließlich Dokumentation. Die Arbeitspakete sind Vorschläge, keine Freigabe für Modellmigrationen oder Produktcode. Vor jedem Paket den aktuellen Stand prüfen und dessen konkrete Spezifikation abstimmen. Flutter/Riverpod und die vorhandenen Gefechtsabläufe werden weiterverwendet.

## Prüfung und Aussagegrenzen

- Vollständiges Metadaten-Screening der **288 Einträge** aus [magie.json](../assets/catalogs/house_rules_v1/magie.json): IDs, Namen, Merkmale, Zielobjekte, Kosten, Dauer und Quellen. Die vollständige Zuordnung steht im Anhang. Sie ist eine fachliche Vorauswahl, keine Prüfung sämtlicher Wirkungs- und Variantentexte.
- Detailprüfung ausgewählter besonders nutzbarer Wirkungen über den DSA-Regel-MCP: `search_rules` und anschließend `get_context`. Die Belegtabelle nennt die reproduzierbaren Chunk-IDs. Grundlage ist **DSA 4.1**, insbesondere *Liber Cantiones*, MCP-Quelle 7. Die PDF-Seite liegt hier jeweils eine Seite über der gedruckten Buchseite; unten stehen **Buchseiten**.
- `wirkung` und `variants` sind im Split-Katalog verschlüsselt. Aus Freitext-Metadaten oder einem Namen wird keine ausführbare Regel erzeugt. Die Laufzeit kann Texte entschlüsselt anzeigen; neue Regeln benötigen ausdrücklich geprüfte Profile und Quellen. Kryptoformate und Katalogverschlüsselung bleiben bestehen.
- Hausregeln, Repräsentationsunterschiede, Sonderfertigkeiten, Reversalis und Varianten sind vor Automatisierung je Profil gesondert zu prüfen. Eine LC-Grundwirkung ist kein Nachweis, dass alle Hausregeln oder Varianten geprüft wurden.
- **B** = Wirkungsmechanik im aktuellen Auftrag per MCP-Volltext belegt. **I** = bestehende Implementierung im Code gefunden; damit nicht automatisch vollständig regelgeprüft. **K** = Integrationskandidat, Detailprüfung vor Umsetzung erforderlich. **N** = zunächst Kontext/Notiz statt Zahlenautomatik; Varianten können die Einstufung ändern.

## Verifizierter App-Bestand

| Bereich | Tatsächlicher Stand | Konsequenz für den Plan |
|---|---|---|
| Aktive Effekte | `active_spell_rules.dart`: Axxeleratus, Attributo, Armatrutz; `HeroState.activeSpellEffects` speichert Aktivierung, Wert und optionale Dauer | Erweitern und migrieren, keine zweite parallele Effektverwaltung aufbauen |
| Eigenschaften | Attributo verwendet `HeroState.tempAttributeMods`; Ausschalten setzt diese Werte zurück | Quellenbezogene Eigenschaftsänderungen einführen, bevor mehrere Zauber dieselben Eigenschaften verändern |
| Kampfwerte | `magic_rules.dart`, `combat_rules.dart` und Herleitungen berücksichtigen bestehende Effekte | Neue Beiträge zentral durch den Snapshot und dieselben Herleitungen führen |
| Dauer | `SpellDuration` unterstützt Aktionen, KR, SR, Minuten, Stunden, Tage, permanent; Countdown ist einheitenneutral | Bestehendes Verhalten: abgelaufen bedeutet Hinweis, kein automatisches Abschalten. Automatisches Ende wäre eine gesonderte Produktentscheidung |
| Gefechtszauber | `gefecht_wirken_rules.dart`, `gefecht_wirkabschluss.dart`: Proben, Kosten, Abschluss und eigene Effekte sind vorhanden | An den Abschluss anbinden, Kosten oder Würfe nicht erneut buchen |
| Fremdschaden | `gefecht_fremdwirkung_rules.dart`: Fulminictus-Grundwirkung, eingefrorener Schadenswurf, AsP-Begrenzung, Gegnerbuchung | Bereits implementierte Grundwirkung absichern; Folgepakete betreffen zusätzliche Profile und empfangene Wirkungen |
| Persistenz | `ActiveSpellEffectsState` erhält unbekannte JSON-Felder; Zusatzdaten werden nach aktiven Effekt-IDs normalisiert | Neue Instanzen, Quellbezüge und inaktive/unterdrückte Zustände benötigen eine explizite Kompatibilitätsprüfung |

Die Aussage „keine aktive Kampf-/Effekt-Engine“ aus der [Recherche vom 31.05.2026](zauber_kampf_hexen_elfen.md) ist für den heutigen Stand überholt. In der Roadmap bestehen zudem offene Gefechts-/Herleitungsarbeiten unter ARCH-04; neue Effekte dürfen deren Unterschiede nicht durch zusätzliche Rechenwege vergrößern.

## Priorisierte, quellengeprüfte Wirkungen

Priorität **P1**: hoher Nutzen, überschaubare Regelgrenzen. **P2**: mehrere Eingriffspunkte oder Ereignisse. **P3**: komplexe Zustände, Ausrüstung, Gruppen oder Meisterentscheid. Priorität bewertet das Gesamtprofil; einzelne Teilwirkungen können früher geliefert werden.

| Zauber / Katalog-ID | Nutzbare Charakterwirkung und benötigte Eingaben | Integration / Priorität | Beleg |
|---|---|---|---|
| Falkenauge / `spell_falkenauge_meisterschuss` | FK-Probe gegen das festgelegte Ziel um ZfP* erleichtert; nächster Schuss/Wurf innerhalb ZfW KR; Konzentrationsverlust beendet das Band | Zielgebundener Probenbonus, einmaliger Verbrauch; Variante „bleibendes Band“ separat. P1 | B: LC 84, Chunk 2020 |
| Adlerauge / `spell_adlerauge_luchsenohr` | Sinnenschärfe um ZfP* erleichtert, kein Gewinn von Nachtsicht; Einzelsinn-Variante ist stärker und auf einen Sinn begrenzt | Talentbonus mit Kontextfilter; Überreizung als Ereignishinweis. P1 | B: LC 15, 1920 |
| Psychostabilis / `spell_psychostabilis` | MR +ZfP*, gegen bestimmte geistige Merkmale zusätzlich +2; Dauer und laufende Kosten nach gewähltem Profil | Allgemeine MR und kontextuelle MR trennen; Selbstanwendung und Gegenzauber sind eigene Profile. P1 | B: LC 214, 2194 |
| Blitz / `spell_blitz_dich_find` | ZfP* gleichmäßig von AT-/PA-Basis abziehen, ungerader Rest zuerst AT; FK-, Talent-, Zauberproben +ZfP* Erschwernis; INI −ZfW; Dauer ZfW/2 Aktionen | Empfangener Malus; Blindkampf/Konzentrationsstärke und Verbot von Orientieren berücksichtigen. P1 | B: LC 49, 1970 |
| Plumbumbarum / `spell_plumbumbarum_schwerer_arm` | AT und **INI-Basis** jeweils −ZfP* für 5 KR; Grundwirkung senkt keine PA | Einfacher Kampfmalus; Demotivationsvariante separat. P1 | B: LC 211, 2190 |
| Ängste lindern / `spell_aengste_lindern` | Wiederholung einer bestimmten Angst-/MU-Probe mit angepasstem Wert oder Aufhebung des zugehörigen Angstzuschlags | Verbrauchbarer, kontextbezogener Bonus; kein pauschales MU-Plus. P1 | B: LC 23, 1929 |
| Satuarias Herrlichkeit / `spell_satuarias_herrlichkeit` | Betören-Wert +ZfP*; weitere gesellschaftliche/CH-Proben situationsabhängig erleichtert; Interaktion mit Aussehen | Talentwertänderung und Probenmodifikator getrennt; passende Zielgruppe bestätigen. P2 | B: LC 224, 2205 |
| Hexenkrallen / `spell_hexenkrallen` | Temporäre natürliche Waffe 1W6+1 TP und Klettern-Erleichterung ZfP*/2; Laufzeit/Kosten; Variante mit Fußkrallen | Virtuelles Kampfmittel und Talentbonus ohne permanente Inventaränderung. P2 | B: LC 116, 2062 |
| Corpofrigo / `spell_corpofrigo_kaelteschock` | Einmalige ZfP* SP(A); zeitweilig −4 auf AT, PA/Ausweichen, INI, GE, FF, KK; Kälteempfindlichkeit/-resistenz verändert Stärke | Ressourcenereignis plus Dauerwirkung; direkte und abgeleitete Abzüge regelgetreu zusammensetzen, erneute Belegung nicht addieren. P2 | B: LC 60, 1988 |
| Corpofesso / `spell_corpofesso_gliederschmerz` | KK −ZfW/2, GE −ZfW/4, sofort Erschöpfung; Kampf trotz Wirkung mit weiteren AuP-/Erschöpfungsfolgen | Eigenschaftseffekt plus Handlungshinweis und Ereignisse; Erschöpfung bleibt nach Ende bestehen. P2 | B: LC 59, 1987 |
| Balsam / `spell_balsam_salabunde` | LeP-Heilung nach AsP, höchstens 2×ZfW; Wundheilung muss angesagt sein; Gift/Krankheit wird nicht beendet | Bestätigte Heiltransaktion mit getrenntem Zauberer/Empfänger; Sonderfälle Todesnähe/permanente AsP später. P2 | B: LC 37, 1951 |
| Ruhe Körper / `spell_ruhe_koerper_ruhe_geist` | Schlaf, stündliche besondere Regeneration und Erschöpfungsabbau, Wundheilung je 6 Stunden; ersetzt normale Regeneration | Rastprofil mit einmalig bestätigten Zeitabschnitten, keine Doppelregeneration. P2 | B: LC 220, 2200 |
| Movimento / `spell_movimento_dauerlauf` | Ausdauernder Lauf ohne AuP-/Erschöpfungsverlust; **keine höhere maximale GS**, Kampf in der Grundwirkung normal anstrengend | Aktivitätsfilter für Reise/Ausdauer; Kampfvariante ausdrücklich getrennt. P2 | B: LC 183, 2154 |
| Duplicatus / `spell_duplicatus_doppelbild` | Doppelgänger verändern Trefferwahrscheinlichkeit und gegnerische Parade; Zahl, Enge und Wahrnehmungsart relevant | Zusätzlicher bestätigter Trefferentscheid, kein einfacher PA-Bonus. P2 | B: LC 70, 2000 |
| Gardianum / `spell_gardianum_zauberschild` | Grundschild mit Kapazität investierte AsP +2×ZfP*, absorbiert passende direkte magische Angriffe; Ort/Ursprung und Variante entscheidend | Separater Schutzvorrat, kein RS; Gruppenkuppel braucht gemeinsame Instanz statt Vorrat pro Held. P2 für persönlichen Schutz, P3 für Gruppe | B: LC 92, 2031–2032 |
| Standfest / `spell_standfest_katzengleich` | Keine Nahkampfpatzer, bestimmte AT-/PA-Zuschläge um 4 erleichtert; nicht Wunden/BE; Bindung an geführte Waffe | Eingriff in Ansagen/Patzer und Endereignisse, kein pauschales AT/PA +4. P2 | B: LC 249, 2234 |
| Sensattacco / `spell_sensattacco_meisterstreich` | Erweiterter Bereich glücklicher Attacken aus vorheriger Ansage; Aufrechterhaltung | Wurfauswertung/Bestätigung erweitern, kein AT-Bonus; WdS-Regeln zusätzlich prüfen. P2 | B: LC 238, 2220 |
| Eiseskälte / `spell_eiseskaelte_kaempferherz` | RS ZfP*/5, ignorierte Wunden bis ZfP*/2, bestimmte Niedrig-LeP-Abzüge entfallen, SB gegen LeP-Verlust erleichtert; Folgekosten und Erschöpfung am Ende | Wunden nur unterdrücken, nicht heilen; Auswahl/Verteilung und Ende bestätigen; Meisterverwaltung verdeckter LeP gesondert. P3 | B: LC 78, 2011 |
| Horriphobus / `spell_horriphobus_schreckgestalt` | Gestaffelte Furcht; MU-Prüfung, erwürfelte Werteverluste und Rückzugs-/Fluchtbedingungen | Quellgebundener Zustand; Würfelergebnisse speichern und Abbau separat verfolgen. P3 | B: LC 121, 2067 |
| Somnigravis / `spell_somnigravis_tiefer_schlaf` | Grundwirkung nur auf ruhendes Ziel; Schlaf ohne Regeneration, Aufwecken durch Angriff/Schütteln; Ohnmacht im Kampf ist Variante | Zustand mit Auslösern, nicht generische AuP-Schwellenprüfung. P2 | B: LC 246, 2230 |
| Band und Fessel / `spell_band_und_fessel` | Gebiet kann nicht verlassen werden; MU-Befreiungsproben und kumulative MU-Verluste; Kämpfen am Rand und Schießen sind möglich | Räumliche Bindung und Probenprotokoll, **keine allgemeine Wehrlosigkeit**. P3 | B: LC 38, 1953 |
| Fulminictus / `spell_fulminictus_donnerkeil` | 2W6+ZfP* direkte SP, begrenzt durch AsP; gewöhnlicher RS/Armatrutz unwirksam, keine regeltechnischen Wunden | I: fremde Grundwirkung vorhanden; B: vorhandenes Profil absichern und Empfangspfad prüfen. P1 Bestand | B: LC 91, 2030 |
| Elementarpfeile / `spell_pfeil_*` (sechs IDs im Anhang) | Verzaubern reale Munition; Feuer hat Folgeschaden, Erz andere TP/Reichweite, Luft andere Reichweite/Windwirkung, Eis AuP-Verlust, Humus Fesselung, Wasser Unterwassereigenschaften | Munitionsgebundene Profile mit Treffer- und Endereignissen; keine gemeinsame Schadensformel. P3 | B: LC 208, 2186–2187 |

Bruchwerte in dieser Tabelle legen **keine Rundungsregel** fest. Vor jedem betroffenen Profil die allgemeinen Rundungsregeln und Ausnahmen belegen und in Grenzwerttests festhalten. ZfW und ZfP* dürfen nicht vertauscht werden; bei fremden Zaubern sind sie Werte des ursprünglichen Zaubernden.

## Weitere relevante Kandidaten

Die folgenden Familien sollten erfasst werden; ihre vollständigen Mechaniken sind hier **K**, nicht freigegebene Formeln. Jede Familie bekommt vor ihrer Umsetzung eine belegte Profilmatrix einschließlich Varianten und Endbedingungen.

| Familie | Beispiele aus dem aktuellen Katalog | Sinnvolle Integrationsart |
|---|---|---|
| Wahrnehmung und Tarnung | Katzenaugen, Warmes Blut, Oculus, Exposami, Pestilenz erspüren; Chamaelioni, Visibili, Unsichtbarer Jäger, Spurlos, Harmlose Gestalt | Sinn-/Sichtkontext und bedingte Probenbeiträge, Grenzen sichtbar machen; Unsichtbarkeit ist keine globale Unangreifbarkeit |
| Mobilität und Umwelt | Krötensprung, Spinnenlauf, Firnlauf, Wellenlauf, Wipfellauf, Wasseratem, Lunge des Leviatan, Nihilogravo, Solidirid, Transversalis | Bewegungs-/Atemfähigkeit, Reichweite, Last, Untergrund und Ereignisse; nur belegte GS-/Talentänderungen rechnen |
| Körper- und Elementarformen | Adlerschwinge, Salander, Serpentialis, Nebelleib, Leib der Erde/Wogen/Eis/Erz/Feuer/Wind, Seidenweich, Transmutare, Transformatio | Temporäres Formprofil mit Kampfmitteln, Sinnen, Resistenzen, erlaubter Ausrüstung; Originalbogen erhalten |
| Kontrolle und Schmerz | Paralysis, Vipernblick, Karnifilo, Höllenpein, Atemnot, Aerogelo, Zwingtanz, Lachkrampf, Böser Blick, Große Verwirrung/Gier, Imperavi, Zauberzwang | Zustand am betroffenen Helden, Handlungsgrenzen und Ende; bei narrativen Befehlen Meisterentscheidung statt automatisch ausgeführter Aktionen |
| Heilung und Ressourcen | Hexenspeichel, Klarum Purum, Leidensbund, Lach dich gesund, Magischer Raub, Levthans Feuer, Sumus Elixiere, Zaubernahrung; Heilkraft bannen | Ressourcen-/Gift-/Krankheits- oder Rastablauf; Heilung, Übertragung, Unterdrückung und tatsächliche Entfernung unterscheiden |
| Waffen, Ausrüstung und Schaden | Adamantium, Eisenrost, Hexengalle, Motoricus, Radau, Ecliptifactus; Faxius-/Sphaero-Familien, Kulminatio, Zorn der Elemente, Schwarz und Rot | Waffen-/Rüstungsinstanz oder separates Kampfmittel; TP, SP, SP(A), RS und Wundfähigkeit ausdrücklich profilieren |
| Soziale und geistige Effekte | Bannbaladin, Seidenzunge, Dichter und Denker, Memorans, Sensibar, Gedankenlesen, Erinnerungsänderung, Seelenwanderung | Bedingte Talent-/Probenboni oder klar gekennzeichneter Zustands-/Wissenshinweis; kein automatisches Entscheiden über NSC-Verhalten |
| Flächen und Schutz | Dunkelheit, Nebelwand, Silentium, Fortifex, Wände, Stillstand, Tempus Stasis, Invercano, Protectionis, Hexenknoten | Situationskontext mit Quelle/Zone; nicht als dauerhafter Eigenbonus speichern; Eintritt/Austritt bestätigen |
| Antimagie und Kombinationen | Einfluss bannen, Eigenschaft wiederherstellen, Beherrschung brechen, Verwandlung beenden, Veränderung aufheben, Schadenszauber bannen, Illusion auflösen, Reversalis, Unitatio, Infinitum | Passende Instanz beenden/unterdrücken; keine pauschale Löschung aller Effekte; Kombinationen nur mit belegtem eigenem Profil |
| Beschworene und erschaffene Wesen | Dschinnenruf, Elementarer Diener, Invocatio, Geisterruf, Skelettarius, Totes handle, Stein/Staub wandle, Hilfreiche Tatze, Weiße Mähn | Später vorhandene Begleiter/Gegner anbinden; Dienste und eigene Werte nicht in Heldenmodifikatoren hineinrechnen |

Alltags-, Objekt-, Informations- und reine Darstellungszauber bleiben zunächst als **N** in Katalog/Notiz nutzbar. Das heißt nicht „wirkungslos“: etwa Licht, entschärfte Nahrung oder ein geöffnetes Schloss können entscheidend sein, benötigen aber zuerst einen passenden Szenenkontext statt erfundener Charakterboni.

## Empfohlene Architektur

**Empfehlung:** Eine gemeinsame, quellenbezogene Effektverwaltung für den betroffenen Helden; numerische Profile schrittweise liefern. Ein globaler Simulator aller Zauber wäre zu groß. Nur neue Schalter in `importantActiveSpellEffects` würden wiederum Zielbindung, mehrere Quellen, Endereignisse und gegenseitige Unterdrückung nicht zuverlässig abbilden.

1. **Definition und Instanz trennen.** Definition: stabile Zauber-ID, Profil/Variante, Quelle/Regelversion, Eingabeschema, Ziel-/Kontextgrenzen und Endereignisse. Instanz: eigene ID, betroffener Charakter, optional Zaubernder, ZfW/ZfP*, bestätigte Zahlen/Würfe, Beginn/Restdauer, Bindung an Ziel/Waffe/Munition, Aktiv-/Unterdrückungsstatus. Fremde Herkunft darf unbekannt bleiben; keine erfundenen Werte.
2. **Keine Universalformel aus `amount`.** Typisierte Parameter je benötigtem Profil; gemeinsame Beiträge für Eigenschaften, Kampfwerte, Proben, Schutz, Sinne und Handlungsgrenzen. Rundung, Stacking und Ausnahmen im zuständigen Regelmodul. Eine Definition kann mehrere Beiträge und einmalige Ereignisse erzeugen.
3. **Basiswerte erhalten.** Effektbeiträge werden abgeleitet. Attributo darf beim Ende nicht künftig auch Corpofesso oder manuelle Boni löschen. Ereignisse wie Heilung, Schaden und Erschöpfung werden einmal gebucht und nicht mit jeder Snapshot-Neuberechnung wiederholt. Unterdrückte Wunden bleiben physisch vorhanden.
4. **Eine Herleitung.** `HeroComputedSnapshot`, Vorschau, Gefecht und Proben verwenden dieselben Beiträge und benannten Quellen. INI-Basis und fertige INI, Talentwert und Probenzuschlag, Schutzkapazität und RS bleiben unterschiedliche Größen. Keine Regelberechnungen in Widgets, Providern oder Modellen.
5. **Schreiben über vorhandene fachliche Aktionen.** Frischen Zustand laden; Probe, AsP-Kosten, Effekt und Ereignisse über vorhandene Operationsgrenzen koordinieren. Idempotente Vorgangs-/Ereignis-IDs verhindern Doppelbuchung bei Doppelklick, Retry und Neustart. Fremde Helden/Gruppenschilde benötigen ein eigenes Mehrzielkonzept; keine behauptete Atomarität zwischen beliebigen Repositories.
6. **Bedienung.** `+ Effekt` im Section-Header; eigener/fremder Ursprung, belegtes Profil, Eingaben, Vorschau, Dauer und Endbedingungen. Nach erfolgreicher Probe Effektübernahme anbieten; bloßer Probenwurf erzeugt noch keinen Effekt. Manuelle Meisterabweichung mit Begründung/Quelle getrennt kennzeichnen. Ungeprüfte Profile sind Hinweise ohne Zahlenautomatik.
7. **Zeit.** Kampfaktionen, Rundenwechsel und außer­kämpferische Zeitfortschritte sind explizite Ereignisse. Aktionsdauer darf nicht bei jedem KR-Wechsel um „eine Aktion“ sinken. Bestehenden Ablaufhinweis beibehalten; automatisches Ende, Kosten und Verbrauch erst nach festgelegter Ereignissemantik umsetzen. Laufende Kosten nie still auslösen oder erneut zahlen.

## Arbeitspakete für die spätere Umsetzung

Jedes Paket ist separat abnehmbar. Neue Dateinamen sind Vorschläge; vor Umsetzung auf bereits vorhandene Verantwortlichkeiten prüfen. Keine nebenbei durchgeführte Großbereinigung von `magic_rules.dart` oder Gefechtsdateien.

### MAG-EFF-01 – Quellenprofile und Bestandsabsicherung (P1)

**Umgesetzt am 14.10.2026** (siehe Prüfprotokoll unten).

- [x] Axxeleratus, Attributo, Armatrutz gegen LC und geltende Hausregeln prüfen; vorhandenen Fulminictus mit belegter Grundwirkung vergleichen. Repräsentation, Varianten, Rundung und zeitliche Regeln protokollieren. *(Protokoll unten; Abweichungen dokumentiert, nicht geändert.)*
- [x] Profildefinitionen in `lib/catalog/spell_effect_def.dart`; Metadaten als `assets/catalogs/house_rules_v1/spell_effects.json` mit Manifest-Schlüssel `spell_effects` (Reisebericht-Ladepfad: `CatalogSourceData.spellEffects`, `RulesCatalog.spellEffects`). Keine zweite Kopie des Zauberkatalogs, keine Wirkungstexte. Zehn Profile: vier Bestand, sechs belegt.
- [x] Validierung in `lib/rules/derived/spell_effect_profile_rules.dart`: Zauber-ID existiert, Quelle/Profilversion gesetzt, Bestandsprofile nennen ihre Umsetzung, `istAutomatisiert` schließt manuelle/unbekannte Profile von Zahlen aus.
- [x] Bestandstests ausgeführt. **Abnahme:** Kein bestehender Effekt verändert sein Verhalten (kein Produktcode der Effekte angefasst); unbekanntes Profil liefert keinen geratenen Zahlenbonus.

**Prüfprotokoll MAG-EFF-01 (DSA-MCP, Liber Cantiones, Buchseiten).**

| Effekt | LC / Chunk | Vergleich mit der App | Befund |
|---|---|---|---|
| Axxeleratus | S. 36, 1949 | PA-Basis +2, Ausweichen +2, TP +2, INI-Basis ×2 (ohne Rundung), GS ×2 nach BE, Schnellziehen/-laden stimmen | Abwehr eines beschleunigten Angriffs um 2 erschwert: **umgesetzt** als Kampfvorschau-Hinweis „Automatische Finte +2“ (`buildAxxeleratusDefenseHint`, getestet). **Nicht umgesetzt:** Athletik-TaW für Sprints/Sprünge verdoppelt (die App rechnet keine Sprint-/Sprungstrecken); Variante Blitzgeschwind (ab ZfW 11, Patzer ab 18) und Koboldisch. *Korrektur 14.10.2026: Die erste Fassung dieses Protokolls nannte die Abwehr-Erschwernis fälschlich als fehlend.* |
| Attributo | S. 30, 1940 | App nimmt einen freien Wert und rundet nicht | Regelwerk: Bonus = ZfP*/3 für 1 Stunde (Kosten 7 AsP); Rundung nicht belegt. Tier-/Pflanzen-Erschwernisse und Schnellsteigerung nicht umgesetzt. Quellenbezug erst mit MAG-EFF-02 |
| Armatrutz | S. 28, 1938 | Kosten `RS² − ZfP*/2` (abgerundet), Minimum 4 AsP, Dauer 1 SR, Behinderung 0, wirkt nicht gegen Fulminictus: stimmen | **Abweichung:** Regelwerk begrenzt den zusätzlichen RS auf ZfW/2; die App kennt nur den Eingaberiegel 12 (bewusst, ohne ZfW). Körperschild, Kraft des Fakirs nicht umgesetzt |
| Fulminictus | S. 91, 2030 | 2W6 + ZfP* direkte SP, AsP-Kappung, kein RS/Armatrutz | Nur Grundwirkung; Varianten offen |

Hausregeln wurden in diesem Paket nicht gegen die Hausregel-Quellen des MCP geprüft; die Profile tragen deshalb nur die LC-Grundregel. Jede Änderung der Bestandsformeln (z. B. ZfW/2-Grenze, Abwehr-Erschwernis) braucht einen gesonderten Regelauftrag.

**Automatisiert geprüft:** `flutter analyze` ohne Befund; `test/catalog/spell_effect_catalog_test.dart`, `test/rules/spell_effect_profile_rules_test.dart`, `test/data/catalog_loader_test.dart` (Manifest mit/ohne Schlüssel, doppelte IDs) sowie die Bestandstests zu Zaubereffekten, Armatrutz, Fulminictus, Magie-Regeln und Bestandshelden-Hashes grün.

### MAG-EFF-02 – Quellenbezogene Instanzen und sichere Speicherung

**Teilweise umgesetzt am 15.10.2026** (Kern; offene Punkte unten markiert).

- Umgesetzt: `SpellEffectInstance` (`lib/domain/spell_effect_instance.dart`) und `ActiveSpellEffectsState.instanzen` (nur bei Belegung im JSON; nicht verstandene Einträge bleiben roh erhalten). Die drei Legacy-IDs bleiben unverändert les- und schreibbar; sie erscheinen in `aktiveEffektInstanzen` als synthetische, nie gespeicherte Instanzen (`legacy:<id>`) — keine Migration, Bestandshelden-Hashes unverändert.
- `effektiveTempAttributeMods` (`spell_effect_instance_rules.dart`) ist die einzige Stelle, an der Zauberquellen Eigenschaften verändern: `tempAttributeMods` plus nicht unterdrückte Attributo-Instanzen; die Leser in Basiswerten, Kampf, Talent-/Kampf-Tab und Anzeige nutzen sie. Andere Profile speichern Instanzen, rechnen aber noch **keine** Zahlen (MAG-EFF-03).
- **Tischregel (Nutzerentscheidung 15.10.2026):** Mehrere Attributo dürfen gewirkt werden. Verbessern sie **dieselbe Eigenschaft**, zählt je Eigenschaft nur der **bessere** Wert (bei Gleichstand die erste Quelle); verschiedene Eigenschaften behalten alle Boni. Gilt auch für das Legacy-Attributo (seine Boni nehmen als eine Quelle teil); manuelle Boni ohne Legacy-Attributo kommen zusätzlich dazu. Die Regel liegt in `effektiveTempAttributeMods`, überlagerte Quellen nennt `ueberlagerteEigenschaften` (Anzeige „zählt nicht für …“). Für weitere Zauber mit Einfluss auf Eigenschaften ist dieselbe Regel das Muster (Profilbeleg in MAG-EFF-03 vorbehalten).
- **Aufrechterhaltung:** Der Katalog markiert sie in `duration` mit „(A)“ (60 von 288 Zaubern; Armatrutz und Axxeleratus ja, Attributo nein). `effektVerlangtAufrechterhaltung`/`aufrechterhaltungsBefund` (`spell_effect_instance_rules.dart`) zählen laufende, nicht unterdrückte Wirkungen einzeln; der Effektdialog zeigt den Hinweis, der Gefecht-Wirkdialog trägt die Zahl als **Vorschlag** in „Aufrechterhaltene Zauber“ ein (der Zuschlag 3 je Zauber, mit Simultanzaubern 1, WdZ 15 stand dort bereits; der Nutzer bestätigt am Tisch). Nicht abgedeckt: der Zuschlag außerhalb des Gefechts (Magie-Tab), Wirkungen allein über das alte Axxeleratus-Häkchen der Kampfeinstellungen, Konzentrationsverlust/Ende (MAG-EFF-04).
- Aktionen in `active_spell_state_rules.dart`: `aktiviereEffektInstanz` (idempotent über `id`/`vorgangsId`), `bearbeiteEffektInstanz`, `unterdrueckeEffektInstanz`, `beendeEffektInstanz`, `zaehleEffektInstanzDauer`, `uebernimmLegacyAttributoAlsInstanz`. Beenden einer Quelle entfernt nur sie.
- Legacy-Attributo: Beim Ausschalten fragt der Dialog, ob die gespeicherten Boni bleiben (Herkunft nicht erkennbar); „Alte Boni als eigene Quelle führen“ überführt sie bewusst in eine Instanz.
- **Noch offen:** Ereignis-/Verbrauchsaktion (`verbraucheEffektInstanz`, gehört zur Ereignissemantik von MAG-EFF-04); Armatrutz-Instanzen und profilabhängige Zusammenwirkung (stärkster Wert/Ersatz/Addition) — Zahlen erst nach Beleg in MAG-EFF-03; Gefecht-Wirkabschluss legt weiterhin die Legacy-Einträge an; Zwei-Geräte-/Export-Test mit echtem Sync steht aus; Verhalten älterer App-Versionen (sie ignorieren `instanzen`, erhalten es aber als unbekanntes Feld) ist nur durch Modelltests belegt.

- [ ] `lib/domain/active_spell_effects_state.dart`, `hero_state.dart`, `attribute_modifiers.dart` und `active_spell_state_rules.dart` prüfen; Instanzen in kleiner eigener Modelldatei ergänzen. Von den drei Legacy-IDs eindeutig migrieren; unbekannte IDs/Felder erhalten.
- [ ] Attributo-Beiträge von allgemeinen manuellen Eigenschaftsänderungen trennen. Bei unklarer Bestandsherkunft Werte erhalten und Zuordnung bestätigen lassen, statt einen zweiten Bonus aufzuschlagen.
- [ ] Aktivieren, Bearbeiten, Unterdrücken, Beenden und Verbrauch als kleine fachliche Aktionen über `lib/state/hero_actions.dart` anbinden. Instanz IDs und Ereignis IDs getrennt führen.
- [ ] JSON-, Hive-/Export-/Import-, Kopier-, Neustart- und Zwei-Geräte-Fälle prüfen; zwei gleiche Zauberquellen müssen getrennt sichtbar sein, Zusammenwirkung folgt dem Profil statt allgemeinem Addieren.
- [ ] **Abnahme:** Ende von Quelle A entfernt nur A; unbekannte Bestandsdaten überleben Speichern; Retry erzeugt keinen zweiten Effekt. Alte Daten bleiben lesbar. Verhalten älterer App-Versionen explizit prüfen, nicht aus dem Erhalt unbekannter Felder ableiten.

### MAG-EFF-03 – Proben- und Kampfbeiträge (erster nutzbarer Ausbau)

**Teilstand 1 (15.10.2026): empfangene Kampf-Mali Blitz und Plumbumbarum umgesetzt**, Probenbeiträge (Adlerauge, Falkenauge, Psychostabilis, Blitz-Probenzuschlag, Ängste lindern) folgen.

- `spell_effect_combat_rules.dart`: `berechneSpellEffectKampfBeitraege` rechnet aus den Instanzen (`zfpStern`, `zfw`) und belegten Profilen. **Blitz** (LC S. 49): ZfP* gleichmäßig von AT- und PA-**Basis**, ungerader Rest zuerst AT; Helden-**INI** −ZfW (nicht INI-Basis, deshalb als eigener Herleitungsschritt in `herleiteHeldenIni`, Untergrenze 0 bleibt); „Orientieren“ gesperrt (Hinweis im Effektdialog). **Plumbumbarum** (LC S. 211): AT-Basis und INI-**Basis** je −ZfP*, keine PA. Die Beiträge laufen als benannte Quellen durch `sammleStatModifikatorQuellen` → Basiswert-Herleitung → Kampfvorschau und Gefecht (eine Rechenstelle, Herkunft sichtbar).
- **Blindkampf** halbiert laut Regelwerk die Blitz-Abzüge; die Rundung ist nicht belegt, deshalb rechnet die App dann **nichts** und zeigt einen Hinweis (Abzüge manuell eintragen). Konzentrationsstärke betrifft nur Zauberproben (Probenpaket).
- **Mehrere Quellen**: derselbe Zauber – nur die stärkste (größtes ZfP*) zählt, verschiedene Zauber addieren sich (Annahme in Anlehnung an die Tischregel, bitte bestätigen); unterdrückte Instanzen zählen nicht. Fehlende ZfP*/ZfW melden einen Hinweis statt einer geratenen Zahl.
- Bedienung: Effektdialog → „Zauberwirkung hinzufügen“ (`spell_effect_input_dialog.dart`, Werte des Zaubernden, optionale Quelle); Beenden/Unterdrücken je Quelle wie bei Attributo.
- Offen: Dauer/Ablauf (MAG-EFF-04), Demotivationsvariante, Chips in der Spielansicht.

**Teilstand 2 (15.10.2026): Probenbeiträge und MR.** Adlerauge (LC S. 15), Blitz-Probenzuschlag und Psychostabilis (LC S. 214) sind umgesetzt; Falkenauge und Ängste lindern (einmaliger, zielgebundener Verbrauch) folgen mit der Ereignissemantik von MAG-EFF-04.

- **Adlerauge**: Proben auf das Talent Sinnesschärfe (Katalogname; das Regelwerk schreibt „Sinnenschärfe“) um ZfP* erleichtert; kein anderes Talent, keine Nachtsicht; Einzelsinn-Variante nicht umgesetzt. Aufrechterhalten („(A)“) wird über den bestehenden Hinweis angezeigt.
- **Blitz**: Talent- und Zauberproben um ZfP* erschwert. Konzentrationsstärke halbiert die Abzüge auf Zauberproben (Rundung nicht belegt → Hinweis, keine Zahl), Blindkampf halbiert alles (→ Hinweis, App rechnet nichts). **Fernkampfproben** erschwert die App noch nicht selbst (Hinweis im Effektdialog).
- **Psychostabilis**: MR +ZfP* als benannte Quelle der MR-Herleitung; das zusätzliche +2 gegen Einfluss/Hellsicht/Herrschaft/Verständigung steht als Hinweis (kontextuelle MR, nicht in der Basis-MR). Selbstanwendung, kleine Stabilisierung und Gegenzauber sind eigene Profile und nicht umgesetzt.
- **Wie die Zahlen in die Probe kommen**: `spell_effect_probe_rules.dart` wählt aus `DerivedStats.zauberEffekte.probenBeitraege`, was zur Probe passt (Art, bei Talenten der Name aus dem Titel `Talentprobe: X`), und setzt es als **Startwert des situativen Modifikators** mit Hinweistext (`probeMitSpellEffekten`). Zentral in `showLoggedProbeDialog` (alle Talent-/Zauberproben des Helden; Vertraute melden `zaubereffekteAnwenden: false`) und `zeigeGefechtsprobe` (nur Talentproben); Gefecht-Zauberproben bekommen Blitz über `gefechtsZauberZuschlag`. Der Nutzer kann den Wert im Dialog ändern.

- [ ] Neue kleine Regelmodule `spell_effect_probe_rules.dart` und `spell_effect_combat_rules.dart` unter `lib/rules/derived/`; Einbindung in `hero_computed_snapshot.dart`, `probe_request_rules.dart`, passende Kampfherleitungen und Gefechtsregeln.
- [ ] Erste Profile: **Adlerauge, Falkenauge, Psychostabilis, Blitz, Plumbumbarum, Ängste lindern**. UI unter `lib/ui/screens/shared/active_spell_effects_dialog.dart` bzw. bestehender UI2-Anbindung erweitern; Beschreibungen aus demselben Profil.
- [ ] Konkrete Testfälle: Falkenauge ZfP*=6 wirkt nur auf das festgelegte Ziel und verfällt nach dem bestätigten Schuss; Adlerauge wirkt nicht auf Klettern; Psychostabilis ZfP*=5 ergibt +5 allgemeine MR und +7 im passenden geistigen Kontext.
- [ ] Blitz ZfP*=5 verteilt −3 AT-/−2 PA-Basis; INI-Malus kommt aus ZfW. Blindkampf/Konzentrationsstärke, Rundung und zusätzliche Wund-/BE-Einflüsse testen. Plumbumbarum ZfP*=6: AT und INI-Basis −6, PA bleibt ohne direkten Plumbumbarum-Abzug.
- [ ] Neue Tests: `test/rules/spell_effect_probe_rules_test.dart`, `spell_effect_combat_rules_test.dart`; vorhandene Dialog-/Gefechts-/Herleitungstests ergänzen. **Abnahme:** gleicher Kontext liefert in Vorschau, Gefecht und Probe gleiche Beiträge; Herkunft sichtbar, keine doppelte Modifikation.

### MAG-EFF-04 – Zeit, Handlungsgrenzen und verbrauchbare Wirkungen

**Teilweise umgesetzt am 15.10.2026** (verbrauchbare Wirkungen und Dauern; Rest unten).

- **Falkenauge** (LC S. 84) – `spell_effect_event_rules.dart`: Die Instanz trägt ein **Ziel** (`SpellEffectInstance.ziel`, Name des Gegners oder `gegner:<ID>`) und ZfP*. Im Gefecht erleichtert sie den Fernkampfangriff auf genau dieses Ziel um ZfP* (benannter Anteil „Falkenauge (Zaubereffekt)“ in `pruefeGefechtsaktion`, über `pruefeGefechtAuftrag` also identisch in Anzeige und Ausführung). Ohne erfassten Kontakt, bei anderem Ziel, unterdrückt oder ohne ZfP* gibt es keinen Anteil. Mehrere passende Quellen: nur die stärkste. **Verbrauch**: nach dem bestätigten Wurf (Treffer oder Fehlschuss) beendet `fuehreGefechtsAuftragAus` genau diese Instanz (`beendeEffektInstanz`, idempotent über die ID); bei Speicherfehler erscheint ein Hinweis, der Nutzer kann die Wirkung im Effektdialog selbst beenden. Die Variante „bleibendes Band“ ist nicht umgesetzt; Fernkampfproben außerhalb des Gefechts bekommen den Anteil nicht.
- **Ängste lindern** (LC S. 23): Im Effektdialog setzt „In Mut-Probe einsetzen“ die Wirkung in einer wiederholten Mut-Probe ein (MU +ZfP*, als Startwert des situativen Modifikators; der Nutzer entscheidet, dass es eine Angstprobe ist, es gibt kein pauschales MU-Plus). Die Wirkung ist **verbraucht**, sobald die Probe ausgewertet wurde; Schließen des Dialogs ohne Wurf behält sie. Die Aufhebung eines Angstzuschlags auf Talentproben bleibt Handarbeit.
- **Wirkungsdauer**: Die Instanz trägt wie die Legacy-Effekte eine `SpellDuration`. Beim Hinzufügen schlägt die App nur **eindeutig belegte** Dauern vor (`dauerVorschlag`: Plumbumbarum 5 KR, Adlerauge 1 SR, Falkenauge ZfW KR); Blitz (ZfW/2 Aktionen, Rundung unbelegt) und Psychostabilis („nach AsP“) setzt der Nutzer selbst. An jeder Quelle lässt sich die Dauer festlegen und herunterzählen; Abgelaufenes wird rot markiert („Ende am Tisch bestätigen“), **nie automatisch beendet** und rechnet bis zum Beenden weiter.
- **Bewusst nicht umgesetzt** (kein Verhalten, das daran hinge, bzw. unbelegt): protokollierte Ende-Gründe (Konzentrationsverlust, Waffenwechsel, Angriff/Wecken, Zielwechsel, Antimagie) – sie bräuchten ein Ereignisprotokoll am Helden (Entscheidung offen); laufende Kosten (z. B. Psychostabilis 1 AsP/SR) und die Entscheidung bei fehlenden AsP; Somnigravis, Standfest und Sensattacco (Ereignis-/Wurfauswertung nicht belegt); automatischer Countdown beim Rundenwechsel.

- [ ] `spell_duration_rules.dart`, `gefecht_wirken_rules.dart`, `gefecht_wirkabschluss.dart` und Runden-/Aktionsübergänge prüfen; neues `spell_effect_event_rules.dart` für bestätigte End-/Verbrauchsereignisse.
- [ ] Konzentrationsverlust, Waffenwechsel, Angriff/Wecken, Zielwechsel, Ablauf und Antimagie als unterscheidbare Gründe. Somnigravis-Grundwirkung, Standfest und Sensattacco erst mit belegter Ereignis-/Wurfauswertung integrieren.
- [ ] Testfälle: Schlaf verhindert normale Regeneration; Angriff weckt passend zum Profil; Grund-Somnigravis kann nicht ohne Variante als Kampf-Ohnmacht gewählt werden. Standfest reduziert Manöverzuschläge, nicht BE/Wunden; Waffenverlust beendet ihn.
- [ ] Laufende Kosten bei bestätigtem Fortschritt genau einmal buchen; bei fehlenden AsP Entscheidung anbieten, keine negativen Ressourcen erzwingen. **Abnahme:** abgebrochene/fehlgeschlagene Speicherung und Retry verändern weder Restdauer noch Ressourcen doppelt.

### MAG-EFF-05 – Schutz, Heilung und anhaltende Folgeschäden

- [ ] `schaden_rules.dart`, `schaden_ruecknahme_rules.dart`, `gefecht_fremdwirkung_rules.dart` und bestehenden Rastablauf anbinden. Separate kleine Module `spell_effect_protection_rules.dart` und `spell_effect_healing_rules.dart` vorsehen.
- [ ] Balsam/Hexenspeichel/Klarum Purum nach jeweiliger Detailprüfung; Ruhe Körper als eigenes Rastprofil; persönlichen Gardianum mit Kapazitätsverbrauch und Duplicatus-Trefferentscheid integrieren. Gruppenkuppel bleibt eigener Folgescope.
- [ ] Testfälle: Gardianum fängt nur passende Angriffe ab; Kapazität schrumpft einmal; Fulminictus ignoriert Armatrutz, wird aber vom passenden Schutzprofil geprüft. Balsam ohne angesagte Wundheilung entfernt keine Wunde und beendet keine Vergiftung.
- [ ] Ruhe Körper verwendet besondere statt zusätzlicher normaler Regeneration. Zauberer bezahlt Kosten, Empfänger erhält Heilung; fremde Quelle ohne bekannte Kosten führt nicht zum AsP-Abzug beim Empfänger.
- [ ] **Abnahme:** Schutz, Heilung und Folgeticks besitzen gespeicherte Ereigniswerte; Rücknahme ist nachvollziehbar; nach Neustart kein erneutes Würfeln oder Buchen bereits abgeschlossener Ereignisse.

### MAG-EFF-06 – Formen, Ausrüstung, Zonen und komplexe Zustände

- [ ] Hexenkrallen als erstes temporäres Kampfmittel, anschließend sechs Elementarpfeilprofile mit tatsächlicher Munitionsbindung. `inventory_sync_rules.dart` nur ändern, wenn die gewählte Instanzbindung dies verlangt; keine dauerhafte Änderung des Waffen-Templates.
- [ ] Eiseskälte, Horriphobus, Band und Fessel, Formen und Elementarleiber in getrennte Folgespezifikationen aufteilen. Vorschläge: `spell_effect_form_rules.dart`, `spell_effect_condition_rules.dart`, `spell_effect_equipment_rules.dart`.
- [ ] Testfälle: Eiseskälte unterdrückt nur bestätigte Wunden, erhält die Wunden selbst und lässt ihre Folgen nach Ende wieder wirken; Folgeschaden/Erschöpfung bleibt. Humuspfeil bindet, Luftpfeil verändert Reichweite; kein Profil erbt automatisch die Formel eines anderen Elements.
- [ ] **Abnahme:** Wechsel/Entfernung von Ausrüstung, Verlassen einer Zone und Ende einer Form hinterlassen weder Phantomwaffen noch verlorene Basiswerte. Beschworene Wesen und gemeinsame Gruppeneffekte haben eigene Zustandsbesitzer.

## Entscheidungen vor dem jeweiligen Paket

- **Ende:** weiter Hinweis + Bestätigung oder automatisches Ende bei eindeutigem Ereignis? Empfehlung: zunächst Bestätigung beibehalten und Ereignisfolge protokollieren.
- **Mehrere Quellen:** je Profil belegen, ob stärkste Wirkung, Ersatz, Addition oder Verbot gilt. Empfehlung: keine globale „alle Boni addieren“-Regel.
- **Bedienumfang:** Empfehlung: manuell empfangene Effekte und Selbstwirkungen zuerst; Zielheldübertragung/Gruppenschilde danach mit eigener Operations- und Berechtigungsgrenze.
- **Verdeckte Informationen:** Eiseskälte benötigt für regelgetreue verdeckte LeP eine Meisteransicht/Rechteentscheidung. Bis dahin keine scheinbar vollständig automatisierte Umsetzung.
- **Regelprofil:** LC-Grundregel, Hausregel und Meisterabweichung sichtbar unterscheiden; Voraussetzungen für Varianten aus der tatsächlichen Repräsentation ableiten.

## Prüfung und Übergabe

Vor jedem Produktpaket: `git status`, gezielter Diff, aktueller Katalog und passende Quellen; Nutzerarbeit erhalten. Danach `flutter analyze` und relevante Tests, dokumentierte Abnahme und eigener gezielter Commit gemäß [AGENTS.md](../AGENTS.md). Mempalace nach Duplikatprüfung aktualisieren.

Bestehende Prüfbasis:

```powershell
flutter analyze
flutter test test/domain/active_spell_effects_state_test.dart test/rules/active_spell_state_rules_test.dart test/rules/spell_duration_rules_test.dart test/rules/magic_rules_test.dart
flutter test test/rules/gefecht_wirken_rules_test.dart test/rules/gefecht_fremdwirkung_rules_test.dart test/ui/shared/active_spell_effects_dialog_test.dart test/ui2/spielen/gefecht_zauberablauf_test.dart test/ui2/spielen/gefecht_fremdwirkung_test.dart
```

Neue Pakete benötigen die oben genannten zusätzlichen Verhaltenstests, 320-Pixel-Ansichten mit 2× Textgröße sowie Persistenz-/Sync-Tests. Testläufe seriell ausführen. README, CLAUDE, Roadmap und betroffene Fachanleitungen im selben Paket aktualisieren; die technische Gesamtdokumentation beschreibt erst nach Umsetzung neues Laufzeitverhalten.

**Prüfung dieses Dokumentationsauftrags am 14.10.2026:** `flutter analyze` ohne Befunde; 79 Tests aus den neun oben genannten Testdateien erfolgreich. Die Matrix wurde auf exakt 288 eindeutige IDs und vollständige Übereinstimmung mit dem Katalog geprüft; relative Links im Plan wurden auf existierende Ziele geprüft. Keine vollständige Testsuite und keine praktische Bedienprüfung durchgeführt. Die Prüfungen liefen auf dem vorhandenen Worktree einschließlich bereits vorhandener fremder Änderungen; dieser Auftrag verändert keine Dart-Dateien.

**Empfohlener nächster Umsetzungsauftrag:** MAG-EFF-01 spezifizieren und danach MAG-EFF-02/03 als getrennte Lieferungen. Ein erster spielbarer Ausbau umfasst Adlerauge, Falkenauge, Psychostabilis, Blitz und Plumbumbarum; die komplexeren P2/P3-Wirkungen bleiben einzeln abnehmbar.

## Anhang – vollständiges Katalog-Screening

Die folgende Matrix erfasst jede der 288 Katalog-IDs genau einmal. **Gruppe** beschreibt den zuerst zu prüfenden Integrationsweg, nicht alle Wirkungen eines Spruchs: BEST (Bestand), PROBE, KAMPF, ZUSTAND, HEILUNG, MOBIL, SINNE, FORM, WAFFE, ZONE, ANTI, WESEN, KOMBINATION oder NOTIZ. Bei K/N ist vor Zahlenautomatik eine Volltextprüfung erforderlich; eine Einstufung als NOTIZ schließt relevante Varianten nicht aus.

| Katalog-ID | Zauber | Gruppe | Status |
|---|---|---|---|
| `spell_abvenenum_reine_speise` | Abvenenum reine Speise | NOTIZ | N |
| `spell_accuratum_zaubernadel` | Accuratum Zaubernadel | NOTIZ | N |
| `spell_adamantium_erzstruktur` | Adamantium Erzstruktur | WAFFE | K |
| `spell_adlerauge_luchsenohr` | Adlerauge Luchsenohr | PROBE | B |
| `spell_adlerschwinge_wolfsgestalt` | Adlerschwinge Wolfsgestalt | FORM | K |
| `spell_aengste_lindern` | Ängste lindern | PROBE | B |
| `spell_aeolitus_windgebraus` | Aeolitus Windgebraus | ZONE | K |
| `spell_aerofugo_vakuum` | Aerofugo Vakuum | ZONE | K |
| `spell_aerogelo_atemqual` | Aerogelo Atemqual | ZUSTAND | K |
| `spell_alpgestalt` | Alpgestalt | ZUSTAND | K |
| `spell_analys_arcanstruktur` | Analys Arcanstruktur | NOTIZ | N |
| `spell_animatio_stummer_diener` | Animatio stummer Diener | WESEN | K |
| `spell_applicatus_zauberspeicher` | Applicatus Zauberspeicher | KOMBINATION | K |
| `spell_aquafaxius` | Aquafaxius | WAFFE | K |
| `spell_aquasphaero` | Aquasphaero | WAFFE | K |
| `spell_arachnea_krabbeltier` | Arachnea Krabbeltier | ZONE | K |
| `spell_arcanovi_artefakt` | Arcanovi Artefakt | KOMBINATION | K |
| `spell_archofaxius` | Archofaxius | WAFFE | K |
| `spell_archosphaero` | Archosphaero | WAFFE | K |
| `spell_armatrutz` | Armatrutz | BEST | I |
| `spell_atemnot` | Atemnot | ZUSTAND | K |
| `spell_attributo` | Attributo | BEST | I |
| `spell_aufgeblasen_abgehoben` | Aufgeblasen Abgehoben | MOBIL | K |
| `spell_auge_des_limbus` | Auge des Limbus | ZONE | K |
| `spell_aureolus_gueldenglanz` | Aureolus Güldenglanz | NOTIZ | N |
| `spell_auris_nasus_oculus` | Auris Nasus Oculus | ZONE | K |
| `spell_axxeleratus_blitzgeschwind` | Axxeleratus Blitzgeschwind | BEST | I |
| `spell_baerenruhe_winterschlaf` | Bärenruhe Winterschlaf | ZUSTAND | K |
| `spell_balsam_salabunde` | Balsam Salabunde | HEILUNG | B |
| `spell_band_und_fessel` | Band und Fessel | ZUSTAND | B |
| `spell_bannbaladin` | Bannbaladin | ZUSTAND | K |
| `spell_beherrschung_brechen` | Beherrschung brechen | ANTI | K |
| `spell_beschwoerung_vereiteln` | Beschwörung vereiteln | ANTI | K |
| `spell_bewegung_stoeren` | Bewegung stören | ANTI | K |
| `spell_blendwerk` | Blendwerk | ZONE | K |
| `spell_blick_aufs_wesen` | Blick aufs Wesen | NOTIZ | N |
| `spell_blick_durch_fremde_augen` | Blick durch fremde Augen | SINNE | K |
| `spell_blick_in_die_gedanken` | Blick in die Gedanken | NOTIZ | N |
| `spell_blick_in_die_vergangenheit` | Blick in die Vergangenheit | NOTIZ | N |
| `spell_blitz_dich_find` | Blitz dich find | KAMPF | B |
| `spell_boeser_blick` | Böser Blick | ZUSTAND | K |
| `spell_brenne_toter_stoff` | Brenne toter Stoff! | WAFFE | K |
| `spell_caldofrigo_heiss_und_kalt` | Caldofrigo heiß und kalt | ZONE | K |
| `spell_chamaelioni_mimikry` | Chamaelioni Mimikry | SINNE | K |
| `spell_chimaeroform_hybridgestalt` | Chimaeroform Hybridgestalt | FORM | K |
| `spell_chronoklassis_urfossil` | Chronoklassis Urfossil | NOTIZ | N |
| `spell_chrononautos_zeitenfahrt` | Chrononautos Zeitenfahrt | NOTIZ | N |
| `spell_claudibus_clavistibor` | Claudibus Clavistibor | NOTIZ | N |
| `spell_corpofesso_gliederschmerz` | Corpofesso Gliederschmerz | KAMPF | B |
| `spell_corpofrigo_kaelteschock` | Corpofrigo Kälteschock | KAMPF | B |
| `spell_cryptographo_zauberschrift` | Cryptographo Zauberschrift | NOTIZ | N |
| `spell_custodosigil_diebesbann` | Custodosigil Diebesbann | WAFFE | K |
| `spell_daemonenbann` | Dämonenbann | ANTI | K |
| `spell_delicioso_gaumenschmaus` | Delicioso Gaumenschmaus | NOTIZ | N |
| `spell_desintegratus_pulverstaub` | Desintegratus Pulverstaub | WAFFE | K |
| `spell_destructibo_arcanitas` | Destructibo Arcanitas | ANTI | K |
| `spell_dichter_und_denker` | Dichter und Denker | PROBE | K |
| `spell_dschinnenruf` | Dschinnenruf | WESEN | K |
| `spell_dunkelheit` | Dunkelheit | ZONE | K |
| `spell_duplicatus_doppelbild` | Duplicatus Doppelbild | KAMPF | B |
| `spell_ecliptifactus_schattenkraft` | Ecliptifactus Schattenkraft | WAFFE | K |
| `spell_eigenschaft_wiederherstellen` | Eigenschaft wiederherstellen | ANTI | K |
| `spell_eigne_aengste_quaelen_dich` | Eigne Ängste quälen dich! | ZUSTAND | K |
| `spell_einfluss_bannen` | Einfluss bannen | ANTI | K |
| `spell_eins_mit_der_natur` | Eins mit der Natur | PROBE | K |
| `spell_eisenrost_und_patina` | Eisenrost und Patina | WAFFE | K |
| `spell_eiseskaelte_kaempferherz` | Eiseskälte Kämpferherz | KAMPF | B |
| `spell_elementarbann` | Elementarbann | ANTI | K |
| `spell_elementarer_diener` | Elementarer Diener | WESEN | K |
| `spell_elfenstimme_floetenton` | Elfenstimme Flötenton | NOTIZ | N |
| `spell_erinnerung_verlasse_dich` | Erinnerung verlasse dich! | ZUSTAND | K |
| `spell_exposami_lebenskraft` | Exposami Lebenskraft | SINNE | K |
| `spell_falkenauge_meisterschuss` | Falkenauge Meisterschuss | PROBE | B |
| `spell_favilludo_funkentanz` | Favilludo Funkentanz | ZONE | K |
| `spell_firnlauf` | Firnlauf | MOBIL | K |
| `spell_flim_flam_funkel` | Flim Flam Funkel | ZONE | K |
| `spell_fluch_der_pestilenz` | Fluch der Pestilenz | ZUSTAND | K |
| `spell_foramen_foraminor` | Foramen Foraminor | NOTIZ | N |
| `spell_fortifex_arkane_wand` | Fortifex arkane Wand | ZONE | K |
| `spell_frigifaxius` | Frigifaxius | WAFFE | K |
| `spell_frigisphaero` | Frigisphaero | WAFFE | K |
| `spell_fulminictus_donnerkeil` | Fulminictus Donnerkeil | BEST | B + I |
| `spell_gardianum_zauberschild` | Gardianum Zauberschild | KAMPF | B |
| `spell_gedankenbilder_elfenruf` | Gedankenbilder Elfenruf | NOTIZ | N |
| `spell_gefaess_der_jahre` | Gefäß der Jahre | FORM | K |
| `spell_gefunden` | Gefunden! | NOTIZ | N |
| `spell_geisterbann` | Geisterbann | ANTI | K |
| `spell_geisterruf` | Geisterruf | WESEN | K |
| `spell_gletscherwand` | Gletscherwand | ZONE | K |
| `spell_granit_und_marmor` | Granit und Marmor | FORM | K |
| `spell_grosse_gier` | Große Gier | ZUSTAND | K |
| `spell_grosse_verwirrung` | Große Verwirrung | ZUSTAND | K |
| `spell_halluzination` | Halluzination | ZUSTAND | K |
| `spell_harmlose_gestalt` | Harmlose Gestalt | SINNE | K |
| `spell_hartes_schmelze` | Hartes schmelze! | NOTIZ | N |
| `spell_haselbusch_und_ginsterkraut` | Haselbusch und Ginsterkraut | NOTIZ | N |
| `spell_heilkraft_bannen` | Heilkraft bannen | ANTI | K |
| `spell_hellsicht_trueben` | Hellsicht trüben | ANTI | K |
| `spell_herbeirufung_vereiteln` | Herbeirufung vereiteln | ANTI | K |
| `spell_herr_ueber_das_tierreich` | Herr über das Tierreich | WESEN | K |
| `spell_herzschlag_ruhe` | Herzschlag ruhe! | ZUSTAND | K |
| `spell_hexenblick` | Hexenblick | NOTIZ | N |
| `spell_hexengalle` | Hexengalle | WAFFE | K |
| `spell_hexenholz` | Hexenholz | WAFFE | K |
| `spell_hexenknoten` | Hexenknoten | ZONE | K |
| `spell_hexenkrallen` | Hexenkrallen | WAFFE | B |
| `spell_hexenspeichel` | Hexenspeichel | HEILUNG | K |
| `spell_hilfreiche_tatze_rettende_schwinge` | Hilfreiche Tatze, rettende Schwinge | WESEN | K |
| `spell_hoellenpein_zerreisse_dich` | Höllenpein zerreiße dich! | ZUSTAND | K |
| `spell_holterdipolter` | Holterdipolter | ZONE | K |
| `spell_horriphobus_schreckgestalt` | Horriphobus Schreckgestalt | ZUSTAND | B |
| `spell_humofaxius` | Humofaxius | WAFFE | K |
| `spell_humosphaero` | Humosphaero | WAFFE | K |
| `spell_ignifaxius` | Ignifaxius | WAFFE | K |
| `spell_ignisphaero` | Ignisphaero | WAFFE | K |
| `spell_ignorantia_ungesehn` | Ignorantia Ungesehn | SINNE | K |
| `spell_illusion_aufloesen` | Illusion auflösen | ANTI | K |
| `spell_immortalis_lebenszeit` | Immortalis Lebenszeit | FORM | K |
| `spell_imperavi_handlungszwang` | Imperavi Handlungszwang | ZUSTAND | K |
| `spell_impersona_maskenbild` | Impersona Maskenbild | FORM | K |
| `spell_infinitum_immerdar` | Infinitum Immerdar | KOMBINATION | K |
| `spell_invercano_spiegeltrick` | Invercano Spiegeltrick | KAMPF | K |
| `spell_invocatio_maior` | Invocatio maior | WESEN | K |
| `spell_invocatio_minor` | Invocatio minor | WESEN | K |
| `spell_iribaars_hand` | Iribaars Hand | WAFFE | K |
| `spell_juckreiz_daemlicher` | Juckreiz, dämlicher! | ZUSTAND | K |
| `spell_karnifilo_raserei` | Karnifilo Raserei | ZUSTAND | K |
| `spell_katzenaugen` | Katzenaugen | SINNE | K |
| `spell_klarum_purum` | Klarum Purum | HEILUNG | K |
| `spell_klickeradomms` | Klickeradomms | NOTIZ | N |
| `spell_koboldgeschenk` | Koboldgeschenk | ZUSTAND | K |
| `spell_koboldovision` | Koboldovision | SINNE | K |
| `spell_koerperlose_reise` | Körperlose Reise | MOBIL | K |
| `spell_komm_kobold_komm` | Komm Kobold Komm | WESEN | K |
| `spell_krabbelnder_schrecken` | Krabbelnder Schrecken | ZUSTAND | K |
| `spell_kraehenruf` | Krähenruf | WESEN | K |
| `spell_kraft_des_erzes` | Kraft des Erzes | ZONE | K |
| `spell_kroetensprung` | Krötensprung | MOBIL | K |
| `spell_kulminatio_kugelblitz` | Kulminatio Kugelblitz | WAFFE | K |
| `spell_kusch` | Kusch! | ZUSTAND | K |
| `spell_lach_dich_gesund` | Lach dich gesund | HEILUNG | K |
| `spell_lachkrampf` | Lachkrampf | ZUSTAND | K |
| `spell_langer_lulatsch` | Langer Lulatsch | ZUSTAND | K |
| `spell_last_des_alters` | Last des Alters | ZUSTAND | K |
| `spell_leib_der_erde` | Leib der Erde | FORM | K |
| `spell_leib_der_wogen` | Leib der Wogen | FORM | K |
| `spell_leib_des_eises` | Leib des Eises | FORM | K |
| `spell_leib_des_erzes` | Leib des Erzes | FORM | K |
| `spell_leib_des_feuers` | Leib des Feuers | FORM | K |
| `spell_leib_des_windes` | Leib des Windes | FORM | K |
| `spell_leidensbund` | Leidensbund | HEILUNG | K |
| `spell_levthans_feuer` | Levthans Feuer | HEILUNG | K |
| `spell_limbus_versiegeln` | Limbus versiegeln | ANTI | K |
| `spell_lockruf_und_feenfuesse` | Lockruf und Feenfüße | MOBIL | K |
| `spell_lunge_des_leviatan` | Lunge des Leviatan | MOBIL | K |
| `spell_madas_spiegel` | Madas Spiegel | SINNE | K |
| `spell_magischer_raub` | Magischer Raub | HEILUNG | K |
| `spell_mahlstrom` | Mahlstrom | ZONE | K |
| `spell_manifesto_element` | Manifesto Element | NOTIZ | N |
| `spell_meister_der_elemente` | Meister der Elemente | WESEN | K |
| `spell_meister_minderer_geister` | Meister minderer Geister | WESEN | K |
| `spell_memorabia_falsifir` | Memorabia Falsifir | ZUSTAND | K |
| `spell_memorans_gedaechtniskraft` | Memorans Gedächtniskraft | PROBE | K |
| `spell_menetekel_flammenschrift` | Menetekel Flammenschrift | NOTIZ | N |
| `spell_metamagie_neutralisieren` | Metamagie neutralisieren | ANTI | K |
| `spell_metamorpho_gletscherform` | Metamorpho Gletscherform | NOTIZ | N |
| `spell_motoricus` | Motoricus | WAFFE | K |
| `spell_movimento_dauerlauf` | Movimento Dauerlauf | MOBIL | B |
| `spell_murks_und_patz` | Murks und Patz | ZUSTAND | K |
| `spell_nackedei` | Nackedei | WAFFE | K |
| `spell_nebelleib` | Nebelleib | FORM | K |
| `spell_nebelwand_und_morgendunst` | Nebelwand und Morgendunst | ZONE | K |
| `spell_nekropathia_seelenreise` | Nekropathia Seelenreise | NOTIZ | N |
| `spell_nihilogravo_schwerelos` | Nihilogravo Schwerelos | MOBIL | K |
| `spell_nuntiovolo_botenvogel` | Nuntiovolo Botenvogel | WESEN | K |
| `spell_objecto_obscuro` | Objecto Obscuro | NOTIZ | N |
| `spell_objectofixo` | Objectofixo | NOTIZ | N |
| `spell_objectovoco` | Objectovoco | NOTIZ | N |
| `spell_objekt_entzaubern` | Objekt entzaubern | ANTI | K |
| `spell_oculus_astralis` | Oculus Astralis | SINNE | K |
| `spell_odem_arcanum` | Odem Arcanum | NOTIZ | N |
| `spell_orcanofaxius` | Orcanofaxius | WAFFE | K |
| `spell_orcanosphaero` | Orcanosphaero | WAFFE | K |
| `spell_pandaemonium` | Pandaemonium | ZONE | K |
| `spell_panik_ueberkomme_euch` | Panik überkomme euch! | ZONE | K |
| `spell_papperlapapp` | Papperlapapp | ZUSTAND | K |
| `spell_paralysis_starr_wie_stein` | Paralysis starr wie Stein | ZUSTAND | K |
| `spell_pectetondo_zauberhaar` | Pectetondo Zauberhaar | NOTIZ | N |
| `spell_penetrizzel_tiefenblick` | Penetrizzel Tiefenblick | SINNE | K |
| `spell_pentagramma_sphaerenbann` | Pentagramma Sphärenbann | ANTI | K |
| `spell_pestilenz_erspueren` | Pestilenz erspüren | SINNE | K |
| `spell_pfeil_der_luft` | Pfeil der Luft | WAFFE | B |
| `spell_pfeil_des_eises` | Pfeil des Eises | WAFFE | B |
| `spell_pfeil_des_erzes` | Pfeil des Erzes | WAFFE | B |
| `spell_pfeil_des_feuers` | Pfeil des Feuers | WAFFE | B |
| `spell_pfeil_des_humus` | Pfeil des Humus | WAFFE | B |
| `spell_pfeil_des_wassers` | Pfeil des Wassers | WAFFE | B |
| `spell_planastrale_anderwelt` | Planastrale Anderwelt | MOBIL | K |
| `spell_plumbumbarum_schwerer_arm` | Plumbumbarum schwerer Arm | KAMPF | B |
| `spell_projektimago_ebenbild` | Projektimago Ebenbild | NOTIZ | N |
| `spell_protectionis_kontrabann` | Protectionis Kontrabann | KOMBINATION | K |
| `spell_psychostabilis` | Psychostabilis | PROBE | B |
| `spell_radau` | Radau | WAFFE | K |
| `spell_reflectimago_spiegelschein` | Reflectimago Spiegelschein | NOTIZ | N |
| `spell_reptilea_natternnest` | Reptilea Natternnest | WESEN | K |
| `spell_respondami_wahrheitszwang` | Respondami Wahrheitszwang | ZUSTAND | K |
| `spell_reversalis_revidum` | Reversalis Revidum | KOMBINATION | K |
| `spell_ruhe_koerper_ruhe_geist` | Ruhe Körper, ruhe Geist | HEILUNG | B |
| `spell_salander_mutander` | Salander Mutander | FORM | K |
| `spell_sanftmut` | Sanftmut | ZUSTAND | K |
| `spell_sapefacta_zauberschwamm` | Sapefacta Zauberschwamm | NOTIZ | N |
| `spell_satuarias_herrlichkeit` | Satuarias Herrlichkeit | PROBE | B |
| `spell_schabernack` | Schabernack | ZUSTAND | K |
| `spell_schadenszauber_bannen` | Schadenszauber bannen | ANTI | K |
| `spell_schelmenkleister` | Schelmenkleister | ZONE | K |
| `spell_schelmenlaune` | Schelmenlaune | ZUSTAND | K |
| `spell_schelmenmaske` | Schelmenmaske | FORM | K |
| `spell_schelmenrausch` | Schelmenrausch | ZUSTAND | K |
| `spell_schleier_der_unwissenheit` | Schleier der Unwissenheit | SINNE | K |
| `spell_schwarz_und_rot` | Schwarz und Rot | WAFFE | K |
| `spell_schwarzer_schrecken` | Schwarzer Schrecken | ZUSTAND | K |
| `spell_seelentier_erkennen` | Seelentier erkennen | NOTIZ | N |
| `spell_seelenwanderung` | Seelenwanderung | ZUSTAND | K |
| `spell_seidenweich_schuppengleich` | Seidenweich Schuppengleich | FORM | K |
| `spell_seidenzunge_elfenwort` | Seidenzunge Elfenwort | PROBE | K |
| `spell_sensattacco_meisterstreich` | Sensattacco Meisterstreich | KAMPF | B |
| `spell_sensibar_empathicus` | Sensibar Empathicus | PROBE | K |
| `spell_serpentialis_schlangenleib` | Serpentialis Schlangenleib | FORM | K |
| `spell_silentium` | Silentium | ZONE | K |
| `spell_sinesigil_unerkannt` | Sinesigil unerkannt | SINNE | K |
| `spell_skelettarius` | Skelettarius | WESEN | K |
| `spell_solidirid_weg_aus_licht` | Solidirid Weg aus Licht | MOBIL | K |
| `spell_somnigravis_tiefer_schlaf` | Somnigravis tiefer Schlaf | ZUSTAND | B |
| `spell_spinnenlauf` | Spinnenlauf | MOBIL | K |
| `spell_spurlos_trittlos` | Spurlos Trittlos | SINNE | K |
| `spell_standfest_katzengleich` | Standfest Katzengleich | KAMPF | B |
| `spell_staub_wandle` | Staub wandle! | WESEN | K |
| `spell_stein_wandle` | Stein wandle! | WESEN | K |
| `spell_stillstand` | Stillstand | ZONE | K |
| `spell_sumus_elixiere` | Sumus Elixiere | HEILUNG | K |
| `spell_tauschrausch` | Tauschrausch | ZUSTAND | K |
| `spell_tempus_stasis` | Tempus Stasis | ZONE | K |
| `spell_tiere_besprechen` | Tiere besprechen | HEILUNG | K |
| `spell_tiergedanken` | Tiergedanken | NOTIZ | N |
| `spell_tlalucs_odem_pestgestank` | Tlalucs Odem Pestgestank | ZONE | K |
| `spell_totes_handle` | Totes handle! | WESEN | K |
| `spell_transformatio_formgestalt` | Transformatio Formgestalt | FORM | K |
| `spell_transmutare_koerperform` | Transmutare Körperform | FORM | K |
| `spell_transversalis_teleport` | Transversalis Teleport | MOBIL | K |
| `spell_traumgestalt` | Traumgestalt | NOTIZ | N |
| `spell_unberuehrt_von_satinav` | Unberührt von Satinav | NOTIZ | N |
| `spell_unitatio_geistesbund` | Unitatio Geistesbund | KOMBINATION | K |
| `spell_unsichtbarer_jaeger` | Unsichtbarer Jäger | SINNE | K |
| `spell_veraenderung_aufheben` | Veränderung aufheben | ANTI | K |
| `spell_verschwindibus` | Verschwindibus | NOTIZ | N |
| `spell_verstaendigung_stoeren` | Verständigung stören | ZUSTAND | K |
| `spell_verwandlung_beenden` | Verwandlung beenden | ANTI | K |
| `spell_vipernblick` | Vipernblick | ZUSTAND | K |
| `spell_visibili_vanitar` | Visibili Vanitar | SINNE | K |
| `spell_vocolimbo_hohler_klang` | Vocolimbo hohler Klang | NOTIZ | N |
| `spell_vogelzwitschern_glockenspiel` | Vogelzwitschern Glockenspiel | NOTIZ | N |
| `spell_wand_aus_dornen` | Wand aus Dornen | ZONE | K |
| `spell_wand_aus_erz` | Wand aus Erz | ZONE | K |
| `spell_wand_aus_flammen` | Wand aus Flammen | ZONE | K |
| `spell_wand_aus_luft` | Wand aus Luft | ZONE | K |
| `spell_wand_aus_wasser` | Wand aus Wasser | ZONE | K |
| `spell_warmes_blut` | Warmes Blut | SINNE | K |
| `spell_wasseratem` | Wasseratem | MOBIL | K |
| `spell_weiches_erstarre` | Weiches erstarre! | ZONE | K |
| `spell_weihrauchwolke_wohlgeruch` | Weihrauchwolke Wohlgeruch | NOTIZ | N |
| `spell_weisheit_der_baeume` | Weisheit der Bäume | FORM | K |
| `spell_weisse_maehn_und_goldener_huf` | Weiße Mähn und goldener Huf | WESEN | K |
| `spell_wellenlauf` | Wellenlauf | MOBIL | K |
| `spell_wettermeisterschaft` | Wettermeisterschaft | ZONE | K |
| `spell_widerwille_ungemach` | Widerwille Ungemach | ZONE | K |
| `spell_windhose` | Windhose | ZONE | K |
| `spell_windstille` | Windstille | ZONE | K |
| `spell_wipfellauf` | Wipfellauf | MOBIL | K |
| `spell_xenographus_schriftenkunde` | Xenographus Schriftenkunde | NOTIZ | N |
| `spell_zagibu_ubigaz` | Zagibu Ubigaz | NOTIZ | N |
| `spell_zappenduster` | Zappenduster | ANTI | K |
| `spell_zauberklinge_geisterspeer` | Zauberklinge Geisterspeer | ZONE | K |
| `spell_zaubernahrung_hungerbann` | Zaubernahrung Hungerbann | HEILUNG | K |
| `spell_zauberwesen_der_natur` | Zauberwesen der Natur | WESEN | K |
| `spell_zauberzwang` | Zauberzwang | ZUSTAND | K |
| `spell_zorn_der_elemente` | Zorn der Elemente | WAFFE | K |
| `spell_zunge_laehmen` | Zunge lähmen | ZUSTAND | K |
| `spell_zwingtanz` | Zwingtanz | ZUSTAND | K |

Screening: ANTI: 21, BEST: 4, FORM: 20, HEILUNG: 11, KAMPF: 10, KOMBINATION: 6, MOBIL: 15, NOTIZ: 42, PROBE: 10, SINNE: 17, WAFFE: 34, WESEN: 20, ZONE: 35, ZUSTAND: 43. Gesamt: 288.
