import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/input_models/preparation_name_input_model.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time/input_models/preparation_time_input_model.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/bloc/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_create_list.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/components/preparation_form_reorderable_list.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_spare_and_preparing_time/preparation_form/cubit/preparation_step_form_cubit.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/domain/entities/preparation_entity.dart';
import 'package:on_time_front/domain/entities/preparation_step_entity.dart';

class _TestBlocObserver extends BlocObserver {
  final List<Object?> events = [];

  @override
  void onEvent(Bloc bloc, Object? event) {
    events.add(event);
    super.onEvent(bloc, event);
  }
}

Widget _wrapWithMaterialApp({
  required PreparationFormBloc bloc,
  required Widget child,
}) {
  return MaterialApp(
    theme: themeData,
    home: Scaffold(
      body: BlocProvider<PreparationFormBloc>.value(
        value: bloc,
        child: child,
      ),
    ),
  );
}

PreparationStepFormState _step({
  required String id,
  required String name,
  required Duration time,
}) {
  return PreparationStepFormState(
    id: id,
    preparationName: PreparationNameInputModel.pure(name),
    preparationTime: PreparationTimeInputModel.pure(time),
  );
}

PreparationEntity _entityFromStepStates(List<PreparationStepFormState> steps) {
  final stepEntities = steps
      .mapIndexed(
        (index, step) => PreparationStepEntity(
          id: step.id,
          preparationName: step.preparationName.value,
          preparationTime: step.preparationTime.value,
          nextPreparationId:
              index < steps.length - 1 ? steps[index + 1].id : null,
        ),
      )
      .toList();
  return PreparationEntity(preparationStepList: stepEntities);
}

