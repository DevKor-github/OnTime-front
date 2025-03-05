import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

@Injectable()
class StreamUserUseCase {
  final UserRepository _userRepository;

  StreamUserUseCase(this._userRepository);

  Stream<UserEntity> call() {
    return _userRepository.userStream;
  }
}
