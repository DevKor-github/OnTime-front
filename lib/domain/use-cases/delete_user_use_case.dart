import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

@Injectable()
class DeleteUserUseCase {
  final UserRepository _userRepository;

  DeleteUserUseCase(this._userRepository);

  Future<void> call(String feedbackMessage) async {
    try {
      await _userRepository.postFeedback(feedbackMessage);
    } catch (_) {}

    final socialTypeString = await _userRepository.getUserSocialType();
    final socialType = socialTypeFromString(socialTypeString);
    if (socialType == SocialType.google) {
      await _userRepository.deleteGoogleUser();
    } else if (socialType == SocialType.apple) {
      await _userRepository.deleteAppleUser();
    } else {
      await _userRepository.deleteUser();
    }
  }
}
