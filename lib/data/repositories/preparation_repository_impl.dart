import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:on_time_front/core/error/failures.dart';
import 'package:on_time_front/core/error/result.dart';
import 'package:on_time_front/core/error/unit.dart';
import 'package:on_time_front/core/services/error_logger_service.dart';
import 'package:on_time_front/data/data_sources/preparation_local_data_source.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';
import 'package:on_time_front/data/errors/exception_to_failure_mapper.dart';
import 'package:on_time_front/data/models/create_defualt_preparation_request_model.dart';

import 'package:on_time_front/domain/entities/preparation_entity.dart';

import 'package:on_time_front/domain/repositories/preparation_repository.dart';
import 'package:rxdart/subjects.dart';

@Singleton(as: PreparationRepository)
class PreparationRepositoryImpl implements PreparationRepository {
  final PreparationRemoteDataSource preparationRemoteDataSource;
  final PreparationLocalDataSource preparationLocalDataSource;
  final ErrorLoggerService _errorLogger;

  late final _preparationStreamController =
      BehaviorSubject<Result<Map<String, PreparationEntity>, Failure>>.seeded(
    Success(const <String, PreparationEntity>{}),
  );

  PreparationRepositoryImpl({
    required this.preparationRemoteDataSource,
    required this.preparationLocalDataSource,
    required ErrorLoggerService errorLoggerService,
  }) : _errorLogger = errorLoggerService;

  Map<String, PreparationEntity> get _currentPreparationMap =>
      _preparationStreamController.value.successOrNull ??
      const <String, PreparationEntity>{};

  void _emitPreparationMap(Map<String, PreparationEntity> map) {
    _preparationStreamController.add(Success(map));
  }

  void _emitFailure(Failure failure, {String? hint}) {
    _preparationStreamController.add(Err(failure));
    _errorLogger.log(failure, hint: hint);
  }

  @override
  Stream<Result<Map<String, PreparationEntity>, Failure>> get preparationStream =>
      _preparationStreamController.asBroadcastStream();

  @override
  Future<Result<Unit, Failure>> createDefaultPreparation(
      {required PreparationEntity preparationEntity,
      required Duration spareTime,
      required String note}) async {
    try {
      await preparationRemoteDataSource.createDefaultPreparation(
          CreateDefaultPreparationRequestModel.fromEntity(
              preparationEntity: preparationEntity,
              spareTime: spareTime,
              note: note));
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'createDefaultPreparation');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> createCustomPreparation(
      PreparationEntity preparationEntity, String scheduleId) async {
    try {
      await preparationRemoteDataSource.createCustomPreparation(
          preparationEntity, scheduleId);
      _emitPreparationMap(
        Map.from(_currentPreparationMap)..[scheduleId] = preparationEntity,
      );
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'createCustomPreparation');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> getPreparationByScheduleId(
      String scheduleId) async {
    try {
      final remotePreparation = await preparationRemoteDataSource
          .getPreparationByScheduleId(scheduleId);
      _emitPreparationMap(
        Map.from(_currentPreparationMap)..[scheduleId] = remotePreparation,
      );
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      _emitFailure(failure, hint: 'getPreparationByScheduleId');
      return Err(failure);
    }
  }

  @override
  Future<Result<PreparationEntity, Failure>> getDefualtPreparation() async {
    try {
      final remotePreparation =
          await preparationRemoteDataSource.getDefualtPreparation();
      return Success(remotePreparation);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'getDefaultPreparation');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> updateDefaultPreparation(
      PreparationEntity preparationEntity) async {
    try {
      await preparationRemoteDataSource
          .updateDefaultPreparation(preparationEntity);
      // await preparationLocalDataSource.updatePreparation(preparationEntity);
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'updateDefaultPreparation');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> updatePreparationByScheduleId(
      PreparationEntity preparationEntity, String scheduleId) async {
    try {
      await preparationRemoteDataSource.updatePreparationByScheduleId(
          preparationEntity, scheduleId);
      _emitPreparationMap(
        Map.from(_currentPreparationMap)..[scheduleId] = preparationEntity,
      );
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      _emitFailure(failure, hint: 'updatePreparationByScheduleId');
      return Err(failure);
    }
  }

  @override
  Future<Result<Unit, Failure>> updateSpareTime(Duration newSpareTime) async {
    try {
      await preparationRemoteDataSource.updateSpareTime(newSpareTime);
      return Success(unit);
    } catch (e) {
      final failure = ExceptionToFailureMapper.map(e, StackTrace.current);
      await _errorLogger.log(failure, hint: 'updateSpareTime');
      return Err(failure);
    }
  }
}
