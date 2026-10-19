import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app/app_shell.dart';
import '../app/test_identity.dart';
import 'google_sign_in_button.dart';

/// Google login gate used by Session 1 in the local four-session preview.
///
/// This is a real Google sign-in UI, but admin authorization in this preview
/// remains local/demo-only. Production admin permissions must be verified by
/// trusted peers using the stable Google identity and the configured allowlist.
class GoogleAdminGate extends StatefulWidget {
  const GoogleAdminGate({super.key});

  @override
  State<GoogleAdminGate> createState() => _GoogleAdminGateState();
}

class _GoogleAdminGateState extends State<GoogleAdminGate> {
  GoogleSignInAccount? _account;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (TestIdentity.googleClientId.isEmpty) {
      setState(() {
        _initializing = false;
        _error = 'Manca il Google OAuth Client ID. Configuralo in '
            '%LOCALAPPDATA%\\PadelCommunity\\settings.json e riavvia '
            'la sessione 1.';
      });
      return;
    }

    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(clientId: TestIdentity.googleClientId);
      _subscription = signIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: _handleAuthenticationError,
      );
      if (mounted) {
        setState(() => _initializing = false);
      }
    } catch (error) {
      _handleAuthenticationError(error);
      if (mounted) {
        setState(() => _initializing = false);
      }
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    final account = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    if (!mounted) return;
    setState(() {
      _account = account;
      _error = null;
    });
  }

  void _handleAuthenticationError(Object error) {
    if (!mounted) return;
    setState(() {
      _account = null;
      _error = 'Accesso Google non riuscito: $error';
    });
  }

  Future<void> _signInNative() async {
    try {
      await GoogleSignIn.instance.authenticate();
    } catch (error) {
      _handleAuthenticationError(error);
    }
  }

  Future<void> _signOut() async {
    try {
      await GoogleSignIn.instance.disconnect();
      if (mounted) setState(() => _account = null);
    } catch (error) {
      _handleAuthenticationError(error);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    if (account != null) {
      return AppShell(
        isAdmin: true,
        identityLabel: account.email,
        onSignOut: _signOut,
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 54,
                  color: Color(0xFF146C5A),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Padel Community · Admin',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La sessione 1 usa un account Google reale. Le altre tre '
                  'sessioni restano giocatori simulati e non richiedono email.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_initializing)
                  const Center(child: CircularProgressIndicator())
                else if (TestIdentity.googleClientId.isNotEmpty)
                  if (usesGoogleIdentityButton)
                    Center(child: buildGoogleIdentityButton())
                  else
                    FilledButton.icon(
                      onPressed: _signInNative,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Accedi con Google'),
                    ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  SelectableText(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB3261E)),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Modalità di test locale. L’accesso Google è reale, ma '
                  'l’autorizzazione amministrativa e i dati condivisi non '
                  'sono ancora protetti da un protocollo P2P.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF68756F)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
