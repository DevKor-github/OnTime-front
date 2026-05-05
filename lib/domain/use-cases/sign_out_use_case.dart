import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/use-cases/cancel_all_alarms_use_case.dart';

@Injectable()
class SignOutUseCase {
  final UserRepository _userRepository;
  final CancelAllAlarmsUseCase _cancelAllAlarmsUseCase;

  SignOutUseCase(this._userRepository, this._cancelAllAlarmsUseCase);

  Future<void> call() async {
    await _cancelAllAlarmsUseCase(unregisterDevice: true);
    return _userRepository.signOut();
  }
}
