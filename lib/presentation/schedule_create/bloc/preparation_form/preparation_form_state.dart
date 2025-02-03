part of 'preparation_form_bloc.dart';

enum PreparationFormStatus { initial, loading, success, error }

final class PreparationFormState extends Equatable {
  const PreparationFormState({
    this.status = PreparationFormStatus.initial,
    this.preparationStepList = const [],
  });

  factory PreparationFormState.fromEntity(PreparationEntity preparationEntity) {
    final List<PreparationStepFormState> preparationStepFormStateList = [];
    String? nextPreparationStepId;

    final int length = preparationEntity.preparationStepList.length;
    for (var i = 0; i < length; i++) {
      for (var j = 0; j < length; j++) {
        final currentPreparationStep = preparationEntity.preparationStepList[j];
        if (currentPreparationStep.nextPreparationId == nextPreparationStepId) {
          nextPreparationStepId = currentPreparationStep.id;
          preparationStepFormStateList.add(
            PreparationStepFormState(
              id: currentPreparationStep.id,
              preparationName: currentPreparationStep.preparationName,
              preparationTime: currentPreparationStep.preparationTime,
              order: length - i - 1,
              focusNode: FocusNode(),
            ),
          );
          break;
        }
      }
    }
    return PreparationFormState(
      status: PreparationFormStatus.success,
      preparationStepList: preparationStepFormStateList,
    );
  }

  PreparationEntity toPreparationEntity() {
    final sortedList = List<PreparationStepFormState>.from(preparationStepList)
      ..sort((a, b) => a.order.compareTo(b.order));
    final steps = sortedList
        .mapIndexed((index, step) => PreparationStepEntity(
              id: step.id,
              preparationName: step.preparationName,
              preparationTime: step.preparationTime,
              nextPreparationId: index < sortedList.length - 1
                  ? sortedList[index + 1].id
                  : null, // if not last step, set next step id
            ))
        .toList();
    return PreparationEntity(preparationStepList: steps);
  }

  final PreparationFormStatus status;
  final List<PreparationStepFormState> preparationStepList;

  PreparationFormState copyWith({
    PreparationFormStatus? status,
    List<PreparationStepFormState>? preparationStepList,
  }) {
    return PreparationFormState(
      status: status ?? this.status,
      preparationStepList: preparationStepList ?? this.preparationStepList,
    );
  }

  @override
  List<Object> get props => [
        status,
        ...preparationStepList,
      ];
}

final class PreparationStepFormState extends Equatable {
  const PreparationStepFormState({
    required this.id,
    required this.preparationName,
    this.preparationTime = const Duration(minutes: 0),
    required this.focusNode,
    required this.order,
  });

  final String id;
  final String preparationName;
  final Duration preparationTime;
  final FocusNode focusNode;
  final int order;

  PreparationStepFormState copyWith(
      {String? id,
      String? preparationName,
      Duration? preparationTime,
      FocusNode? focusNode,
      int? order}) {
    return PreparationStepFormState(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      focusNode: focusNode ?? this.focusNode,
      order: order ?? this.order,
    );
  }

  @override
  List<Object> get props => [
        id,
        preparationName,
        preparationTime,
        focusNode,
        order,
      ];
}
