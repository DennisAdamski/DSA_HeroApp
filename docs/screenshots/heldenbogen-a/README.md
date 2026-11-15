# Heldenbogen A – erster Flutter-Entwurf

Erster begutachtbarer Stand vom 15.11.2026 auf Basis von `test`.
Die Bilder stammen aus dem echten Flutter-Test-Renderer mit geladenen
Projektschriften, nicht aus dem generierten Mockup. Die Beispieldaten sind
Testdaten; der Held mit 27/22 LeP zeigt absichtlich einen Wert über Maximum.

- [Desktop, hell](spielen-1440-light.png)
- [Mobil, hell](spielen-390-light.png)
- [Tablet, dunkel](spielen-1024-dark.png)

Umgesetzt sind feine Messingkonturen, dezente Kartuschenecken, größere
Serifentitel und Kopflinien an äußeren Spielkacheln. Die Anordnung bleibt
anpassbar; Unterabschnitte bleiben schlicht. Illustrationen und zusätzliche
Texturen aus dem Mockup sind nicht Bestandteil dieses ersten Entwurfs.

Die Aufnahmen enthalten inzwischen auch das persönliche Heldensiegel vor
„Am Spieltisch“ und am Porträtring im ruhenden Zustand. Der kurze Auftritt
und der Messinglichtbogen sind über
die bestehenden Effektoptionen abschaltbar und laufen nicht dauerhaft.

Reproduktion mit dem bestehenden Aufnahme-Workflow:

```powershell
flutter test --no-pub test/ui2/shell/karto_workspace_visual_test.dart --dart-define=R3_SCREENSHOT_DIR=docs/screenshots/heldenbogen-a
```

Der Workflow erzeugt zusätzlich Bilder anderer Seiten; hier werden nur
die drei zur Designänderung gehörenden Spielen-Aufnahmen versioniert.
