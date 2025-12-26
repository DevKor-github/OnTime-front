import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

@Injectable()
class SignOutUseCase {
  final UserRepository _userRepository;

  SignOutUseCase(this._userRepository);

  Future<Result<Unit, Failure>> call() async {
    return _userRepository.signOut();
  }
}
