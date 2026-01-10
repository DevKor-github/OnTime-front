import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class GetPreparationByScheduleIdUseCase {
  final PreparationRepository _preparationRepository;

  GetPreparationByScheduleIdUseCase(this._preparationRepository);

  /// Gets preparation for the given schedule ID from the stream.
  /// Returns the preparation entity if it exists in the stream.
  ///
  /// [scheduleId] - The ID of the schedule to get preparation for
  Future<PreparationEntity> call(String scheduleId) async {
    return await _preparationRepository.preparationStream
        .map((preparations) => preparations[scheduleId])
        .where((preparation) => preparation != null)
        .cast<PreparationEntity>()
        .first;
  }
}
