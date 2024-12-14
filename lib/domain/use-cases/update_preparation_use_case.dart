import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

class UpdatePreparationUseCase {
  final PreparationRemoteDataSource remoteDataSource;

  UpdatePreparationUseCase(this.remoteDataSource);

  Future<void> call(PreparationStepEntity preparationStepEntity) async {
    await remoteDataSource.updatePreparation(preparationStepEntity);
  }
}
