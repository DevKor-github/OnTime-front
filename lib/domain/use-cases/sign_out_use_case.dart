import 'package:injectable/injectable.dart';
import 'package:on_time_front/data/repositories/authentication_repository_impl.dart';

@Injectable()
class SignOutUseCase {
  final AuthenticationRepositoryImpl _authenticationRepository;

  SignOutUseCase(this._authenticationRepository);

  Future<void> call() async {
    return _authenticationRepository.signOut();
  }
}
