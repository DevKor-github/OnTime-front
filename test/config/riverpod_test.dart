import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/config/database.dart';
import 'package:on_time_front/config/riverpod.dart';

void main() {
  test('[appDatabaseProvider] should provide AppDatabase', () {
    final container = ProviderContainer();
    final appDatabase = container.read(appDatabseProvider);
    expect(appDatabase, isA<AppDatabase>());
  });
}
