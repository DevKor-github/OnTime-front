import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

@Injectable()
class StreamUserUseCase {
  final UserRepository _userRepository;

  StreamUserUseCase(this._userRepository);

  Stream<Result<UserEntity, Failure>> call() {
    return _userRepository.userStream;
  }
}
