import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_compat_theme.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/open_sign_in.dart';
import 'package:dsa_heldenverwaltung/ui/screens/auth/sign_in_screen.dart';
import 'package:dsa_heldenverwaltung/ui/theme/codex_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_feinschliff.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_rahmen.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';

void main() {
  for (final helligkeit in Brightness.values) {
    final wurzel = buildKartoTheme(
      brightness: helligkeit,
      centerAppBarTitle: false,
    );

    test('das Wurzeltheme bleibt ohne Komponenten-Textstile '
        '(${helligkeit.name})', () {
      // Die MaterialApp blendet zwischen Codex und Kartograph ueber; ein Stil,
      // der dort auf null trifft, bricht das. Der Feinschliff liegt deshalb
      // nur in verschachtelten Themes.
      expect(wurzel.dialogTheme.titleTextStyle, isNull);
      expect(wurzel.dataTableTheme.headingTextStyle, isNull);
      expect(wurzel.dataTableTheme.dataTextStyle, isNull);
    });

    test('Feinschliff setzt Spectral-Titel und Kartusche '
        '(${helligkeit.name})', () {
      final fein = buildKartoFeinschliff(wurzel);
      final token = helligkeit == Brightness.dark ? kartoDunkel : kartoHell;
      final titel = fein.dialogTheme.titleTextStyle!;
      expect(titel.fontFamily, kSchriftTitel);
      expect(titel.inherit, wurzel.textTheme.titleLarge!.inherit);
      final rahmen = fein.dialogTheme.shape! as KartoRahmen;
      expect(rahmen.akzent, token.messing);
      expect(rahmen.side.color, token.kueste);
      expect(fein.dataTableTheme.headingTextStyle!.fontFamily, kSchriftDaten);
      expect(fein.dataTableTheme.dividerThickness, 0.5);
      // Idempotent: die Bruecke wendet ihn auf bereits verfeinerte Themes an.
      final zweimal = buildKartoFeinschliff(fein);
      expect(zweimal.dialogTheme, fein.dialogTheme);
      expect(zweimal.dataTableTheme, fein.dataTableTheme);
    });
  }

  testWidgets('ein Dialog unter dem Feinschliff traegt Titel und Rahmen', (
    tester,
  ) async {
    final wurzel = buildKartoTheme(
      brightness: Brightness.light,
      centerAppBarTitle: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: wurzel,
        home: Theme(
          data: buildKartoFeinschliff(wurzel),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Rast'),
                  content: Text('Inhalt'),
                ),
              ),
              child: const Text('Öffnen'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Öffnen'));
    await tester.pumpAndSettle();
    final titel = tester.widget<DefaultTextStyle>(
      find
          .ancestor(
            of: find.text('Rast'),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(titel.style.fontFamily, kSchriftTitel);
    final flaechen = tester.widgetList<Material>(
      find.ancestor(of: find.text('Inhalt'), matching: find.byType(Material)),
    );
    expect(flaechen.map((m) => m.shape), contains(isA<KartoRahmen>()));
    expect(tester.takeException(), isNull);
  });

  test('KartoRahmen skaliert, kopiert und blendet ueber', () {
    const a = KartoRahmen(
      side: BorderSide(color: Color(0xFF000000), width: 2),
      akzent: Color(0xFF000000),
    );
    const b = KartoRahmen(
      side: BorderSide(color: Color(0xFFFFFFFF), width: 4),
      radius: 16,
      akzent: Color(0xFFFFFFFF),
      akzentStaerke: 5,
    );
    expect(a.copyWith(radius: 16).radius, 16);
    expect(a.copyWith(), a);
    expect(a.scale(2).radius, 16);
    expect(a.scale(2).akzentStaerke, 6);
    final mitte = ShapeBorder.lerp(a, b, 0.5)! as KartoRahmen;
    expect(mitte.radius, 12);
    expect(mitte.side.width, 3);
    expect(mitte.akzentStaerke, 4);
    expect(a.hashCode, a.copyWith().hashCode);
    // Gegen einen fremden Rahmen faellt die Ueberblendung nicht aus.
    expect(ShapeBorder.lerp(a, const RoundedRectangleBorder(), 0.5), isNotNull);
  });

  testWidgets('aufgelegte Seiten behalten das Theme ihres Aufrufers', (
    tester,
  ) async {
    // Eine MaterialPageRoute saehe sonst nur das Wurzeltheme: unter
    // Kartograph fiele die Bruecke weg und CodexTheme auf Pergament zurueck.
    final wurzel = buildKartoTheme(
      brightness: Brightness.light,
      centerAppBarTitle: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: wurzel,
        home: Theme(
          data: buildKartoCompatTheme(wurzel),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => openSignInScreen(context, _AuthAttrappe()),
              child: const Text('Anmelden'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    final kontext = tester.element(find.byType(SignInScreen));
    final theme = Theme.of(kontext);
    expect(theme.extension<CodexTheme>()?.showDecoration, isFalse);
    expect(theme.dialogTheme.titleTextStyle?.fontFamily, kSchriftTitel);
    // Die Anmeldung zeichnet sich dort als Kartusche mit Rueckweg.
    expect(find.byType(KartoKompassrose), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
  });
}

class _AuthAttrappe implements AuthService {
  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
  }) async => AuthUser(uid: email, email: email);

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthUser(uid: email, email: email);

  @override
  Stream<AuthUser?> watchUser() => const Stream<AuthUser?>.empty();
}
