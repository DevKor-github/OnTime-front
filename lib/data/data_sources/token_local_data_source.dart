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

  @override
  Future<void> storeToken(TokenEntity token) async {
    await storage.write(key: 'accesToken', value: token.accessToken);
    await storage.write(key: 'refreshToken', value: token.refreshToken);
  }

  @override
  Future<TokenEntity> getToken() async {
    try {
      final accessToken = await storage.read(key: 'accessToken');
      final refreshToken = await storage.read(key: 'refreshToken');
      return TokenEntity(
          accessToken: accessToken!, refreshToken: refreshToken!);
    } catch (e) {
      throw Exception('Error getting token');
    }
  }

  @override
  Future<void> deleteToken() async {
    await storage.delete(key: 'accessToken');
    await storage.delete(key: 'refreshToken');
  }
}
