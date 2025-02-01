import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_swipe_action_cell/core/cell.dart';
import 'package:on_time_front/presentation/onboarding/mutly_page_form.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/preparation_form/preparation_form_bloc.dart';
import 'package:on_time_front/presentation/schedule_create/compoenent/preparation_reorderable_list_form_field.dart';
import 'package:on_time_front/presentation/shared/components/cupertino_picker_modal.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';
import 'package:uuid/uuid.dart';

typedef OnPreparationListChangedCallBackFunction<T> = void Function(List<T>);

class PreparationEditList extends StatefulWidget {
  final PreparationFormState preparationFormState;
  final GlobalKey<FormState> formKey;
  final Function(PreparationFormData) onSaved;

  const PreparationEditList({
    super.key,
    required this.formKey,
    required this.onSaved,
    required this.preparationFormState,
  });

  @override
  State<PreparationEditList> createState() => _PreparationEditListState();
}

class _PreparationEditListState extends State<PreparationEditList> {
  final FocusScopeNode newFocusNode = FocusScopeNode();
  final FocusNode newPreparationStepNameTextFieldFocusNode = FocusNode();
  final FocusNode newPreparationStepTimeFocusNode = FocusNode();
  final reorderableListKey =
      GlobalKey<PreparationReorderableListFormFieldState>();

