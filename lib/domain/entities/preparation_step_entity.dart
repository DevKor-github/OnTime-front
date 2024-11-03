class PreparationStepEntity {
  final int id;
  final String preparationName;
  final int preparationTime;
  final int order;

  PreparationStepEntity({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.order,
  });

  @override
  String toString() {
    return 'PreparationStepEntity(id: $id, preparationName: $preparationName, preparationTime: $preparationTime, order: $order)';
  }
}
