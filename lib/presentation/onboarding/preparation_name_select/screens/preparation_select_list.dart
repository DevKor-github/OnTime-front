import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

typedef OnSelectedStepChangedCallBackFunction<T> = void Function(List<T>);

class PreparationSelectList extends StatelessWidget {
  const PreparationSelectList({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<PreparationNameCubit, PreparationNameState>(
        builder: (context, state) {
      return SingleChildScrollView(
        child: Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: state.preparationStepList.length,
              itemBuilder: (context, index) {
                return PreparationNameSelectField(
                  preparationStep: state.preparationStepList[index],
                  onNameChanged: (value) {
                    context
                        .read<PreparationNameCubit>()
                        .preparationStepNameChanged(index: index, value: value);
                  },
                  onSelectionChanged: () {
                    context
                        .read<PreparationNameCubit>()
                        .preparationStepSelectionChanged(index: index);
                  },
                );
              },
            ),
            state.status == PreparationNameStatus.adding
                ? BlocProvider<PreparationStepNameCubit>(
                    create: (context) => PreparationStepNameCubit(
                        PreparationStepNameState(),
                        preparationNameCubit:
                            context.read<PreparationNameCubit>()),
                    child: BlocBuilder<PreparationStepNameCubit,
                        PreparationStepNameState>(builder: (context, state) {
                      return PreparationNameSelectField(
                        isAdding: true,
                        preparationStep: state,
                        onNameChanged: (value) {
                          context
                              .read<PreparationStepNameCubit>()
                              .nameChanged(value);
                        },
                        onSelectionChanged: () {
                          context
                              .read<PreparationStepNameCubit>()
                              .selectionToggled();
                        },
                        onNameSaved: () {
                          context
                              .read<PreparationStepNameCubit>()
                              .preparationStepSaved();
                        },
                      );
                    }),
                  )
                : SizedBox.shrink(),
            SizedBox(
              height: 28.0,
            ),
            Center(
              child: SizedBox(
                height: 30,
                width: 30,
                child: IconButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                        colorScheme.primaryContainer),
                  ),
                  onPressed: () {
                    context
                        .read<PreparationNameCubit>()
                        .preparationStepCreateRequested();
                  },
                  color: colorScheme.onPrimary,
                  icon: Icon(Icons.add),
                  padding: EdgeInsets.zero,
                  iconSize: 30.0,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class PreparationNameSelectField extends StatefulWidget {
  const PreparationNameSelectField({
    super.key,
    required this.preparationStep,
    this.onNameChanged,
    this.onNameSaved,
    required this.onSelectionChanged,
    this.isAdding = false,
  });

  final PreparationStepNameState preparationStep;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback? onNameSaved;
  final VoidCallback onSelectionChanged;
  final bool isAdding;

  @override
  State<PreparationNameSelectField> createState() =>
      _PreparationNameSelectFieldState();
}

class _PreparationNameSelectFieldState
    extends State<PreparationNameSelectField> {
  final FocusNode focusNode = FocusNode();

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        widget.onNameSaved?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAdding) {
      focusNode.requestFocus();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Tile(
        key: ValueKey<String>(widget.preparationStep.preparationId),
        style: TileStyle(padding: EdgeInsets.all(16.0)),
        leading: SizedBox(
            width: 30,
            height: 30,
            child: CheckButton(
              isChecked: widget.preparationStep.isSelected,
              onPressed: widget.onSelectionChanged,
            )),
        child: Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 19.0),
            child: Container(
              constraints: BoxConstraints(minHeight: 30),
              child: TextFormField(
                initialValue: widget.preparationStep.preparationName.value,
                onChanged: widget.onNameChanged,
                onFieldSubmitted: (value) => widget.onNameSaved?.call(),
                onTapOutside: (event) {
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(3.0),
                ),
                focusNode: focusNode,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PreparationSelectField extends StatefulWidget {
  const PreparationSelectField({
    super.key,
    required this.formKey,
  });

  final GlobalKey<FormState> formKey;

  @override
  State<PreparationSelectField> createState() => _PreparationSelectFieldState();
}

class _PreparationSelectFieldState extends State<PreparationSelectField> {
  @override
  void initState() {
    super.initState();
    context.read<PreparationNameCubit>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: Text(
        '주로 하는 준비 과정을\n선택해주세요',
        style: textTheme.titleLarge,
      ),
      form: Form(
        key: widget.formKey,
        child: PreparationSelectList(),
      ),
    );
  }
}
