import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/presentation/shared/constants/constants.dart';

@Injectable()
class DeleteUserUseCase {
  final UserRepository _userRepository;

  DeleteUserUseCase(this._userRepository);

  Future<Result<Unit, Failure>> call(String feedbackMessage) async {
    // Best-effort feedback; deletion should still proceed even if feedback fails.
    await _userRepository.postFeedback(feedbackMessage);

    final socialTypeResult = await _userRepository.getUserSocialType();
    final socialTypeString = socialTypeResult.successOrNull;
    final socialType = socialTypeFromString(socialTypeString);

    if (socialType == SocialType.google) {
      // Best-effort disconnect; deletion should still proceed.
      await _userRepository.disconnectGoogleSignIn();
      return _userRepository.deleteGoogleUser();
    } else if (socialType == SocialType.apple) {
      return _userRepository.deleteAppleUser();
    } else {
      return _userRepository.deleteUser();
    }
  }
}