  bool isModalUp = false;
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    newFocusNode.dispose();
    newPreparationStepNameTextFieldFocusNode.dispose();
    newPreparationStepTimeFocusNode.dispose();
    super.dispose();
  }

  List<Widget> _listViewChildren(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final preparationList = widget.preparationFormState.preparationStepList;
    List<Widget> children = [];
    final Widget dragIndicatorSvg = SvgPicture.asset(
      'assets/drag_indicator.svg',
      semanticsLabel: 'drag indicator',
      height: 14,
      width: 14,
      fit: BoxFit.contain,
    );

    children.add(
      PreparationReorderableListFormField(
        key: reorderableListKey,
        initialValue: preparationList.map((e) => e.order).toList(),
        onSaved: (newValue) {
          context.read<PreparationFormBloc>().add(
                PreparationFormPreparationStepOrderChanged(
                    preparationStepOrder: newValue!),
              );
        },
        itemCount: preparationList.length,
        itemBuilder: (context, index) {
          final preparationStep = preparationList[index];
          return SwipeActionCell(
            key: ObjectKey(preparationStep),
            trailingActions: <SwipeAction>[
              SwipeAction(
                content: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: colorScheme.surfaceContainerLow,
                  ),
                  width: 130,
                  height: 60,
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('삭제',
                            style: TextStyle(
                                color: colorScheme.onSurface, fontSize: 20)),
                      ],
                    ),
                  ),
                ),
                onTap: (CompletionHandler handler) {
                  context.read<PreparationFormBloc>().add(
                        PreparationFormPreparationStepRemoved(
                            preparationStepId: preparationStep.id),
                      );
                  reorderableListKey.currentState?.elementRemoved(index);
                },
                color: Colors.transparent,
              ),
            ],
            child: Tile(
              key: Key('$index'),
              leading: ReorderableDragStartListener(
                index: index,
                child: dragIndicatorSvg,
              ),
              style: TileStyle(padding: EdgeInsets.all(16.0)),
              trailing: FormField<Duration>(
                onSaved: (newValue) {
                  context.read<PreparationFormBloc>().add(
                        PreparationFormPreparationStepTimeChanged(
                            preparationStepId: preparationStep.id,
                            preparationStepTime: newValue!),
                      );
                },
                initialValue: preparationStep.preparationTime,
                builder: (field) => Row(
                  children: [
                    GestureDetector(
                      child: Text((field.value!.inMinutes < 10 ? '0' : '') +
                          field.value!.inMinutes.toString()),
                      onTap: () {
                        context.showCupertinoMinutePickerModal(
                          title: '시간을 선택해 주세요',
                          context: context,
                          initialValue: field.value!,
                          onSaved: field.didChange,
                        );
                      },
                    ),
                    SizedBox(width: 35),
                    Text('분'),
                  ],
                ),
              ),
              child: Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19.0),
                  child: PreparationNameTextField(
                    initialValue: preparationStep.preparationName,
                    focusNode: preparationList[index].focusNode,
                    onSaved: (newValue) {
                      context.read<PreparationFormBloc>().add(
                            PreparationFormPreparationStepNameChanged(
                                preparationStepId: preparationStep.id,
                                preparationStepName: newValue!),
                          );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final newPreparationStepFormKey = GlobalKey<FormState>();
    PreparationStepFormState newPreparationStep = PreparationStepFormState(
      id: Uuid().v7(),
      preparationName: '',
      focusNode: FocusNode(),
      order: preparationList.length,
    );
    children.addAll([
      isAdding
          ? Form(
              key: newPreparationStepFormKey,
              child: Focus(
                focusNode: newPreparationStep.focusNode,
                onFocusChange: (value) {
                  if (!value && isModalUp == false) {
                    newPreparationStepFormKey.currentState?.save();
                    if (newPreparationStep.preparationName == '') {
                      newPreparationStep = PreparationStepFormState(
                        id: Uuid().v7(),
                        preparationName: '',
                        focusNode: FocusNode(),
                        order: preparationList.length,
                      );
                    } else {
                      newPreparationStep = newPreparationStep.copyWith(
                        order: preparationList.length,
                      );
                      context.read<PreparationFormBloc>().add(
                            PreparationFormPreparationStepAdded(
                                preparationStep: newPreparationStep),
                          );
                      reorderableListKey.currentState?.elementAdded();
                    }
                    setState(() {
                      isAdding = false;
                    });
                  }
                },
                child: TapRegion(
                  onTapOutside: (event) => newFocusNode.unfocus(),
                  onTapInside: (event) => newFocusNode.requestFocus(),
                  child: Tile(
                    leading: dragIndicatorSvg,
                    key: ValueKey<String>('adding'),
                    style: TileStyle(padding: EdgeInsets.all(16.0)),
                    trailing: FormField<Duration>(
                      initialValue: Duration.zero,
                      onSaved: (newValue) => newPreparationStep =
                          newPreparationStep.copyWith(
                              preparationTime: newValue!),
                      builder: (field) => Focus(
                        focusNode: newPreparationStepTimeFocusNode,
                        onFocusChange: (focused) {
                          if (focused) {
                            isModalUp = true;

                            context.showCupertinoMinutePickerModal(
                              title: '시간을 선택해 주세요',
                              context: context,
                              initialValue: field.value!,
                              onSaved: (value) {
                                field.didChange(value);
                                newPreparationStepFormKey.currentState?.save();
                                // save new preparation step if name is not empty
                                if (newPreparationStep.preparationName != '') {
                                  newPreparationStep =
                                      newPreparationStep.copyWith(
                                    order: preparationList.length,
                                  );
                                  context.read<PreparationFormBloc>().add(
                                        PreparationFormPreparationStepAdded(
                                            preparationStep:
                                                newPreparationStep),
                                      );
                                  reorderableListKey.currentState
                                      ?.elementAdded();
                                  isAdding = false;
                                }
                              },
                              onDisposed: () {
                                isModalUp = false;
                                newPreparationStepTimeFocusNode.unfocus();
                              },
                            );
                          }
                        },
                        child: Row(
                          children: [
                            GestureDetector(
                              child: Text(
                                  (field.value!.inMinutes < 10 ? '0' : '') +
                                      field.value!.inMinutes.toString()),
                              onTap: () {
                                newPreparationStepTimeFocusNode.requestFocus();
                              },
                            ),
                            SizedBox(width: 35),
                            Text('분'),
                          ],
                        ),
                      ),
                    ),
                    child: Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 19.0),
                        child: PreparationNameTextField(
                          initialValue: '',
                          focusNode: newPreparationStepNameTextFieldFocusNode,
                          onChanged: (value) {},
                          onSaved: (newValue) {
                            newPreparationStep = newPreparationStep.copyWith(
                                preparationName: newValue);
                          },
                          onSubmitted: (value) {
                            newPreparationStepTimeFocusNode.requestFocus();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : SizedBox.shrink(),
      SizedBox(
        height: 32.0,
      ),
      Center(
        child: SizedBox(
          height: 30,
          width: 30,
          child: IconButton(
            style: ButtonStyle(
              backgroundColor:
                  WidgetStateProperty.all<Color>(colorScheme.primaryContainer),
            ),
            onPressed: () {
              newFocusNode.requestFocus();
              newPreparationStepNameTextFieldFocusNode.requestFocus();
              setState(() {
                isAdding = true;
              });
            },
            color: colorScheme.onPrimary,
            icon: Icon(Icons.add),
            padding: EdgeInsets.zero,
            iconSize: 30.0,
          ),
        ),
      ),
    ]);
    return children;
  }

  @override
  Widget build(BuildContext context) {
    return MultiPageFormField(
      key: widget.formKey,
      onSaved: () {},
      child: ListView(
        children: _listViewChildren(context),
      ),
    );
  }
}

class PreparationNameTextField extends StatefulWidget {
  const PreparationNameTextField(
      {super.key,
      required this.initialValue,
      required this.focusNode,
      this.onChanged,
      this.onFocusChange,
      this.onSubmitted,
      this.onSaved});

  final String initialValue;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onFocusChange;
  final FormFieldSetter<String>? onSaved;
  final FormFieldSetter<String>? onSubmitted;

  @override
  State<PreparationNameTextField> createState() =>
      _PreparationNameTextFieldState();
}

class _PreparationNameTextFieldState extends State<PreparationNameTextField> {
  void onFocusChange() {
    widget.onFocusChange?.call(widget.focusNode.hasFocus);
    debugPrint('Focus changed');
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 30),
      child: TextFormField(
        initialValue: widget.initialValue,
        onChanged: widget.onChanged,
        onSaved: widget.onSaved,
        onFieldSubmitted: widget.onSubmitted,
        focusNode: widget.focusNode,
        onTapOutside: (event) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(3.0),
        ),
      ),
    );
  }
}
