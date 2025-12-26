import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
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
  Future<Result<PreparationEntity, Failure>> call(String scheduleId) async {
    await for (final result in _preparationRepository.preparationStream) {
      if (result.isFailure) {
        return Err(result.failureOrNull!);
      }

      final preparations =
          result.successOrNull ?? const <String, PreparationEntity>{};
      final preparation = preparations[scheduleId];
      if (preparation != null) {
        return Success(preparation);
      }
    }

    // Stream should be infinite, but keep a safe fallback.
    return Err(
      UnexpectedFailure(
        code: 'PREP_STREAM_ENDED',
        message: 'Preparation stream ended unexpectedly.',
      ),
    );
  }
}
