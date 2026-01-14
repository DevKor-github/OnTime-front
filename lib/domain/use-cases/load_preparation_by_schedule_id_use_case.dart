import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class LoadPreparationByScheduleIdUseCase {
  final PreparationRepository _preparationRepository;

  LoadPreparationByScheduleIdUseCase(this._preparationRepository);

  /// Loads preparation for the given schedule ID.
  /// This triggers fetching preparation from the remote data source
  /// and updating the local cache/stream.
  ///
  /// [scheduleId] - The ID of the schedule to load preparation for
  Future<Result<Unit, Failure>> call(String scheduleId) async {
    return _preparationRepository.getPreparationByScheduleId(scheduleId);
  }
}
