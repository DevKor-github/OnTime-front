import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';

@Injectable()
class StreamUserUseCase {
  final AuthenticationRepository _authenticationRepository;

  StreamUserUseCase(this._authenticationRepository);

  Stream<UserEntity> call() {
    return _authenticationRepository.userStream;
  }
}
