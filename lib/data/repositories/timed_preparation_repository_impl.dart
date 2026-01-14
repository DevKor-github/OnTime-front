import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/core/services/error_logger_service.dart';
import 'package:on_time_front/data/data_sources/preparation_with_time_local_data_source.dart';
import 'package:on_time_front/data/errors/exception_to_failure_mapper.dart';
import 'package:on_time_front/domain/entities/preparation_with_time_entity.dart';
import 'package:on_time_front/domain/repositories/timed_preparation_repository.dart';

@Singleton(as: TimedPreparationRepository)
class TimedPreparationRepositoryImpl implements TimedPreparationRepository {
  final PreparationWithTimeLocalDataSource localDataSource;
  final ErrorLoggerService _errorLogger;

  TimedPreparationRepositoryImpl({
    required this.localDataSource,
    required ErrorLoggerService errorLoggerService,
  }) : _errorLogger = errorLoggerService;

  @override
  Future<Result<Unit, Failure>> clearTimedPreparation(String scheduleId) async {
    try {
      await localDataSource.clearPreparation(scheduleId);
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'clearTimedPreparation');
      return Err(failure);
    }
  }

  @override
  Future<Result<PreparationWithTimeEntity?, Failure>> getTimedPreparation(
      String scheduleId) async {
    try {
      final result = await localDataSource.loadPreparation(scheduleId);
      return Success(result);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'getTimedPreparation');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> saveTimedPreparation(
      String scheduleId, PreparationWithTimeEntity preparation) async {
    try {
      await localDataSource.savePreparation(scheduleId, preparation);
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'saveTimedPreparation');
      return Err(failure);
    }
  }
}
