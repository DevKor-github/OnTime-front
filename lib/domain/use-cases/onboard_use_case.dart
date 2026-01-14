import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/user_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class OnboardUseCase {
  final PreparationRepository _preparationRepository;
  final UserRepository _userRepository;

  OnboardUseCase(this._preparationRepository, this._userRepository);

  Future<Result<Unit, Failure>> call(
      {required PreparationEntity preparationEntity,
      required Duration spareTime,
      required String note}) async {
    final result = await _preparationRepository.createDefaultPreparation(
        preparationEntity: preparationEntity, spareTime: spareTime, note: note);
    if (result.isFailure) return Err(result.failureOrNull!);

    final userResult = await _userRepository.getUser();
    if (userResult.isFailure) return Err(userResult.failureOrNull!);

    return Success(unit);
  }
}
