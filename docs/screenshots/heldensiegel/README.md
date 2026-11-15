# Persönliche Heldensiegel

Erster begutachtbarer Stand vom 15.11.2026.

[Motivübersicht aus dem Flutter-Renderer](motive.png)

Die vier Siegel jeder Gruppe zeigen von links nach rechts: profan, magisch,
karmal und beides. Die Grundformen sind eigenständige Gestaltungsentwürfe;
Stern und Strahlenmarke zeigen nur vorhandene Befähigungen. Die karmale Marke
ist ein neutrales Ornament und kein spezifisches Gottheitsemblem.

Die Motive erscheinen am Porträtring, im Spieltisch-Kopf und im Abschnitt
„Magie und Karma“. Alle Zusatzanimationen bleiben abschaltbar. Fehlende oder
mehrdeutige Rassenangaben erhalten das neutrale Motiv.

Reproduktion der Übersicht:

```powershell
flutter test --no-pub test/ui2/widgets/karto_heldensiegel_test.dart --dart-define=HELDENSIEGEL_PREVIEW_DIR=docs/screenshots/heldensiegel
```

Die vollständige Desktopansicht steht unter
[Spielen, hell](../heldenbogen-a/spielen-1440-light.png).
