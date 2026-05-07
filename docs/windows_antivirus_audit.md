# Windows-Antivirus-Audit

Dieses Dokument haelt den statischen Antivirus-Risiko-Audit fuer die
Windows-Desktop-App und den relevanten Laufzeitcode fest. Es dient als
nachvollziehbare Referenz fuer Release-Pruefungen, False-Positive-Analyse und
Kommunikation bei Rueckfragen von Nutzern oder Plattformbetreibern.

## Kurzfazit

- Im Repository wurden keine typischen Schadcode-Muster gefunden.
- Wahrscheinliche AV-Treffer auf Windows waeren am ehesten heuristische
  False Positives durch neue oder unsignierte Desktop-Binaries in Kombination
  mit legitimen Netzwerk-, Kryptografie- und Datei-Funktionen.
- Die funktional auffaelligen Stellen sind fachlich begruendet und im Code
  klar eingrenzbar.

## Audit-Umfang

Geprueft wurden:

- Laufzeitcode unter `lib/`
- Plattformcode und Manifeste unter `windows/`, `android/`, `ios/`,
  `macos/` und `linux/`
- generierte Plugin-Registrierungen, soweit sie das ausgelieferte
  Plattformverhalten sichtbar machen

Nicht Teil dieses Audits:

- Python- und Hilfsskripte unter `tool/`, sofern sie nicht in die App
  ausgeliefert werden
- Pub-Cache-Quellen der Drittanbieter-Pakete ausserhalb dieses Repositories

## Keine gefundenen Schadcode-Muster

Der statische Audit hat keine Hinweise auf folgende Muster ergeben:

- kein Autostart oder Persistenz ueber Run-Keys, Scheduled Tasks oder
  Startup-Ordner
- keine Registry-Manipulation
- keine Privilegienerhoehung oder `runas`-Aufrufe
- keine Shell-Ausfuehrung ueber `cmd.exe`, PowerShell oder `bash -c`
- keine Code-Injektion, kein `CreateRemoteThread`, kein `VirtualAlloc`,
  kein fremdes DLL-Nachladen fuer Schadfunktionen
- keine Hooks, kein Keylogging, kein Mitschneiden von Tastatur oder Maus
- kein versteckter Downloader und kein Nachladen oder Starten externer
  Binardateien

## Heuristisch auffaellige, aber legitime Funktionen

### Netzwerkzugriffe

- OpenAI-Bildgenerierung nutzt HTTPS-Requests mit API-Key und optionalem
  Referenzbild-Upload in `lib/data/avatar_api_openai.dart`.
- Firestore-Gruppensync nutzt Cloud Firestore in
  `lib/data/gruppen_sync_service.dart`.
- Die Windows-MSIX-Konfiguration fordert `internetClient` in `pubspec.yaml`,
  was fuer diese Cloud-Funktionen konsistent ist.
- Android fordert `INTERNET` nur in Debug/Profile-Manifests an, nicht im
  produktiven `main`-Manifest.

### Dateisystem und Dateiuebertragung

- JSON-Import und -Export erfolgen ueber `FilePicker` und lokale Dateien in
  `lib/data/hero_transfer_file_gateway_io.dart`.
- Auf mobilen Zielen wird der Export ueber `share_plus` geteilt, nicht ueber
  versteckte Netzwerkkanale.
- Avatarbilder und Custom-Kataloge werden lokal in klar benannten Ordnern
  gespeichert, gelesen und geloescht.

### Child-Process-Verhalten

- `lib/data/storage_directory_tools_io.dart` startet ausschliesslich den
  nativen Dateimanager (`explorer.exe`, `open`, `xdg-open`), um einen vom
  Nutzer bekannten lokalen Ordner zu oeffnen.
- Es gibt dabei keine Shell-Kommandokette, keine zusammengesetzten
  Befehlsstrings und keine Weitergabe an `cmd.exe` oder PowerShell.

### Kryptografie und Schutz sensibler Daten

