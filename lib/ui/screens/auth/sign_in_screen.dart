import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';
import 'package:dsa_heldenverwaltung/ui/screens/legal/legal_pages.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/karto_variante.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_rahmen.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_papier.dart';

/// Login- und Registrierungsbildschirm fuer den Heldenmanager-Web-Build.
///
/// Bietet Email/Passwort-Login und Neuregistrierung. Wird im Web als
/// Pflicht-Gate vor dem App-Shell angezeigt; auf Desktop optional ueber
/// die Einstellungen erreichbar.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this._authService,
    this.initialRegisterMode = false,
  });

  final AuthService? _authService;

  /// Startet direkt im Registriermodus statt im Login.
  final bool initialRegisterMode;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final AuthService _authService = widget._authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late bool _isRegisterMode = widget.initialRegisterMode;
  bool _privacyNoticeAcknowledged = false;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      if (_isRegisterMode) {
        await _authService.registerWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await _authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      // Beim Erfolg uebernimmt der WebAuthGate via authStateChanges().
      // Als gepushte Route schliesst sich der Screen selbst, damit er einen
      // Profilwechsel unterhalb der MaterialApp nicht ueberlebt.
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      setState(() {
        _errorMessage = _localizeError(error);
      });
    } on Object catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = 'Bitte gib zuerst eine gültige E-Mail-Adresse ein.';
      });
      return;
    }
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) {
        return;
      }
      _showPasswordResetConfirmation();
    } on FirebaseAuthException catch (error) {
      if (mounted && error.code == 'user-not-found') {
        _showPasswordResetConfirmation();
      } else if (mounted) {
        setState(() {
          _errorMessage = _localizeError(error);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showPasswordResetConfirmation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Falls ein Konto existiert, wurde eine E-Mail zum Zurücksetzen '
          'gesendet.',
        ),
      ),
    );
  }

  String _localizeError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Bitte gib eine gültige E-Mail-Adresse ein.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-Mail oder Passwort sind nicht korrekt.';
      case 'email-already-in-use':
        return 'Für diese E-Mail existiert bereits ein Konto.';
      case 'weak-password':
        return 'Das Passwort ist zu schwach (mindestens 12 Zeichen).';
      case 'network-request-failed':
        return 'Keine Verbindung zum Server. Prüfe deine Internetverbindung.';
      default:
        return 'Anmeldung fehlgeschlagen: ${error.message ?? error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formular = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DSA-Heldenverwaltung',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _isRegisterMode
                ? 'Neues Konto anlegen'
                : 'Anmelden, um deine Helden zu synchronisieren',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-Mail',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Bitte E-Mail eingeben.';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Bitte gültige E-Mail eingeben.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Passwort',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  autofillHints: [
                    _isRegisterMode
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  textInputAction: _isRegisterMode
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: _isRegisterMode ? null : (_) => _submit(),
                  validator: (value) {
                    final v = value ?? '';
                    if (v.isEmpty) return 'Bitte Passwort eingeben.';
                    if (_isRegisterMode && v.length < 12) {
                      return 'Mindestens 12 Zeichen.';
                    }
                    return null;
                  },
                ),
                if (_isRegisterMode) ...[
                  const SizedBox(height: 16),
                  FormField<bool>(
                    initialValue: _privacyNoticeAcknowledged,
                    validator: (value) => value == true
                        ? null
                        : 'Bitte bestätige die Kenntnisnahme.',
                    builder: (field) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: _privacyNoticeAcknowledged,
                          onChanged: _isBusy
                              ? null
                              : (value) {
                                  final acknowledged = value ?? false;
                                  setState(() {
                                    _privacyNoticeAcknowledged = acknowledged;
                                  });
                                  field.didChange(acknowledged);
                                },
                          title: const Text(
                            'Ich habe die Datenschutzerklärung zur Kenntnis '
                            'genommen.',
                          ),
                        ),
                        TextButton(
                          onPressed: _openPrivacyPolicy,
                          child: const Text('Datenschutzerklärung'),
                        ),
                        if (field.hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              field.errorText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isBusy ? null : _submit,
            child: _isBusy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isRegisterMode ? 'Konto anlegen' : 'Anmelden'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isBusy
                ? null
                : () {
                    setState(() {
                      _isRegisterMode = !_isRegisterMode;
                      _privacyNoticeAcknowledged = false;
                      _errorMessage = null;
                    });
                  },
            child: Text(
              _isRegisterMode ? 'Stattdessen anmelden' : 'Neues Konto anlegen',
            ),
          ),
          if (!_isRegisterMode)
            TextButton(
              onPressed: _isBusy ? null : _sendPasswordReset,
              child: const Text('Passwort vergessen?'),
            ),
        ],
      ),
    );
    final karto = kartoVariante(context);
    if (karto == null) {
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: formular,
            ),
          ),
        ),
      );
    }
    // Unter Kartograph eine Kartusche auf dem Papier, mit Kompassrose ueber
    // dem Titel. Scrollbar, damit grosse Schrift das Formular nicht
    // abschneidet; ein Rueckweg nur, wenn es einen gibt.
    return Scaffold(
      appBar: Navigator.of(context).canPop() ? AppBar() : null,
      body: KartoPapier(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: karto.feld,
                  shape: KartoRahmen(
                    side: BorderSide(
                      color: karto.hoehenlinie,
                      width: Strich.hoehenlinie,
                    ),
                    akzent: karto.messing,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: KartoKompassrose(groesse: 72)),
                      const SizedBox(height: 16),
                      formular,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
    );
  }
}
