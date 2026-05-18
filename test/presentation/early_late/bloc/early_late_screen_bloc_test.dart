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

    test(
      'loaded checklist replaces only checklist while preserving message',
      () async {
        final bloc = EarlyLateScreenBloc();
        addTearDown(bloc.close);

        bloc.add(const LoadEarlyLateInfo(earlyLateTime: 5 * 60));
        await Future<void>.delayed(Duration.zero);
        final loaded = bloc.state as EarlyLateScreenLoadSuccess;

        bloc.add(const ChecklistLoaded(checklist: [true, false, true]));
        await Future<void>.delayed(Duration.zero);

        final state = bloc.state as EarlyLateScreenLoadSuccess;
        expect(state.checklist, [true, false, true]);
        expect(state.isLate, loaded.isLate);
        expect(state.earlylateMessage, loaded.earlylateMessage);
        expect(state.earlylateImage, loaded.earlylateImage);
      },
    );

    test('toggle checklist item flips one item and keeps the others', () async {
      final bloc = EarlyLateScreenBloc();
      addTearDown(bloc.close);

      bloc.add(const LoadEarlyLateInfo(earlyLateTime: 5 * 60));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ChecklistLoaded(checklist: [false, false, true]));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ChecklistItemToggled(1));
      await Future<void>.delayed(Duration.zero);

      final state = bloc.state as EarlyLateScreenLoadSuccess;
      expect(state.checklist, [false, true, true]);
    });

    test(
      'checklist events are ignored until early-late info is loaded',
      () async {
        final bloc = EarlyLateScreenBloc();
        addTearDown(bloc.close);

        bloc.add(const ChecklistLoaded(checklist: [true, true, true]));
        bloc.add(const ChecklistItemToggled(0));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state, isA<EarlyLateScreenInitial>());
      },
    );

    test('events and states compare by their public fields', () {
      expect(
        const LoadEarlyLateInfo(earlyLateTime: 60),
        const LoadEarlyLateInfo(earlyLateTime: 60),
      );
      expect(const ChecklistLoaded(checklist: [true, false]).props, [
        [true, false],
      ]);
      expect(const ChecklistItemToggled(2).props, [2]);
      expect(
        const EarlyLateScreenLoadSuccess(
          checklist: [false, true],
          isLate: false,
          earlylateMessage: 'Ready',
          earlylateImage: 'character.svg',
        ).props,
        [
          [false, true],
          false,
          'Ready',
          'character.svg',
        ],
      );
    });
  });
}
