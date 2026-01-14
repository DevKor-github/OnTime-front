part of 'preparation_form_bloc.dart';

enum PreparationFormStatus { initial, success, adding }

final class PreparationFormState extends Equatable {
  const PreparationFormState({
    this.status = PreparationFormStatus.initial,
    this.preparationStepList = const [],
    this.isValid = false,
    this.failure,
  });

  static Result<PreparationFormState, Failure> fromEntity(
      PreparationEntity preparationEntity) {
    final steps = preparationEntity.preparationStepList;
    if (steps.isEmpty) {
      return const Success(
        PreparationFormState(
          status: PreparationFormStatus.success,
          preparationStepList: [],
        ),
      );
    }

    final tails = steps.where((s) => s.nextPreparationId == null).toList();
    if (tails.isEmpty) {
      return Err(PreparationChainFailure.noTail());
    }
    if (tails.length > 1) {
      return Err(
          PreparationChainFailure.multipleTails(tailCount: tails.length));
    }

    // Detect branching (two steps pointing to the same nextPreparationId).
    final byNextId = <String?, PreparationStepEntity>{};
    for (final step in steps) {
      final key = step.nextPreparationId; // can be null for tail
      if (byNextId.containsKey(key)) {
        return Err(
          PreparationChainFailure.broken(
            connectedCount: 0,
            totalCount: steps.length,
            cause: 'Multiple steps share nextPreparationId=$key',
          ),
        );
      }
      byNextId[key] = step;
    }

    final List<PreparationStepFormState> reversedOrder = [];
    final visited = <String>{};
    String? currentNextId; // start from tail (nextId=null)

    for (var i = 0; i < steps.length; i++) {
      final current = byNextId[currentNextId];
      if (current == null) {
        return Err(
          PreparationChainFailure.broken(
            connectedCount: reversedOrder.length,
            totalCount: steps.length,
          ),
        );
      }

      if (!visited.add(current.id)) {
        return Err(PreparationChainFailure.cycleDetected(atStepId: current.id));
      }

      reversedOrder.add(
        PreparationStepFormState(
          id: current.id,
          preparationName:
              PreparationNameInputModel.pure(current.preparationName),
          preparationTime:
              PreparationTimeInputModel.pure(current.preparationTime),
        ),
      );

      currentNextId = current.id;
    }

    if (reversedOrder.length != steps.length) {
      return Err(
        PreparationChainFailure.broken(
          connectedCount: reversedOrder.length,
          totalCount: steps.length,
        ),
      );
    }

    return Success(
      PreparationFormState(
        status: PreparationFormStatus.success,
        preparationStepList: reversedOrder.reversed.toList(),
      ),
    );
  }

  PreparationEntity toPreparationEntity() {
    final steps = preparationStepList
        .mapIndexed((index, step) => PreparationStepEntity(
              id: step.id,
              preparationName: step.preparationName.value,
              preparationTime: step.preparationTime.value,
              nextPreparationId: index < preparationStepList.length - 1
                  ? preparationStepList[index + 1].id
                  : null, // if not last step, set next step id
            ))
        .toList();
    return PreparationEntity(preparationStepList: steps);
  }

  final PreparationFormStatus status;
  final List<PreparationStepFormState> preparationStepList;
  final bool isValid;
  final Failure? failure;

  PreparationFormState copyWith({
    PreparationFormStatus? status,
    List<PreparationStepFormState>? preparationStepList,
    bool? isValid,
    Failure? failure,
  }) {
    return PreparationFormState(
      status: status ?? this.status,
      preparationStepList: preparationStepList ?? this.preparationStepList,
      isValid: isValid ?? this.isValid,
      failure: failure,
    );
  }

  @override
  List<Object> get props => [
        status,
        preparationStepList,
        isValid,
        failure ?? '',
      ];
}
