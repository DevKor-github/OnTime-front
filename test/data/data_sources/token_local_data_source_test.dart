import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';
import 'package:on_time_front/domain/entities/token_entity.dart';

void main() {
  late TokenLocalDataSourceImpl dataSource;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    dataSource = TokenLocalDataSourceImpl();
  });

  test('stores and reads access and refresh tokens together', () async {
    const token = TokenEntity(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );

    await dataSource.storeTokens(token);

    expect(await dataSource.getToken(), token);
  });

  test(
    'does not reread secure storage after the token cache is warm',
    () async {
      const token = TokenEntity(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );
      final storage = _CountingSecureStorage({
        'accessToken': token.accessToken,
        'refreshToken': token.refreshToken,
      });
      dataSource = TokenLocalDataSourceImpl.withStorage(storage);

      expect(await dataSource.getToken(), token);
      expect(await dataSource.getToken(), token);

      expect(storage.readsByKey, {'accessToken': 1, 'refreshToken': 1});
    },
  );

  test('auth token write only updates the access token slot', () async {
    await dataSource.storeTokens(
      const TokenEntity(
        accessToken: 'old-access',
        refreshToken: 'refresh-token',
      ),
    );

    await dataSource.storeAuthToken('new-access');

    expect(
      await dataSource.getToken(),
      const TokenEntity(
        accessToken: 'new-access',
        refreshToken: 'refresh-token',
      ),
    );
  });

  test(
    'auth token write warms the cache when refresh token is persisted',
    () async {
      final storage = _CountingSecureStorage({'refreshToken': 'refresh-token'});
      dataSource = TokenLocalDataSourceImpl.withStorage(storage);

      await dataSource.storeAuthToken('new-access');
      storage.readsByKey.clear();

      expect(
        await dataSource.getToken(),
        const TokenEntity(
          accessToken: 'new-access',
          refreshToken: 'refresh-token',
        ),
      );
      expect(storage.readsByKey, isEmpty);
    },
  );

  test(
    'legacy token load migrates to current storage and warms cache',
    () async {
      const legacyToken = TokenEntity(
        accessToken: 'legacy-access',
        refreshToken: 'legacy-refresh',
      );
      final storage = _LegacyTokenSecureStorage(
        currentValues: {},
        legacyValues: {
          'accessToken': legacyToken.accessToken,
          'refreshToken': legacyToken.refreshToken,
        },
      );
      dataSource = TokenLocalDataSourceImpl.withStorage(storage);

      expect(await dataSource.getToken(), legacyToken);
      storage.readsByKey.clear();

      expect(await dataSource.getToken(), legacyToken);
      expect(storage.currentValues, {
        'accessToken': legacyToken.accessToken,
        'refreshToken': legacyToken.refreshToken,
      });
      expect(storage.readsByKey, isEmpty);
    },
  );

  test(
    'delete removes both token values and missing tokens fail clearly',
    () async {
      await dataSource.storeTokens(
        const TokenEntity(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );

      await dataSource.deleteToken();

      await expectLater(
        dataSource.getToken(),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Token not found'),
          ),
        ),
      );
    },
  );
}

class _CountingSecureStorage extends FlutterSecureStorage {
  _CountingSecureStorage(this.values);

  final Map<String, String?> values;
  final readsByKey = <String, int>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    readsByKey[key] = (readsByKey[key] ?? 0) + 1;
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

class _LegacyTokenSecureStorage extends FlutterSecureStorage {
  _LegacyTokenSecureStorage({
    required this.currentValues,
    required this.legacyValues,
  });

  final Map<String, String?> currentValues;
  final Map<String, String?> legacyValues;
  final readsByKey = <String, int>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    readsByKey[key] = (readsByKey[key] ?? 0) + 1;
    return _valuesFor(iOptions)[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _valuesFor(iOptions)[key] = value;
  }

  Map<String, String?> _valuesFor(AppleOptions? iOptions) {
    return iOptions?.accessibility ==
            KeychainAccessibility.first_unlock_this_device
        ? currentValues
        : legacyValues;
  }
}
