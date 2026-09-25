import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class CreateCustomPreparationUseCase {
  final PreparationRepository _preparationRepository;
  final ReconcileAlarmsUseCase _reconcile;

  CreateCustomPreparationUseCase(this._preparationRepository, this._reconcile);

  Future<void> call(
    PreparationEntity preparationEntity,
    String scheduleId,
  ) async {
    await _preparationRepository.createCustomPreparation(
      preparationEntity,
      scheduleId,
    );
    requestAlarmReconciliation(_reconcile);
  }
}
