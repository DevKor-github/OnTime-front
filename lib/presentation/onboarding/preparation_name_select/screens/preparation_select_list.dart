import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_name/preparation_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/preparation_name_select/cubit/preparation_step_name/preparation_step_name_cubit.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_screen.dart';
import 'package:on_time_front/presentation/shared/components/check_button.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

typedef OnSelectedStepChangedCallBackFunction<T> = void Function(List<T>);

class PreparationSelectList extends StatefulWidget {
  final List<PreparationStepWithSelection> preparationList;
  final OnSelectedStepChangedCallBackFunction<PreparationStepWithSelection>
      onSelectedStepChanged;

  const PreparationSelectList(
      {super.key,
      required this.preparationList,
      required this.onSelectedStepChanged});

  @override
  State<PreparationSelectList> createState() => _PreparationSelectListState();
}

class _PreparationSelectListState extends State<PreparationSelectList> {
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onStepSelected(int index) {
    widget.preparationList[index].isSelected =
        !widget.preparationList[index].isSelected;
    widget.onSelectedStepChanged(widget.preparationList);
  }

  // List<Widget> _listViewChildren(BuildContext context) {
  //   List<Widget> children = [];
  //   for (var i = 0; i < widget.preparationList.length; i++) {
  //     PreparationStepWithSelection step = widget.preparationList[i];
  //     children.add(
  //       Padding(
  //         padding: const EdgeInsets.only(bottom: 8.0),
  //         child: GestureDetector(
  //           onTap: () => FocusScope.of(context).requestFocus(focusNodes[i]),
  //           child: Tile(
  //               style: TileStyle(
  //                 padding: EdgeInsets.all(16.0),
  //               ),
  //               key: ValueKey<String>(step.id),
  //               leading: Padding(
  //                 padding: const EdgeInsets.symmetric(vertical: 0.0),
  //                 child: SizedBox(
  //                     width: 30,
  //                     height: 30,
  //                     child: CheckButton(
  //                       isChecked: step.isSelected,
  //                       onPressed: () => onStepSelected(i),
  //                     )),
  //               ),
  //               child: Expanded(
  //                 child: Padding(
  //                   padding: const EdgeInsets.symmetric(horizontal: 19.0),
  //                   child: PreparationNameTextField(
  //                     preparationName: step.preparationName,
  //                     focusNode: focusNodes[i],
  //                     onChanged: (value) {},
  //                     onsubmitted: (value) {
  //                       widget.preparationList[i].preparationName = value;
  //                       widget.onSelectedStepChanged(widget.preparationList);
  //                     },
  //                   ),
  //                 ),
  //               )),
  //         ),
  //       ),
  //     );
  //   }
  //   return children;
  // }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocBuilder<PreparationNameCubit, PreparationNameState>(
        builder: (context, state) {
      return ListView(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: state.preparationStepList.length,
            itemBuilder: (context, index) {
              return BlocProvider<PreparationStepNameCubit>(
                create: (context) => PreparationStepNameCubit(
                  state.preparationStepList[index],
                  preparationNameCubit: context.read<PreparationNameCubit>(),
                ),
                child: PreparationNameSelectField(),
              );
            },
          ),
          isAdding
              ? BlocProvider<PreparationStepNameCubit>(
                  create: (context) => PreparationStepNameCubit(
                      PreparationStepNameState(),
                      preparationNameCubit:
                          context.read<PreparationNameCubit>()),
                  child: PreparationNameSelectField(),
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
                  backgroundColor: WidgetStateProperty.all<Color>(
                      colorScheme.primaryContainer),
                ),
                onPressed: () {
                  //tmpAddFocusNode.requestFocus();
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
        ],
      );
    });
  }
}

class PreparationNameSelectField extends StatelessWidget {
  const PreparationNameSelectField({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PreparationStepNameCubit, PreparationStepNameState>(
      builder: (context, state) {
        return Tile(
          key: ValueKey<String>(state.preparationId),
          style: TileStyle(padding: EdgeInsets.all(16.0)),
          leading: SizedBox(
              width: 30,
              height: 30,
              child: CheckButton(
                isChecked: state.isSelected,
                onPressed: () {
                  context.read<PreparationStepNameCubit>().selectionToggled();
                },
              )),
          child: Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 19.0),
              child: Container(
                constraints: BoxConstraints(minHeight: 30),
                child: TextFormField(
                  initialValue: state.preparationName.value,
                  onChanged:
                      context.read<PreparationStepNameCubit>().nameChanged,
                  onFieldSubmitted: (value) => context
                      .read<PreparationStepNameCubit>()
                      .preparationStepSaved(),
                  onTapOutside: (event) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(3.0),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class PreparationNameTextField extends StatefulWidget {
  const PreparationNameTextField(
      {super.key,
      required this.preparationName,
      required this.focusNode,
      required this.onChanged,
      this.onFocusChange,
      this.onsubmitted});

  final String preparationName;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool>? onFocusChange;
  final ValueChanged<String>? onsubmitted;

  @override
  State<PreparationNameTextField> createState() =>
      _PreparationNameTextFieldState();
}

class _PreparationNameTextFieldState extends State<PreparationNameTextField> {
  bool isEditing = false;

  void onFocusChange() {
    widget.onFocusChange?.call(widget.focusNode.hasFocus);
    setState(() {
      isEditing = widget.focusNode.hasFocus;
    });
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
      child: TextField(
        controller: TextEditingController(text: widget.preparationName),
        onChanged: widget.onChanged,
        focusNode: widget.focusNode,
        onSubmitted: widget.onsubmitted,
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

class PreparationStepWithSelection {
  PreparationStepWithSelection({
    required this.id,
    required this.preparationName,
    required this.isSelected,
  });

  final String id;
  String preparationName;
  bool isSelected;
}

class PreparationSelectField extends StatefulWidget {
  const PreparationSelectField(
      {super.key,
      required this.formKey,
      required this.initailValue,
      this.onSaved});

  final GlobalKey<FormState> formKey;

  final List<PreparationStepWithNameAndId> initailValue;

  final Function(List<PreparationStepWithNameAndId>)? onSaved;

  @override
  State<PreparationSelectField> createState() => _PreparationSelectFieldState();
}

class _PreparationSelectFieldState extends State<PreparationSelectField> {
  List<PreparationStepWithSelection> preparationStepSelectingList = [];

  @override
  void initState() {
    super.initState();
    if (widget.initailValue.isEmpty) {
      preparationStepSelectingList = [];
    } else {
      preparationStepSelectingList.addAll(
        widget.initailValue.map((e) {
          return PreparationStepWithSelection(
            id: e.id,
            preparationName: e.preparationName,
            isSelected: true,
          );
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return BlocProvider<PreparationNameCubit>(
      create: (context) => PreparationNameCubit(),
      child: OnboardingPageViewLayout(
        title: Text(
          '주로 하는 준비 과정을\n선택해주세요',
          style: textTheme.titleLarge,
        ),
        form: Form(
          key: widget.formKey,
          child: FormField<List<PreparationStepWithSelection>>(
            initialValue: preparationStepSelectingList,
            onSaved: (value) {
              widget.onSaved
                  ?.call(value!.where((element) => element.isSelected).map((e) {
                return PreparationStepWithNameAndId(
                  id: e.id,
                  preparationName: e.preparationName,
                );
              }).toList());
            },
            builder: (field) => PreparationSelectList(
              preparationList: preparationStepSelectingList,
              onSelectedStepChanged: (value) {
                field.didChange(value);
                setState(() {
                  preparationStepSelectingList = value;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
