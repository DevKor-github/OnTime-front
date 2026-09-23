import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class UpdateDefaultPreparationUseCase {
  final PreparationRepository _preparationRepository;
  final ReconcileAlarmsUseCase _reconcile;

  UpdateDefaultPreparationUseCase(this._preparationRepository, this._reconcile);

  Future<void> call(PreparationEntity preparationEntity) async {
    await _preparationRepository.updateDefaultPreparation(preparationEntity);
    requestAlarmReconciliation(_reconcile);
  }
}
