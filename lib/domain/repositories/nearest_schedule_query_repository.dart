import '../entities/nearest_schedule_query.dart';
import '../entities/schedule_with_preparation_entity.dart';

/// A session is installation-owned, in-memory and never serializable.
abstract interface class NearestScheduleQuerySession {
  Future<NearestScheduleQuery> advance({required int candidateBudget});
  void cancel();
}

abstract interface class NearestScheduleQueryRepository {
  Stream<void> get changes;
  Future<NearestScheduleQuerySession> open(NearestQueryKey key);
  Future<ScheduleWithPreparationEntity?> readActive();
}

final class NearestQueryInvalidated implements Exception {
  const NearestQueryInvalidated();
}
