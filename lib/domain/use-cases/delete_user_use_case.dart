import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';

@Injectable()
class DeleteUserUseCase {
  final UserRepository _userRepository;

  DeleteUserUseCase(this._userRepository);

  Future<void> call(String feedbackMessage) async {
    try {
      await _userRepository.postFeedback(feedbackMessage);
    } catch (_) {}

    final socialType = await _userRepository.getUserSocialType();
    if (socialType == 'GOOGLE') {
      await _userRepository.deleteGoogleUser();
    } else if (socialType == 'APPLE') {
      await _userRepository.deleteAppleUser();
    } else {
      await _userRepository.deleteUser();
    }
  }
}
