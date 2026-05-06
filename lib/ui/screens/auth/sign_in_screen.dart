import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/data/auth_service.dart';

/// Login- und Registrierungsbildschirm fuer den Heldenmanager-Web-Build.
///
/// Bietet Email/Passwort-Login und Neuregistrierung. Wird im Web als
/// Pflicht-Gate vor dem App-Shell angezeigt; auf Desktop optional ueber
/// die Einstellungen erreichbar.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, AuthService? authService})
    : _authService = authService;

  final AuthService? _authService;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final AuthService _authService = widget._authService ?? AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
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
        return 'Das Passwort ist zu schwach (mindestens 6 Zeichen).';
      case 'network-request-failed':
        return 'Keine Verbindung zum Server. Prüfe deine Internetverbindung.';
      default:
        return 'Anmeldung fehlgeschlagen: ${error.message ?? error.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
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
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-Mail',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    keyboardType: TextInputType.emailAddress,
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
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      final v = value ?? '';
                      if (v.isEmpty) return 'Bitte Passwort eingeben.';
                      if (_isRegisterMode && v.length < 6) {
                        return 'Mindestens 6 Zeichen.';
                      }
                      return null;
                    },
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
                              _errorMessage = null;
                            });
                          },
                    child: Text(
                      _isRegisterMode
                          ? 'Stattdessen anmelden'
                          : 'Neues Konto anlegen',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
