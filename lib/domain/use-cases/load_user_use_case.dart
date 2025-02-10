import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';

@Injectable()
class LoadUserUseCase {
  final AuthenticationRepository _authenticationRepository;

  LoadUserUseCase(this._authenticationRepository);

  Future<void> call() async {
    await _authenticationRepository.getUser();
  }
}
