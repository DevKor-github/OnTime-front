class PreparationEntity {
  final int id;
  final String preparationName;
  final int preparationTime;
  final int order;

  PreparationEntity({
    required this.id,
    required this.preparationName,
    required this.preparationTime,
    required this.order,
  });

  @override
  String toString() {
    return 'PreparationEntity(id: $id, preparationName: $preparationName, preparationTime: $preparationTime, order: $order)';
  }
}