- `lib/catalog/catalog_crypto.dart` verschluesselt geschuetzte
  Kataloginhalte. Das ist fachlich gewollt und kein Hinweis auf Verschleierung
  von Schadcode.
- `lib/data/hive_settings_repository.dart` nutzt
  `flutter_secure_storage`, um sensible Einstellungen wie API-Schluessel im
  Betriebssystem-Schluesselspeicher abzulegen.

### Plattform-Metadaten und Entitlements

- macOS Release laeuft in der Sandbox; Debug erlaubt zusaetzlich
  `allow-jit` und `network.server`, was fuer Debug-Builds bei Flutter
  erwartbar ist.
- Windows-Desktop nutzt die normalen Flutter-Runner-Dateien; es gibt keine
  benutzerdefinierten Win32-APIs fuer Ueberwachung, Hooks oder Injektion.

## Bekannte Stellen fuer Release-Rueckfragen

Falls ein Antivirus-Produkt oder ein Nutzer Rueckfragen stellt, sind diese
Stellen zuerst zu pruefen:

- `lib/data/avatar_api_openai.dart`
- `lib/data/gruppen_sync_service.dart`
- `lib/data/hero_transfer_file_gateway_io.dart`
- `lib/data/storage_directory_tools_io.dart`
- `lib/catalog/catalog_crypto.dart`
- `pubspec.yaml`

## Windows-Artefakt-Pruefung

Quellcode und Binardatei muessen getrennt bewertet werden. Ein sauberer
Quellcode-Audit schliesst False Positives auf EXE- oder MSIX-Ebene nicht aus.

Empfohlener Ablauf:

1. Release-Artefakt bauen, zum Beispiel mit `flutter build windows --release`.
2. SHA-256 und Signaturstatus des Artefakts dokumentieren.
3. Optional einen lokalen Microsoft-Defender-Scan ausfuehren.
4. Optional das Artefakt bei VirusTotal hochladen.
5. Eventuelle Treffer mit den oben genannten legitimen Funktionen abgleichen.

Der Windows-Build bindet `flutter_secure_storage_windows` ein. Das Plugin nutzt
ATL/MFC-Header und Bibliotheken (`atlstr.h`, `atls.lib`); die Pfade werden in
`windows/CMakeLists.txt` fuer das Plugin-Ziel aufgeloest. Wenn ein Build trotz
dieser Konfiguration an ATL/MFC scheitert, ist in der von CMake verwendeten
Visual-Studio- oder Build-Tools-Instanz die Komponente `C++ ATL/MFC`
nachzuinstallieren.

Fuer Schritt 2 bis 4 liegt ein Helfer unter
`tool/audit_windows_artifact.ps1`.

Beispiel:

```powershell
pwsh -File tool/audit_windows_artifact.ps1 `
  -ArtifactPath build\windows\x64\runner\Release\flutter_application_1.exe `
  -AsJson
```

Mit optionalem Defender-Aufruf:

```powershell
pwsh -File tool/audit_windows_artifact.ps1 `
  -ArtifactPath build\windows\x64\runner\Release\flutter_application_1.exe `
  -RunDefender `
  -OutputPath build\windows_audit_report.json
```

## Priorisierte Massnahmen gegen False Positives

- Release-Builds signieren, bevor sie breit verteilt werden.
- Stabile Produktmetadaten fuer EXE/MSIX pflegen.
- Netzwerkfunktionen in Release Notes oder Datenschutztexten offen benennen.
- Keine unsignierten Debug-Builds an Endnutzer verteilen.
- Artefakt-Hash, Signaturstatus und Scan-Ergebnisse pro Release dokumentieren.

## Einordnung von Dev-Code

Die Hilfsskripte unter `tool/` koennen fuer interne Workflows Kryptografie,
SQLite oder Dateiverarbeitung nutzen. Sie sind nicht Teil der ausgelieferten
Flutter-App und werden deshalb in Antivirus-Rueckfragen zur Laufzeit-App
getrennt bewertet.
