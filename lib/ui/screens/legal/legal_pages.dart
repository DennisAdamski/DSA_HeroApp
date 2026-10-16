import 'package:flutter/material.dart';

/// Pflichtangaben für Impressum und Datenschutzerklärung.
class LegalContact {
  /// Erstellt vollständig angegebene Kontaktdaten.
  const LegalContact({
    required this.responsibleName,
    required this.streetAddress,
    required this.postalCode,
    required this.city,
    required this.country,
    required this.email,
  });

  /// Erstellt eine bewusst unvollständige lokale Konfiguration.
  const LegalContact.empty()
    : responsibleName = '',
      streetAddress = '',
      postalCode = '',
      city = '',
      country = '',
      email = '';

  /// Liest die Pflichtangaben aus nicht geheimen Build-Parametern.
  const LegalContact.fromEnvironment()
    : responsibleName = const String.fromEnvironment('LEGAL_RESPONSIBLE_NAME'),
      streetAddress = const String.fromEnvironment('LEGAL_STREET_ADDRESS'),
      postalCode = const String.fromEnvironment('LEGAL_POSTAL_CODE'),
      city = const String.fromEnvironment('LEGAL_CITY'),
      country = const String.fromEnvironment('LEGAL_COUNTRY'),
      email = const String.fromEnvironment('LEGAL_CONTACT_EMAIL');

  /// Name der verantwortlichen Person oder Organisation.
  final String responsibleName;

  /// Straße und Hausnummer der ladungsfähigen Anschrift.
  final String streetAddress;

  /// Postleitzahl der ladungsfähigen Anschrift.
  final String postalCode;

  /// Ort der ladungsfähigen Anschrift.
  final String city;

  /// Staat der ladungsfähigen Anschrift.
  final String country;

  /// Adresse für schnelle elektronische Kontaktaufnahme.
  final String email;

  /// Gibt an, ob alle für den öffentlichen Release verlangten Werte gesetzt sind.
  bool get isComplete {
    return responsibleName.trim().isNotEmpty &&
        streetAddress.trim().isNotEmpty &&
        postalCode.trim().isNotEmpty &&
        city.trim().isNotEmpty &&
        country.trim().isNotEmpty &&
        email.trim().isNotEmpty;
  }

  /// Formatiert die ladungsfähige Anschrift für die Anzeige.
  String get formattedAddress {
    return '$responsibleName\n$streetAddress\n$postalCode $city\n$country';
  }
}

/// Im Build konfigurierte Pflichtangaben für öffentliche Rechtstexte.
const legalContactFromEnvironment = LegalContact.fromEnvironment();

/// Öffentlich und ohne Anmeldung erreichbare Datenschutzerklärung.
class PrivacyPolicyScreen extends StatelessWidget {
  /// Erstellt die Datenschutzerklärung mit den Angaben des Verantwortlichen.
  const PrivacyPolicyScreen({
    super.key,
    this.contact = legalContactFromEnvironment,
  });

