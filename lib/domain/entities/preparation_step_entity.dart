import 'package:equatable/equatable.dart';

class PreparationStepEntity extends Equatable {
  final String id;
  final String preparationName;
  final Duration preparationTime;
  final String? nextPreparationId;

  const PreparationStepEntity({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    this.nextPreparationId,
  });

  @override
  String toString() {
    return 'PreparationStepEntity(id: $id, preparationName: $preparationName, preparationTime: $preparationTime, nextPreparationId: $nextPreparationId)';
  }

  PreparationStepEntity copyWith({
    String? id,
    String? preparationName,
    Duration? preparationTime,
    String? nextPreparationId,
  }) {
    return PreparationStepEntity(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      nextPreparationId: nextPreparationId ?? this.nextPreparationId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    preparationName,
    preparationTime,
    nextPreparationId,
  ];
}
