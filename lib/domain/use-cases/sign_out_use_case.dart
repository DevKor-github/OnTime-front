import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

@Injectable()
class SignOutUseCase {
  final UserRepository _userRepository;

  SignOutUseCase(this._userRepository);

  Future<void> call() async {
    return _userRepository.signOut();
  }
}
