import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

@Injectable()
class LoadUserUseCase {
  final UserRepository _userRepository;

  LoadUserUseCase(this._userRepository);

  Future<void> call() async {
    await _userRepository.getUser();
  }
}
