import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/domain/entities/nearest_schedule_query.dart';
import 'package:on_time_front/domain/entities/schedule_with_preparation_entity.dart';
import 'package:on_time_front/domain/repositories/nearest_schedule_query_repository.dart';

@Injectable()
class GetNearestUpcomingScheduleUseCase {
  GetNearestUpcomingScheduleUseCase(
    this._repository, {
    @ignoreParam DateTime Function()? now,
    @ignoreParam int chunkSize = 1024,
  }) : _now = now ?? DateTime.now,
       _chunkSize = chunkSize;
  final NearestScheduleQueryRepository _repository;
  final DateTime Function() _now;
  final int _chunkSize;

  Future<ScheduleWithPreparationEntity?> readActive() =>
      _repository.readActive();

  Stream<NearestScheduleQuery> call({required NearestQueryKey key}) {
    late StreamController<NearestScheduleQuery> output;
    StreamSubscription<void>? changes;
    NearestScheduleQuerySession? session;
    NearestQueryKey? sessionRequest;
    var completedSession = false;
    Timer? boundary;
    var closed = false;
    var paused = false;
    Completer<void>? resumed;
    Future<void> waitForResume() async {
      while (paused && !closed) {
        resumed ??= Completer<void>();
        await resumed!.future;
      }
    }

    var owner = 0;
    var revision = key.revision;
    var dirty = false;
    var running = false;
    NearestVerifiedSchedule? previous;
    bool current(int value) =>
        !closed &&
        owner == value &&
        key.generation == LocalDataOperationGate.shared.generation &&
        LocalDataOperationGate.shared.isAvailable;
    Future<void> drain({bool revalidateCompleted = false}) async {
      if (running || closed) {
        dirty = true;
        return;
      }
      running = true;
      var reuseCompleted =
          revalidateCompleted && session != null && sessionRequest != null;
      do {
        await waitForResume();
        if (closed) break;
        final reuse = reuseCompleted && !dirty;
        reuseCompleted = false;
        dirty = false;
        final run = ++owner;
        final request = reuse
            ? sessionRequest!
            : NearestQueryKey(
                generation: key.generation,
                epoch: key.epoch,
                revision: revision++,
              );
        boundary?.cancel();
        if (!reuse) {
          session?.cancel();
          session = null;
          sessionRequest = null;
        }
        completedSession = false;
        if (!current(run)) break;
        output.add(
          NearestQueryLoading(
            key: request,
            stale: previous,
            progress: const NearestQueryProgress(
              visitedCandidates: 0,
              candidateBudget: 200000,
              provenSegments: 0,
              totalSegments: 0,
            ),
          ),
        );
        try {
          final opened = reuse ? session! : await _repository.open(request);
          if (!current(run)) {
            opened.cancel();
            break;
          }
          session = opened;
          sessionRequest = request;
          while (current(run) && !dirty) {
            await waitForResume();
            if (!current(run) || dirty) break;
            final result = await opened.advance(candidateBudget: _chunkSize);
            await waitForResume();
            if (!current(run) || dirty) break;
            if (result is NearestQueryLimited && result.canContinue) {
              output.add(
                NearestQueryLoading(
                  key: request,
                  stale: previous,
                  progress: result.progress,
                  issues: result.issues,
                ),
              );
              await Future<void>.delayed(Duration.zero);
              continue;
            }
            if (result is NearestQueryReady) {
              previous = result.value;
              final delay =
                  result.value.resolution.instantUtc!.difference(
                    _now().toUtc(),
                  ) +
                  const Duration(microseconds: 1);
              boundary = Timer(
                delay < const Duration(milliseconds: 1)
                    ? const Duration(milliseconds: 1)
                    : delay,
                () {
                  unawaited(drain());
                },
              );
            }
            if (result is NearestQueryEmpty) previous = null;
            completedSession = true;
            output.add(
              result is NearestQueryError
                  ? NearestQueryError(
                      key: request,
                      reason: result.reason,
                      stale: previous,
                      issues: result.issues,
                    )
                  : result is NearestQueryLimited
                  ? NearestQueryLimited(
                      key: request,
                      reason: result.reason,
                      progress: result.progress,
                      canContinue: result.canContinue,
                      canRetry: result.canRetry,
                      stale: previous,
                      issues: result.issues,
                    )
                  : result,
            );
            break;
          }
        } on NearestQueryInvalidated {
          if (current(run)) dirty = true;
        } catch (_) {
          await waitForResume();
          if (current(run) && !dirty) {
            completedSession = true;
            output.add(
              NearestQueryError(
                key: request,
                reason: NearestQueryFailureReason.storeReadFailed,
                stale: previous,
              ),
            );
          }
        }
      } while (dirty && !closed);
      running = false;
    }

    output = StreamController<NearestScheduleQuery>(
      onListen: () {
        changes = _repository.changes.listen(
          (_) {
            unawaited(drain());
          },
          onError: (Object error, StackTrace stack) {
            owner++;
            session?.cancel();
            session = null;
            sessionRequest = null;
            completedSession = true;
            boundary?.cancel();
            if (!closed) {
              output.add(
                NearestQueryError(
                  key: NearestQueryKey(
                    generation: key.generation,
                    epoch: key.epoch,
                    revision: revision++,
                  ),
                  reason: NearestQueryFailureReason.storeReadFailed,
                  stale: previous,
                ),
              );
            }
          },
        );
        unawaited(drain());
      },
      onPause: () {
        paused = true;
      },
      onResume: () {
        paused = false;
        resumed?.complete();
        resumed = null;
        // A terminal receipt may already be queued in the consumer when it
        // pauses. Revalidate the same completed cursor instead of replaying a
        // cached receipt or resetting its candidate budget on Continue.
        if (completedSession) {
          if (running) {
            // A watch failure may have retired an in-flight operation. Its
            // eventual completion must hand off to a fresh current read.
            dirty = true;
          } else {
            unawaited(drain(revalidateCompleted: true));
          }
        }
      },
      onCancel: () async {
        closed = true;
        resumed?.complete();
        resumed = null;
        owner++;
        boundary?.cancel();
        session?.cancel();
        await changes?.cancel();
      },
    );
    return output.stream;
  }
}
