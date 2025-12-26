import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

@Injectable()
class LoadUserUseCase {
  final UserRepository _userRepository;

  LoadUserUseCase(this._userRepository);

  Future<Result<Unit, Failure>> call() async {
    return _userRepository.getUser();
  }
}
