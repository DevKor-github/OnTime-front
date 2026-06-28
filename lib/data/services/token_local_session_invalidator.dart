import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/dio/interceptors/token_session_invalidator.dart';
import 'package:on_time_front/data/data_sources/token_local_data_source.dart';

@Singleton(as: TokenSessionInvalidator)
class TokenLocalSessionInvalidator implements TokenSessionInvalidator {
  TokenLocalSessionInvalidator(this._tokenLocalDataSource);

  final TokenLocalDataSource _tokenLocalDataSource;

  @override
  Future<void> signOutLocally() {
    return _tokenLocalDataSource.deleteToken();
  }
}
