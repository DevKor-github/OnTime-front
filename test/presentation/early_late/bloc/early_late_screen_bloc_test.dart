import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/early_late/bloc/early_late_screen_bloc.dart';

void main() {
  group('EarlyLateScreenBloc', () {
    test('loads success state for early completion values', () async {
      final bloc = EarlyLateScreenBloc();
      addTearDown(bloc.close);

      bloc.add(const LoadEarlyLateInfo(earlyLateTime: 45 * 60));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<EarlyLateScreenLoadSuccess>());
      final state = bloc.state as EarlyLateScreenLoadSuccess;
      expect(state.isLate, isFalse);
      expect(state.earlylateMessage, isNotEmpty);
      expect(state.earlylateImage, isNotEmpty);
    });

    test('loads success state for late completion values', () async {
      final bloc = EarlyLateScreenBloc();
      addTearDown(bloc.close);

      bloc.add(const LoadEarlyLateInfo(earlyLateTime: -60));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state, isA<EarlyLateScreenLoadSuccess>());
      final state = bloc.state as EarlyLateScreenLoadSuccess;
      expect(state.isLate, isTrue);
      expect(state.earlylateMessage, isNotEmpty);
      expect(state.earlylateImage, isNotEmpty);
    });
  });
}
