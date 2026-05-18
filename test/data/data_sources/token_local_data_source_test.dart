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
