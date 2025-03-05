import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';

@Injectable()
class SignOutUseCase {
  final UserRepository _authenticationRepository;

  SignOutUseCase(this._authenticationRepository);

  Future<void> call() async {
    return _authenticationRepository.signOut();
  }
}
