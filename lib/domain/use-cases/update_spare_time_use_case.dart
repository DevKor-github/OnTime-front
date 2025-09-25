import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class UpdateSpareTimeUseCase {
  final PreparationRepository _preparationRepository;

  UpdateSpareTimeUseCase(this._preparationRepository);

  Future<void> call(Duration newSpareTime) async {
    await _preparationRepository.updateSpareTime(newSpareTime);
  }
}
