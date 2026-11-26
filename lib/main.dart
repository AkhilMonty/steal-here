import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/supabase_config.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/services/supabase_service.dart';
import 'core/themes/themes.dart';
import 'core/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (SupabaseConfig.isConfigured) {
      await SupabaseService.initialize(
        supabaseUrl: SupabaseConfig.supabaseUrl,
        publishableKey: SupabaseConfig.publishableKey,
      );

      debugPrint('Supabase initialized successfully.');
    } else {
      debugPrint(
        'Supabase credentials are not configured. '
        'Running in UI demonstration mode.',
      );
    }

    runApp(const StealHereApp());
  } catch (error, stackTrace) {
    debugPrint('Supabase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);

    runApp(const InitializationErrorApp());
  }
}

/// Root widget of the Steal Here application.
class StealHereApp extends StatefulWidget {
  const StealHereApp({super.key});

  @override
  State<StealHereApp> createState() => _StealHereAppState();
}

class _StealHereAppState extends State<StealHereApp> {
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _deepLinkSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  bool _verificationCallbackReceived = false;
  bool _verificationScreenOpened = false;
  bool _recoveryScreenOpened = false;
  bool _passwordRecoveryCallbackReceived = false;

  void _openPasswordRecoveryScreen() {
    if (!mounted || _recoveryScreenOpened) return;

    _recoveryScreenOpened = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      AppRouter.router.go(AppRoutes.resetPassword);
    });
  }

  @override
  void initState() {
    super.initState();

    _listenForAuthenticationChanges();
    _listenForDeepLinks();
  }

  void _listenForAuthenticationChanges() {
    if (!SupabaseConfig.isConfigured) return;

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      (authState) {
        // Handle password recovery before email verification.
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _passwordRecoveryCallbackReceived = true;
          _verificationCallbackReceived = false;

          AuthService.markPasswordRecoveryStarted();

          if (authState.session != null) {
            _openPasswordRecoveryScreen();
          } else {
            debugPrint('Password recovery event received without a session.');
          }

          return;
        }

        if (!_verificationCallbackReceived ||
            _passwordRecoveryCallbackReceived) {
          return;
        }

        final user = authState.session?.user;

        if (user?.emailConfirmedAt != null) {
          _openVerificationSuccessScreen(user!.email);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Authentication state error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  void _listenForDeepLinks() {
    _deepLinkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Deep link error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    _checkInitialDeepLink();
  }

  Future<void> _checkInitialDeepLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
    } catch (error, stackTrace) {
      debugPrint('Could not read initial deep link: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.scheme != 'stealhere' || uri.host != 'auth-callback') {
      return;
    }

    // Extract callback parameters from the URI.
    final fragmentParameters = Uri.splitQueryString(
      uri.fragment.contains('?') ? uri.fragment.split('?').last : uri.fragment,
    );

    final callbackType =
        uri.queryParameters['type'] ?? fragmentParameters['type'];

    try {
      String? redirectTypeName;

      final code = uri.queryParameters['code'] ?? fragmentParameters['code'];

      final hasImplicitAuthData =
          uri.fragment.contains('access_token=') ||
          uri.fragment.contains('token_hash=') ||
          uri.queryParameters.containsKey('access_token') ||
          uri.queryParameters.containsKey('token_hash');

      // Process PKCE callbacks first, including password recovery.
      if (code != null && code.isNotEmpty) {
        final response = await SupabaseService.client.auth
            .exchangeCodeForSession(code);

        redirectTypeName = response.redirectType;
      } else if (callbackType == 'email_change' || hasImplicitAuthData) {
        // Process implicit Supabase authentication callbacks.
        final response = await SupabaseService.client.auth.getSessionFromUrl(
          uri,
        );

        redirectTypeName = response.redirectType;
      }

      // Handle password recovery after establishing the session.
      if (redirectTypeName == 'passwordRecovery' ||
          callbackType == 'recovery' ||
          _passwordRecoveryCallbackReceived) {
        debugPrint('Password recovery callback processed.');

        _passwordRecoveryCallbackReceived = true;
        _verificationCallbackReceived = false;

        AuthService.markPasswordRecoveryStarted();

        if (SupabaseService.client.auth.currentSession != null) {
          _openPasswordRecoveryScreen();
        } else {
          debugPrint(
            'Password recovery callback received, but no session is available.',
          );
        }

        return;
      }

      // Never treat an email-change confirmation as registration verification.
      if (redirectTypeName == 'emailChange' || callbackType == 'email_change') {
        debugPrint('Email change confirmation callback processed.');
        return;
      }

      // Registration verification.
      if (redirectTypeName == 'signIn' ||
          callbackType == 'signup' ||
          callbackType == 'magiclink' ||
          callbackType == 'email') {
        debugPrint('Email verification callback processed.');

        _verificationCallbackReceived = true;

        await _checkVerifiedUser();
      }
    } catch (error, stackTrace) {
      debugPrint('Authentication callback processing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _checkVerifiedUser() async {
    if (!SupabaseConfig.isConfigured) return;

    // Allow Supabase a moment to process the incoming callback.
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted || !_verificationCallbackReceived) return;

    final user = SupabaseService.currentUser;

    if (user?.emailConfirmedAt != null) {
      _openVerificationSuccessScreen(user!.email);
    } else {
      debugPrint(
        'The verification callback arrived, but a confirmed '
        'Supabase user is not available yet.',
      );
    }
  }

  void _openVerificationSuccessScreen(String? email) {
    if (!mounted || _verificationScreenOpened) return;

    if (email == null || email.isEmpty) {
      debugPrint('The verified user does not have an email address.');
      return;
    }

    _verificationScreenOpened = true;

    final encodedEmail = Uri.encodeQueryComponent(email);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      AppRouter.router.go('${AppRoutes.emailVerified}?email=$encodedEmail');
    });
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    _authSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}

/// Displays a helpful message if Supabase initialization fails.
class InitializationErrorApp extends StatelessWidget {
  const InitializationErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 56,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Backend Connection Failed',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Steal Here could not initialize its backend. '
                    'Please check your Supabase configuration '
                    'and try again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
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
