import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  test('user exposes profile convenience values', () {
    const entity = UserEntity(
      id: 'user-1',
      email: 'user@example.com',
      name: 'User',
      spareTime: Duration(minutes: 12),
      note: 'note',
      score: 4.5,
    );

    expect(entity.valueOrNull, entity);
    expect(entity.spareTimeOrNull, const Duration(minutes: 12));
    expect(entity.scoreOrNull, 4.5);
    expect(entity.nameOrNull, 'User');
    expect(entity.emailOrNull, 'user@example.com');
  });

  test('empty user exposes null convenience values', () {
    const entity = UserEntity.empty();

    expect(entity.valueOrNull, isNull);
    expect(entity.spareTimeOrNull, isNull);
    expect(entity.scoreOrNull, isNull);
    expect(entity.nameOrNull, isNull);
    expect(entity.emailOrNull, isNull);
  });
}
