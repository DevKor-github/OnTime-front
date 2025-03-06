import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';
import 'package:rxdart/subjects.dart';

abstract class TokenLocalDataSource {
  Future<void> storeTokens(TokenEntity token);

  Future<void> storeAuthToken(String token);

  Future<TokenEntity> getToken();

  Future<void> deleteToken();

  Stream<bool> get authenticationStream;
}

@Injectable(as: TokenLocalDataSource)
class TokenLocalDataSourceImpl implements TokenLocalDataSource {
  final storage = FlutterSecureStorage();

  late final _authenticationStreamController = BehaviorSubject<bool>.seeded(
    false,
  );

  @override
  Stream<bool> get authenticationStream =>
      _authenticationStreamController.asBroadcastStream();

  final accessTokenKey = 'accessToken';
  final refreshTokenKey = 'refreshToken';

  @override
  Future<void> storeTokens(TokenEntity token) async {
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
    //_authenticationStreamController.add(false);
  }

  @override
  Future<void> storeAuthToken(String token) async {
    await storage.write(key: accessTokenKey, value: token);
    //_authenticationStreamController.add(true);
  }
}
