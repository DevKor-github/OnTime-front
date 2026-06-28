import 'package:flutter/foundation.dart';
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

  TokenLocalDataSourceImpl()
    : storage = const FlutterSecureStorage(iOptions: _appleOptions);

  @visibleForTesting
  TokenLocalDataSourceImpl.withStorage(this.storage);

  final FlutterSecureStorage storage;

  final accessTokenKey = 'accessToken';
  final refreshTokenKey = 'refreshToken';
  TokenEntity? _cachedToken;

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
    _cachedToken = token;
  }

  @override
  Future<TokenEntity> getToken() async {
    final cachedToken = _cachedToken;
    if (cachedToken != null) {
      return cachedToken;
    }

    final token = await _readToken(_appleOptions);
    if (token != null) {
      _cachedToken = token;
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
    _cachedToken = null;
  }

  @override
  Future<void> storeAuthToken(String token) async {
    await storage.write(
      key: accessTokenKey,
      value: token,
      iOptions: _appleOptions,
    );
    final cachedToken = _cachedToken;
    final refreshToken =
        cachedToken?.refreshToken ??
        await storage.read(key: refreshTokenKey, iOptions: _appleOptions);
    if (refreshToken != null) {
      _cachedToken = TokenEntity(
        accessToken: token,
        refreshToken: refreshToken,
      );
    }
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
