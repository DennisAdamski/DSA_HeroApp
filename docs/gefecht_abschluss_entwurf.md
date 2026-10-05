# Gefecht: Abschluss der Folgepakete

Bestätigter Umfang vom 5. Oktober 2026: vorhandene Gefechtsänderungen prüfen
und einbeziehen; mehrere Gegner mit Name, LeP, RS und INI flüchtig führen.
Fachliche Entscheidungen werden anhand des DSA-MCP belegt.

## Gemeinsame Gegner und Initiative

Eine lokale Begegnung erhält stabile Gegner-IDs. Eigene Heldensitzungen wählen
einen Gegner ausdrücklich aus. Kontaktwechsel verwirft Angriffsdaten, Entfernung
und alte Zielzahlungen; offene Treffer behalten ihre ursprüngliche Ziel-ID.
Gleichnamige Gegner bleiben unterscheidbar. Gegnerwerte werden bearbeitet und
gewöhnliche Treffer nach bestätigter gescheiterter Abwehr übertragen:
SP = max(0, TP − RS), LeP können negativ werden. Direkte SP umgehen RS.
Wunden benötigen weitere Werte und werden nicht aus LeP/RS erfunden.

Eine gemeinsame flüchtige Teilnehmerliste verbindet ausdrücklich gewählte eigene
Helden mit den Gegnern. Offene INI-Zeitpunkte werden frisch ermittelt; Gleichstände
werden am Tisch geordnet. Reguläre Aktionen gehen umgewandelten Aktionen in
derselben Phase vor. Verzögerung hält höchstens eine bezahlte Reserve, Abwehr
verwirft sie. Bestätigte INI-Änderungen bewegen nur offene Zeitpunkte.
Laufende Aufträge und ungeklärte Übernahmen sperren gemeinsamen Rundenwechsel.

## Weitere Pakete

Entwaffnen/Umreißen bekommen bestätigte Gegenproben und flüchtige Folgen;
Klingenwand/Klingensturm getrennte Proben. Patzer und Bruchtests erhalten
belegte Folgewürfe und frische Waffenänderungen ohne automatische Entfernung.
Magie/Karma wird nur für vollständige belegte Profile erweitert. Unbelegte
Komponenten werden ausdrücklich erfragt oder bleiben sichtbar manuell.

## Prüfung und Fortschritt

Neue Regeln liegen unter `lib/rules/derived`, Provider und UI rufen sie auf.
Regressionen prüfen ID-Bindung, Zielwechsel, Doppelcallback, Dialogabbruch,
Rundenübertrag, frische Werte und schmale/breite Layouts. Pro Paket erfolgen
Analyse, relevante Tests, Format/LOC und ein gezielter Commit; zuletzt Gesamtsuite
und unabhängiges Review. Keine Veröffentlichung und keine neue Persistenz.

Quellen: WdS MCP 6975 (Seite 56: TP/RS/SP), 7046–7047 (Seite 82:
Abwarten/Umwandlung); Hausregel 25819 (Seite 3: kritischer Bruchtest).

- Vorprüfung: 38 Tests der vorhandenen Vorgaben-/Freigabe-/Kontextänderungen
  bestanden. Noch kein Paketabschluss.
- Übernahme und Stabilisierung am 5. Oktober 2026: Die neuen Gefechtskarten
  (Patzer, Klingen, Reserve) lösen die Gefechtsbrücke erst beim Bedienen auf;
  ein vorzeitiger Cast brach Ansichten mit Testbeständen. Die Patzerkarte
  erscheint vollständig nur bei offener Folge, sonst bleibt der Einstieg
  „Bruchtest“. Ein Test, der eine misslungene AT mit einer 20 erzwang, nutzt
  nun eine 19, weil eine natürliche 20 regelgerecht die Patzerklärung öffnet.
  Analyse, Format und LOC-Prüfung bestehen; die frühere Grenze „Gegner bleiben
  unmodelliert“ aus dem Vervollständigungsplan ist durch diesen bestätigten
  Umfang ersetzt.
- Erledigt im Vervollständigungspaket „Ansicht und Handy“: Gegner und
  gemeinsame Initiative stehen im Abschnitt „Begegnung“, Abwarten bei den
  weiteren Aktionen; schmal hält eine Schnellleiste die häufigsten Aktionen.
