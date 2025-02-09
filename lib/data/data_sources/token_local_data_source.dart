import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';

abstract class TokenLocalDataSource {
  Future<void> storeToken(TokenEntity token);

  Future<TokenEntity> getToken();

  Future<void> deleteToken();
}

@Injectable(as: TokenLocalDataSource)
class TokenLocalDataSourceImpl implements TokenLocalDataSource {
  final storage = FlutterSecureStorage();

  final accessTokenKey = 'accessToken';
  final refreshTokenKey = 'refreshToken';

  @override
  Future<void> storeToken(TokenEntity token) async {
    await storage.write(key: accessTokenKey, value: token.accessToken);
    await storage.write(key: refreshTokenKey, value: token.refreshToken);
  }

  @override
  Future<TokenEntity> getToken() async {
    try {
      final accessToken = await storage.read(key: accessTokenKey);
      final refreshToken = await storage.read(key: refreshTokenKey);
      return TokenEntity(
          accessToken: accessToken!, refreshToken: refreshToken!);
    } catch (e) {
      throw Exception('Token not found');
    }
  }

  @override
  Future<void> deleteToken() async {
    await storage.delete(key: accessTokenKey);
    await storage.delete(key: refreshTokenKey);
  }
}
