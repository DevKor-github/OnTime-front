import 'package:equatable/equatable.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';

class PreparationTemplateEntity extends Equatable {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final PreparationEntity preparation;

  const PreparationTemplateEntity({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.preparation,
  });

  bool get isDeleted => deletedAt != null;

  @override
  List<Object?> get props => [
    id,
    name,
    createdAt,
    updatedAt,
    deletedAt,
    preparation,
  ];
}