  /// Verantwortlicher und Kontaktweg für Betroffenenanfragen.
  final LegalContact contact;

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Datenschutzerklärung',
      children: [
        _configurationWarning(contact),
        _LegalSection(
          title: '1. Verantwortlicher',
          text: contact.isComplete
              ? '${contact.formattedAddress}\nE-Mail: ${contact.email}'
              : 'Die Kontaktdaten des Verantwortlichen sind in diesem '
                    'Entwicklungsbuild noch nicht vollständig konfiguriert.',
        ),
        const _LegalSection(
          title: '2. Lokale Nutzung',
          text:
              'Heldendaten, App-Einstellungen und lokale Geheimnisse werden '
              'zunächst auf deinem Gerät gespeichert. Ohne Anmeldung ist '
              'keine Konto-Synchronisierung aktiv. Technisch erforderliche '
              'lokale Speicherung dient der von dir gewünschten App-Funktion. '
              'Wir verwenden kein Analytics, kein Marketing-Tracking und '
              'keine Werbe-Cookies.',
        ),
        const _LegalSection(
          title: '3. Firebase-Konto und Cloud-Dienste',
          text:
              'Bei freiwilliger Konto-Nutzung verarbeitet Firebase '
              'Authentication insbesondere E-Mail-Adresse, Zugangsdaten, '
              'IP-Adresse und Geräte-/Browserinformationen. Firebase '
              'Authentication wird ausschließlich aus US-Rechenzentren '
              'betrieben. Firestore speichert kontogebundene Helden, '
              'Zustände, Sync-Metadaten und Einstellungen; Cloud Storage '
              'speichert Avatarbilder unter deiner UID. Cloud Functions '
              'verarbeitet technische Anfragedaten, Firebase App Check '
              'Integritätsnachweise und Hosting liefert die Web-App aus. '
              'Google verarbeitet diese Daten regelmäßig als '
              'Auftragsverarbeiter. Rechtsgrundlage ist Art. 6 Abs. 1 lit. b '
              'DSGVO für die angeforderten Konto- und Sync-Funktionen sowie '
              'Art. 6 Abs. 1 lit. f DSGVO für Sicherheit und Missbrauchsschutz.\n\n'
              'Informationen: https://firebase.google.com/support/privacy/\n'
              'Verarbeitungsbedingungen: '
              'https://firebase.google.com/terms/data-processing-terms',
        ),
        const _LegalSection(
          title: '4. Feedback über GitHub',
          text:
              'Wenn du Feedback absendest, werden der von dir freigegebene '
              'Text und technische Angaben als öffentliches GitHub-Issue '
              'veröffentlicht. GitHub-Inhalte sind grundsätzlich unbefristet '
              'öffentlich abrufbar. Interne Feedback-Metadaten werden nach '
              'sieben Tagen gelöscht. Bitte übermittle keine personenbezogenen '
              'oder vertraulichen Inhalte. Löschwünsche kannst du an die oben '
              'genannte Kontaktadresse richten. Die Veröffentlichung erfolgt '
              'nur nach deiner ausdrücklichen Aktion auf Grundlage von '
              'Art. 6 Abs. 1 lit. a DSGVO.',
        ),
        const _LegalSection(
          title: '5. Optionale OpenAI-Bildgenerierung',
          text:
              'Die Bildgenerierung ist optional. Erst nach deiner Bestätigung '
              'werden Prompt und gegebenenfalls ein Referenzbild direkt an '
              'OpenAI übertragen. API-Daten werden ohne ausdrückliches Opt-in '
              'nicht zum Training verwendet. Standardmäßige '
              'Missbrauchsprotokolle können Inhalte bis zu 30 Tage enthalten; '
              'gesetzlich oder sicherheitsbedingt kann eine längere '
              'Aufbewahrung erforderlich sein. Die Übertragung erfolgt nur '
              'für die von dir angeforderte Generierung.\n\n'
              'Informationen: '
              'https://developers.openai.com/api/docs/guides/your-data',
        ),
        const _LegalSection(
          title: '6. Empfänger und Drittlandtransfers',
          text:
              'Empfänger sind Google/Firebase für Authentifizierung, Hosting, '
              'Datenbank, Storage, Functions und App Check, GitHub für '
              'öffentlich abgesendetes Feedback sowie OpenAI nur bei '
              'freiwilliger Bildgenerierung. Dabei können Daten in den USA '
              'verarbeitet werden. Maßgeblich sind die jeweiligen '
              'Verarbeitungsbedingungen, Angemessenheitsbeschlüsse und '
              'Standardvertragsklauseln.',
        ),
        const _LegalSection(
          title: '7. Speicherdauer und Löschung',
          text:
              'Lokale Daten bleiben bis zu ihrer Löschung in der App oder im '
              'Betriebssystem erhalten. Kontodaten, synchronisierte Helden, '
              'Avatare und Remote-Geheimnisse bleiben bis zur Konto- oder '
              'Einzellöschung gespeichert; Sicherungskopien können nach den '
              'Fristen des Dienstleisters zeitversetzt verschwinden. '
              'Öffentliches GitHub-Feedback bleibt grundsätzlich unbefristet. '
              'Technische Logs richten sich nach den erforderlichen '
              'Sicherheits- und Anbieterfristen.',
        ),
        _LegalSection(
          title: '8. Deine Rechte',
          text:
              'Du hast nach Maßgabe der DSGVO insbesondere Rechte auf Auskunft, '
              'Berichtigung, Löschung, Einschränkung, Datenübertragbarkeit und '
              'Widerspruch. Eine Einwilligung kannst du für die Zukunft '
              'widerrufen. Richte Anfragen an ${contact.email.isEmpty ? 'die '
                        'noch zu konfigurierende Kontaktadresse' : contact.email}. '
              'Außerdem besteht ein Beschwerderecht bei einer zuständigen '
              'Datenschutzaufsichtsbehörde.',
        ),
        const _LegalSection(
          title: '9. Stand und Änderungen',
          text:
              'Stand: 17. Oktober 2026. Bei neuen Telemetrie-, Analyse- oder '
              'Marketingfunktionen sowie bei geänderten Dienstleistern wird '
              'diese Erklärung vor deren Einsatz aktualisiert.',
        ),
      ],
    );
  }
}

/// Öffentlich und ohne Anmeldung erreichbares Impressum.
class ImprintScreen extends StatelessWidget {
  /// Erstellt das Impressum mit den Build-Angaben des Anbieters.
  const ImprintScreen({super.key, this.contact = legalContactFromEnvironment});

  /// Anbieter- und Kontaktangaben.
  final LegalContact contact;

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'Impressum',
      children: [
        _configurationWarning(contact),
        _LegalSection(
          title: 'Angaben gemäß § 5 DDG',
          text: contact.isComplete
              ? contact.formattedAddress
              : 'Name und ladungsfähige Anschrift fehlen in diesem '
                    'Entwicklungsbuild.',
        ),
        _LegalSection(
          title: 'Kontakt',
          text: contact.email.isEmpty
              ? 'Die Kontaktadresse ist noch nicht konfiguriert.'
              : 'E-Mail: ${contact.email}',
        ),
        const _LegalSection(
          title: 'Fanprojekt und Rechte Dritter',
          text:
              'DSA Heldenverwaltung ist ein inoffizielles, kostenloses '
              'Fanprojekt und steht nicht in Verbindung zu Ulisses Spiele. '
              'Marken, Regeltexte, Grafiken und sonstige DSA-Inhalte gehören '
              'Ulisses Spiele beziehungsweise den jeweiligen '
              'Rechteinhabern. Rechte an eigener Software und eigenen Inhalten '
              'bleiben davon getrennt.',
        ),
        const _LegalSection(
          title: 'Haftungshinweis',
          text:
              'Trotz sorgfältiger Prüfung wird keine Gewähr für Richtigkeit, '
              'Vollständigkeit oder ständige Verfügbarkeit übernommen. Für '
              'verlinkte externe Inhalte sind deren Anbieter verantwortlich.',
        ),
      ],
    );
  }
}

// Einheitliche, scrollbar lesbare Darstellung für beide öffentlichen Texte.
class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

Widget _configurationWarning(LegalContact contact) {
  if (contact.isComplete) {
    return const SizedBox.shrink();
  }
  return const Card(
    color: Color(0xffffe0b2),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'Entwicklungsstand: Pflichtangaben fehlen. Diesen Build nicht '
        'veröffentlichen.',
      ),
    ),
  );
}
