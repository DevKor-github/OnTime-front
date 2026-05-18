import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/database.dart';
import 'package:on_time_front/domain/entities/user_entity.dart';

void main() {
  test('fromModel and toModel preserve user profile values', () {
    const model = User(
      id: 'user-1',
      email: 'user@example.com',
      name: 'User',
      spareTime: 12,
      note: 'note',
      score: 4.5,
    );

    final entity = UserEntity.fromModel(model);
    final roundTrip = entity.toModel();

    expect(entity.valueOrNull, entity);
    expect(entity.spareTimeOrNull, const Duration(minutes: 12));
    expect(entity.scoreOrNull, 4.5);
    expect(entity.nameOrNull, 'User');
    expect(entity.emailOrNull, 'user@example.com');
    expect(roundTrip.id, model.id);
    expect(roundTrip.email, model.email);
    expect(roundTrip.name, model.name);
    expect(roundTrip.spareTime, model.spareTime);
    expect(roundTrip.note, model.note);
    expect(roundTrip.score, model.score);
  });

  test(
    'empty user exposes null convenience values and cannot become a model',
    () {
      const entity = UserEntity.empty();

      expect(entity.valueOrNull, isNull);
      expect(entity.spareTimeOrNull, isNull);
      expect(entity.scoreOrNull, isNull);
      expect(entity.nameOrNull, isNull);
      expect(entity.emailOrNull, isNull);
      expect(entity.toModel, throwsException);
    },
  );
}
