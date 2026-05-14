import 'package:json_annotation/json_annotation.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class OrderedPreparationStepModel {
  @JsonKey(name: 'preparationId')
  final String id;
  final String preparationName;
  final int preparationTime;
  final int orderIndex;

  const OrderedPreparationStepModel({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.orderIndex,
  });

  factory OrderedPreparationStepModel.fromJson(Map<String, dynamic> json) {
    return OrderedPreparationStepModel(
      id: json['preparationId'] as String,
      preparationName: json['preparationName'] as String,
      preparationTime: (json['preparationTime'] as num).toInt(),
      orderIndex: (json['orderIndex'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'preparationId': id,
    'preparationName': preparationName,
    'preparationTime': preparationTime,
    'orderIndex': orderIndex,
  };

  static List<OrderedPreparationStepModel> fromPreparationEntity(
    PreparationEntity preparation,
  ) {
    final orderedSteps = preparation.ordered.preparationStepList;
    return [
      for (var index = 0; index < orderedSteps.length; index++)
        OrderedPreparationStepModel.fromEntity(
          orderedSteps[index],
          orderIndex: index,
        ),
    ];
  }

  static OrderedPreparationStepModel fromEntity(
    PreparationStepEntity entity, {
    required int orderIndex,
  }) {
    return OrderedPreparationStepModel(
      id: entity.id,
      preparationName: entity.preparationName,
      preparationTime: entity.preparationTime.inMinutes,
      orderIndex: orderIndex,
    );
  }

  PreparationStepEntity toEntity({String? nextPreparationId}) {
    return PreparationStepEntity(
      id: id,
      preparationName: preparationName,
      preparationTime: Duration(minutes: preparationTime),
      nextPreparationId: nextPreparationId,
    );
  }
}

extension OrderedPreparationStepModelListExtension
    on List<OrderedPreparationStepModel> {
  PreparationEntity toPreparationEntity() {
    final sorted = [...this]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return PreparationEntity(
      preparationStepList: [
        for (var index = 0; index < sorted.length; index++)
          sorted[index].toEntity(
            nextPreparationId: index + 1 < sorted.length
                ? sorted[index + 1].id
                : null,
          ),
      ],
    );
  }
}
