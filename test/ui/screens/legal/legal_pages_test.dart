import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/app_shell.dart';
import 'package:dsa_heldenverwaltung/ui/screens/legal/legal_pages.dart';

void main() {
  const contact = LegalContact(
    responsibleName: 'Alrik Beispiel',
    streetAddress: 'Testweg 1',
    postalCode: '12345',
    city: 'Beispielstadt',
    country: 'Deutschland',
    email: 'datenschutz@example.test',
  );

  testWidgets('Datenschutz nennt Dienste, Speicherdauer und Rechte', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PrivacyPolicyScreen(contact: contact)),
    );

    expect(find.text('Datenschutzerklärung'), findsOneWidget);
    expect(find.textContaining('Alrik Beispiel'), findsOneWidget);
    expect(find.textContaining('Firebase Authentication'), findsOneWidget);
    expect(find.textContaining('bis zu 30 Tage'), findsOneWidget);
    expect(find.textContaining('öffentlich'), findsWidgets);
    expect(find.textContaining('Beschwerderecht'), findsOneWidget);
    expect(find.textContaining('Analytics'), findsOneWidget);
  });

  testWidgets('Impressum warnt sichtbar bei fehlenden Pflichtangaben', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ImprintScreen(contact: LegalContact.empty())),
    );

    expect(find.text('Impressum'), findsOneWidget);
    expect(find.textContaining('nicht veröffentlichen'), findsOneWidget);
  });

  testWidgets('App-Shell stellt öffentliche Legal-Routen bereit', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dunkelModusProvider.overrideWithValue(false),
          debugModusProvider.overrideWithValue(false),
          oberflaecheProvider.overrideWithValue(Oberflaeche.codex),
        ],
        child: DsaAppShell(
          legalContact: contact,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/datenschutz'),
              child: const Text('Datenschutz öffnen'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Datenschutz öffnen'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
  });
}
