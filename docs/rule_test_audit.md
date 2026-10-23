# Audit der Regel- und Katalogtests

Stand: 23. Oktober 2026

## Ergebnis

Die maschinenlesbare Inventur unter `tool/rule_test_evidence.json` erfasst alle
196 Testdateien unter `test/rules/` und `test/catalog/`.

- 17 technische Katalogverträge sind als `product_contract` bestätigt.
- 179 Dateien sind als `conflict` markiert.
- Es gibt keine nicht inventarisierten oder als `unreviewed` geführten Dateien.

`conflict` bedeutet in diesem Audit nicht automatisch, dass die implementierte
Regel falsch ist. Es bedeutet, dass mindestens eine Erwartung der gesamten Datei
noch nicht lückenlos mit gedruckter Buchseite und vollständigem DSA-MCP-Kontext
belegt oder bewusst als Produktvertrag eingeordnet wurde. Eine vorhandene
Quellenangabe an einzelnen Tests reicht für den Status `verified` der ganzen
Datei nicht aus.

## Prüfregeln

Für `official` und `house_rule` gilt `verified` nur, wenn jede fachliche
Erwartung der Datei geprüft wurde und die Inventur mindestens Quellentitel,
gedruckte Seite, DSA-MCP-Chunk und Prüfdatum enthält. Die gedruckte Seite ist
die kanonische Referenz; die Chunk-ID dokumentiert den gelesenen MCP-Kontext.

Technische Verträge ohne DSA-Regelbehauptung werden als `product_contract`
geführt. Dazu gehören beispielsweise Verschlüsselungs-, Lade-, Referenz- und
Konsistenzverträge der Kataloginfrastruktur.

Der CI-Check `python tool/check_rule_test_evidence.py` verhindert fehlende oder
veraltete Inventurpfade. Neue verifizierte Buch- oder Hausregeln ohne
vollständigen Quellenblock werden abgelehnt. Ein Konflikt benötigt einen Befund
und einen Folgeauftrag.

## Gebündelte Folgeaufträge

| Kennung | Inhalt | Abgrenzung |
| --- | --- | --- |
| `RULE-AUDIT-COMBAT` | Kampf, Gefecht, Waffen, Schaden, Treffer und Wunden | Nur Quellenprüfung; fachliche Korrekturen werden separat geplant. |
| `RULE-AUDIT-MAGIC` | Magie, Zauber, Rituale, Alchimie und Artefakte | Repräsentation, Tradition und Ritualkenntnis getrennt prüfen. |
| `RULE-AUDIT-ADVANCEMENT` | Steigerung, Lernen, Erwerb, AP und Eigenschaften | Buchregeln von App-Planungsregeln trennen. |
| `RULE-AUDIT-COMPANIONS` | Vertraute, Begleiter und Reittiere | Offizielle Regeln und Meisterentscheidungen getrennt ausweisen. |
| `RULE-AUDIT-INVENTORY` | Inventar, Ressourcen und Währung | Reine App-Verträge dürfen nach belegter Einordnung umklassifiziert werden. |
| `RULE-AUDIT-GENERAL` | Übrige Regel- und Ableitungsdateien | Dateiweise prüfen und in ein Fachpaket überführen. |

## Bereits bestätigte Stichproben

Während der Bestandsaufnahme wurden Repräsentationskosten gegen *Wege der
Helden* S. 290 (DSA-MCP-Chunk 4824), fremde Ritualkenntnis gegen *Wege der
Götter* S. 240 (Chunk 3771) und TP/KK gegen *Wege des Schwerts* S. 83
(Chunk 7048) gegengeprüft. Die zugehörigen Dateien bleiben dennoch als
Konflikt markiert, solange ihre übrigen Erwartungen nicht ebenfalls vollständig
geprüft sind.

## Umgang mit Abweichungen

Dieses Arbeitspaket ändert keine Fachlogik. Ein belegter Unterschied zwischen
Regelbuch, Test und Produktcode wird im passenden Folgeauftrag festgehalten.
Erst ein eigener, fachlich abgegrenzter Auftrag darf Produktverhalten und
Erwartungswerte gemeinsam ändern.
