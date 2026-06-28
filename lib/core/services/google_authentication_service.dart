import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/logging/app_logger.dart';
import 'package:on_time_front/domain/entities/google_auth_credential.dart';

abstract interface class GoogleAuthenticationService {
  Stream<GoogleAuthCredential> get authenticationCredentials;

  bool get supportsAuthenticate;

  Future<void> initialize();

  Future<GoogleAuthCredential> authenticate();

  Future<void> disconnect();
}

class GoogleAuthenticationCanceledException implements Exception {
  const GoogleAuthenticationCanceledException();
}

@Singleton(as: GoogleAuthenticationService)
class GoogleSignInAuthenticationService implements GoogleAuthenticationService {
  GoogleSignInAuthenticationService({@ignoreParam GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static const _googleIosClientId =
      '456571312261-r35ah9qi0qaq7al007e2db0e0jmjcmb4.apps.googleusercontent.com';
  static const _googleServerClientId =
      '456571312261-5kuf2r6i5i7lqjr7qealv06sdgkn3hcp.apps.googleusercontent.com';
  static const _googleScopes = ['email', 'profile'];

  final GoogleSignIn _googleSignIn;
  Future<void>? _initialization;

  @override
  Stream<GoogleAuthCredential> get authenticationCredentials => _googleSignIn
      .authenticationEvents
      .where((event) => event is GoogleSignInAuthenticationEventSignIn)
      .cast<GoogleSignInAuthenticationEventSignIn>()
      .map((event) => _credentialFromAccount(event.user));

  @override
  bool get supportsAuthenticate => _googleSignIn.supportsAuthenticate();

  @override
  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await _googleSignIn.initialize(
      clientId: _googleClientId,
      serverClientId: _googleServerClientId,
    );
  }

  @override
  Future<GoogleAuthCredential> authenticate() async {
    try {
      await initialize();
      final account = await _googleSignIn.authenticate(
        scopeHint: _googleScopes,
      );
      return _credentialFromAccount(account);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleAuthenticationCanceledException();
      }
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      AppLogger.debug('Google Sign-In disconnected');
    } catch (error) {
      AppLogger.debug(
        'Google Sign-In disconnect failed errorType=${error.runtimeType}',
      );
    }
  }

  GoogleAuthCredential _credentialFromAccount(GoogleSignInAccount account) {
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw Exception('Google ID Token is null');
    }
    return GoogleAuthCredential(idToken: idToken);
  }

  String? get _googleClientId {
    if (kIsWeb) return null;
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _googleIosClientId
        : null;
  }
}
