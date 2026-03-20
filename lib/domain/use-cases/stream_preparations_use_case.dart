import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/repositories/preparation_repository.dart';

@Injectable()
class StreamPreparationsUseCase {
  final PreparationRepository _preparationRepository;

  StreamPreparationsUseCase(this._preparationRepository);

  Stream<Map<String, PreparationEntity>> call() {
    return _preparationRepository.preparationStream;
  }
}
