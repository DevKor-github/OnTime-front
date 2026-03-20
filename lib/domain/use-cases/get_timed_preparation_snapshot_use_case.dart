import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/timed_preparation_snapshot_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

@Injectable()
class GetTimedPreparationSnapshotUseCase {
  const GetTimedPreparationSnapshotUseCase(this._timedPreparationRepository);

  final TimedPreparationRepository _timedPreparationRepository;

  Future<TimedPreparationSnapshotEntity?> call(String scheduleId) {
    return _timedPreparationRepository.getTimedPreparationSnapshot(scheduleId);
  }
}
