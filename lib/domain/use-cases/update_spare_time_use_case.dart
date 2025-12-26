import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class UpdateSpareTimeUseCase {
  final PreparationRepository _preparationRepository;

  UpdateSpareTimeUseCase(this._preparationRepository);

  Future<Result<Unit, Failure>> call(Duration newSpareTime) async {
    return _preparationRepository.updateSpareTime(newSpareTime);
  }
}
