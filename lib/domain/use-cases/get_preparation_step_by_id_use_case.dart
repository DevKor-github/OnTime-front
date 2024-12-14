import 'package:on_time_front/domain/entities/preparation_step_entity.dart';
import 'package:on_time_front/data/data_sources/preparation_remote_data_source.dart';

class GetPreparationStepByIdUseCase {
  final PreparationRemoteDataSource remoteDataSource;

  GetPreparationStepByIdUseCase(this.remoteDataSource);

  Future<PreparationStepEntity> call(String preparationStepId) async {
    return await remoteDataSource.getPreparationStepById(preparationStepId);
  }
}
