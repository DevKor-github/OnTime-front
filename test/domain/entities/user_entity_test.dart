import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  test('local profile derives punctuality from eligible outcomes', () {
    const entity = UserEntity(
      id: 'user-1',
      spareTime: Duration(minutes: 12),
      note: 'note',
      eligibleOutcomeCount: 4,
      onTimeOutcomeCount: 3,
    );

    expect(entity.valueOrNull, entity);
    expect(entity.spareTimeOrNull, const Duration(minutes: 12));
    expect(entity.scoreOrNull, 75);
  });

  test('empty user exposes null convenience values', () {
    const entity = UserEntity.empty();

    expect(entity.valueOrNull, isNull);
    expect(entity.spareTimeOrNull, isNull);
    expect(entity.scoreOrNull, isNull);
  });
}
