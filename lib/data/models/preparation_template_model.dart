import 'package:on_time_front/data/models/ordered_preparation_step_model.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_template_entity.dart';

class PreparationTemplateModel {
  final String templateId;
  final String templateName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<OrderedPreparationStepModel> preparations;

  const PreparationTemplateModel({
    required this.templateId,
    required this.templateName,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.preparations,
  });

  factory PreparationTemplateModel.fromJson(Map<String, dynamic> json) {
    return PreparationTemplateModel(
      templateId: json['templateId'] as String,
      templateName: json['templateName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      deletedAt: _optionalDateTime(json['deletedAt']),
      preparations: (json['preparations'] as List<dynamic>? ?? const [])
          .map(
            (item) => OrderedPreparationStepModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'templateName': templateName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'preparations': preparations.map((step) => step.toJson()).toList(),
  };

  PreparationTemplateEntity toEntity() {
    return PreparationTemplateEntity(
      id: templateId,
      name: templateName,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      preparation: preparations.toPreparationEntity(),
    );
  }
}

class UpsertPreparationTemplateRequestModel {
  final String templateId;
  final String templateName;
  final List<OrderedPreparationStepModel> preparations;

  const UpsertPreparationTemplateRequestModel({
    required this.templateId,
    required this.templateName,
    required this.preparations,
  });

  factory UpsertPreparationTemplateRequestModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return UpsertPreparationTemplateRequestModel(
      templateId: json['templateId'] as String,
      templateName: json['templateName'] as String,
      preparations: (json['preparations'] as List<dynamic>)
          .map(
            (item) => OrderedPreparationStepModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'templateName': templateName,
    'preparations': preparations.map((step) => step.toJson()).toList(),
  };

  static UpsertPreparationTemplateRequestModel fromEntity(
    PreparationTemplateEntity entity,
  ) {
    return UpsertPreparationTemplateRequestModel(
      templateId: entity.id,
      templateName: entity.name,
      preparations: OrderedPreparationStepModel.fromPreparationEntity(
        entity.preparation,
      ),
    );
  }

  static UpsertPreparationTemplateRequestModel fromValues({
    required String templateId,
    required String templateName,
    required PreparationEntity preparation,
  }) {
    return UpsertPreparationTemplateRequestModel(
      templateId: templateId,
      templateName: templateName,
      preparations: OrderedPreparationStepModel.fromPreparationEntity(
        preparation,
      ),
    );
  }
}

DateTime? _optionalDateTime(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return null;
}