void main() {
  late PreparationFormBloc bloc;
  late _TestBlocObserver observer;
  late BlocObserver previousObserver;

  setUp(() {
    previousObserver = Bloc.observer;
    observer = _TestBlocObserver();
    Bloc.observer = observer;

    bloc = PreparationFormBloc();
  });

  tearDown(() async {
    await bloc.close();
    Bloc.observer = previousObserver;
  });

  group('PreparationFormCreateList', () {
    testWidgets(
        'renders list + create button; does not render extra add-field when not adding',
        (tester) async {
      final steps = [
        _step(id: 's1', name: 'A', time: const Duration(minutes: 1)),
        _step(id: 's2', name: 'B', time: const Duration(minutes: 2)),
      ];

      await tester.pumpWidget(
        _wrapWithMaterialApp(
          bloc: bloc,
          child: PreparationFormCreateList(
            preparationNameState: PreparationFormState(
              status: PreparationFormStatus.initial,
              preparationStepList: steps,
            ),
            onNameChanged: ({required index, required value}) {},
            onCreationRequested: () {},
          ),
        ),
      );

      expect(find.byType(PreparationFormReorderableList), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(steps.length));
    });

    testWidgets('renders an extra add-field when status == adding',
        (tester) async {
      final steps = [
        _step(id: 's1', name: 'A', time: const Duration(minutes: 1)),
      ];

      await tester.pumpWidget(
        _wrapWithMaterialApp(
          bloc: bloc,
          child: PreparationFormCreateList(
            preparationNameState: PreparationFormState(
              status: PreparationFormStatus.adding,
              preparationStepList: steps,
            ),
            onNameChanged: ({required index, required value}) {},
            onCreationRequested: () {},
          ),
        ),
      );

      expect(find.byType(PreparationFormReorderableList), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(steps.length + 1));
    });

    testWidgets('CreateIconButton triggers onCreationRequested',
        (tester) async {
      var didTap = false;

      await tester.pumpWidget(
        _wrapWithMaterialApp(
          bloc: bloc,
          child: PreparationFormCreateList(
            preparationNameState: const PreparationFormState(
              status: PreparationFormStatus.initial,
              preparationStepList: [],
            ),
            onNameChanged: ({required index, required value}) {},
            onCreationRequested: () => didTap = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(didTap, isTrue);
    });

    testWidgets(
        'wires reorder + time change to PreparationFormBloc events, and name change to callback',
        (tester) async {
      final steps = [
        _step(id: 's1', name: 'A', time: const Duration(minutes: 1)),
      ];

      int? nameChangedIndex;
      String? nameChangedValue;

      await tester.pumpWidget(
        _wrapWithMaterialApp(
          bloc: bloc,
          child: PreparationFormCreateList(
            preparationNameState: PreparationFormState(
              status: PreparationFormStatus.initial,
              preparationStepList: steps,
            ),
            onNameChanged: ({required index, required value}) {
              nameChangedIndex = index;
              nameChangedValue = value;
            },
            onCreationRequested: () {},
          ),
        ),
      );

      // Seed the bloc state so its real event handlers don't throw while processing.
      bloc.add(
        PreparationFormEditRequested(
          preparationEntity: _entityFromStepStates(steps),
        ),
      );
      await tester.pump();

      final listWidget = tester.widget<PreparationFormReorderableList>(
          find.byType(PreparationFormReorderableList));

      listWidget.onNameChanged(0, 'Changed');
      expect(nameChangedIndex, 0);
      expect(nameChangedValue, 'Changed');

      listWidget.onTimeChanged(0, const Duration(minutes: 7));
      expect(
        observer.events,
        contains(
          const PreparationFormPreparationStepTimeChanged(
            index: 0,
            preparationStepTime: Duration(minutes: 7),
          ),
        ),
      );

      listWidget.onReorder(0, 1);
      expect(
        observer.events,
        contains(
          const PreparationFormPreparationStepOrderChanged(
            oldIndex: 0,
            newIndex: 1,
          ),
        ),
      );
    });

    testWidgets('swipe-to-delete dispatches PreparationStepRemoved',
        (tester) async {
      final steps = [
        _step(id: 's1', name: 'A', time: const Duration(minutes: 1)),
        _step(id: 's2', name: 'B', time: const Duration(minutes: 2)),
      ];

      await tester.pumpWidget(
        _wrapWithMaterialApp(
          bloc: bloc,
          child: PreparationFormCreateList(
            preparationNameState: PreparationFormState(
              status: PreparationFormStatus.initial,
              preparationStepList: steps,
            ),
            onNameChanged: ({required index, required value}) {},
            onCreationRequested: () {},
          ),
        ),
      );

      // Programmatically invoke the trailing swipe action, instead of relying on
      // gesture/animation behavior from the 3rd-party swipe widget.
      final swipeCellFinder = find.byWidgetPredicate(
          (w) => w is SwipeActionCell && w.key == const ValueKey<String>('s1'));
      expect(swipeCellFinder, findsOneWidget);

      final swipeCell = tester.widget<SwipeActionCell>(swipeCellFinder);
      final trailingActions = swipeCell.trailingActions;
      expect(trailingActions, isNotNull);
      expect(trailingActions!, isNotEmpty);

      trailingActions.first.onTap((_) async {});
      await tester.pump();

      expect(
        observer.events,
        contains(
          const PreparationFormPreparationStepRemoved(preparationStepId: 's1'),
        ),
      );
    });

    testWidgets(
        'in adding state, submitting the new field dispatches StepCreated',
        (tester) async {
      final steps = [
        _step(id: 's1', name: 'A', time: const Duration(minutes: 1)),
      ];

      await tester.pumpWidget(
        _wrapWithMaterialApp(
          bloc: bloc,
          child: PreparationFormCreateList(
            preparationNameState: PreparationFormState(
              status: PreparationFormStatus.adding,
              preparationStepList: steps,
            ),
            onNameChanged: ({required index, required value}) {},
            onCreationRequested: () {},
          ),
        ),
      );

      final newField = find.byType(TextFormField).last;
      await tester.enterText(newField, 'New step');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      final createdEvents = observer.events
          .whereType<PreparationFormPreparationStepCreated>()
          .toList();
      expect(createdEvents, isNotEmpty);
      final createdEvent = createdEvents.last;
      expect(createdEvent.preparationStep.preparationName.value, 'New step');
    });
  });
}
