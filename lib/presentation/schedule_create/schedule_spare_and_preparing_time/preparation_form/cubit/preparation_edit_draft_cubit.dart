import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';

/// Shared draft state for the `/preparationEdit` flow.
///
/// The caller sets a draft before navigating. The editor overwrites it on Save.
/// The caller reads it after pop and then clears it.
@LazySingleton()
class PreparationEditDraftCubit extends Cubit<PreparationEntity?> {
  PreparationEditDraftCubit() : super(null);

  void setDraft(PreparationEntity draft) => emit(draft);

  void clear() => emit(null);
}


