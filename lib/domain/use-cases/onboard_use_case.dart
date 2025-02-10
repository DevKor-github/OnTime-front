import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/authentication_repository.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class OnboardUseCase {
  final PreparationRepository _preparationRepository;
  final AuthenticationRepository _authenticationRepository;

  OnboardUseCase(this._preparationRepository, this._authenticationRepository);

  Future<void> call(
      {required PreparationEntity preparationEntity,
      required Duration spareTime,
      required String note}) async {
    await _preparationRepository.createDefaultPreparation(
        preparationEntity: preparationEntity, spareTime: spareTime, note: note);
    await _authenticationRepository.getUser();
  }
}
