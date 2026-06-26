import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';

abstract class TokenLocalDataSource {
  Future<void> storeTokens(TokenEntity token);

  Future<void> storeAuthToken(String token);

  Future<TokenEntity> getToken();

  Future<void> deleteToken();
}

@Injectable(as: TokenLocalDataSource)
class TokenLocalDataSourceImpl implements TokenLocalDataSource {
  static const _appleOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  final storage = const FlutterSecureStorage(iOptions: _appleOptions);

  final accessTokenKey = 'accessToken';
  final refreshTokenKey = 'refreshToken';

  @override
  Future<void> storeTokens(TokenEntity token) async {
    await storage.write(
      key: accessTokenKey,
      value: token.accessToken,
      iOptions: _appleOptions,
    );
    await storage.write(
      key: refreshTokenKey,
      value: token.refreshToken,
      iOptions: _appleOptions,
    );
  }

  @override
  Future<TokenEntity> getToken() async {
    final token = await _readToken(_appleOptions);
    if (token != null) {
      return token;
    }

    final legacyToken = await _readToken(IOSOptions.defaultOptions);
    if (legacyToken != null) {
      await storeTokens(legacyToken);
      return legacyToken;
    }

    throw Exception('Token not found');
  }

  @override
  Future<void> deleteToken() async {
    await storage.delete(key: accessTokenKey, iOptions: _appleOptions);
    await storage.delete(key: refreshTokenKey, iOptions: _appleOptions);
    await storage.delete(
      key: accessTokenKey,
      iOptions: IOSOptions.defaultOptions,
    );
    await storage.delete(
      key: refreshTokenKey,
      iOptions: IOSOptions.defaultOptions,
    );
  }

  @override
  Future<void> storeAuthToken(String token) async {
    await storage.write(
      key: accessTokenKey,
      value: token,
      iOptions: _appleOptions,
    );
  }

  Future<TokenEntity?> _readToken(IOSOptions options) async {
    final accessToken = await storage.read(
      key: accessTokenKey,
      iOptions: options,
    );
    final refreshToken = await storage.read(
      key: refreshTokenKey,
      iOptions: options,
    );
    if (accessToken == null || refreshToken == null) {
      return null;
    }
    return TokenEntity(accessToken: accessToken, refreshToken: refreshToken);
  }
}
