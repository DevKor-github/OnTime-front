import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/onboarding_screen.dart';
import 'package:on_time_front/shared/components/check_button.dart';
import 'package:on_time_front/shared/components/tile.dart';
import 'package:on_time_front/shared/theme/tile_style.dart';
import 'package:uuid/uuid.dart';

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
  final List<FocusNode> focusNodes = [];
  final FocusNode tmpAddFocusNode = FocusNode();
  bool isAdding = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.preparationList.length; i++) {
      focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (var i = 0; i < widget.preparationList.length; i++) {
      focusNodes[i].dispose();
    }
    super.dispose();
  }

  void onStepSelected(int index) {
    widget.preparationList[index].isSelected =
        !widget.preparationList[index].isSelected;
    widget.onSelectedStepChanged(widget.preparationList);
  }

  List<Widget> _listViewChildren(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    List<Widget> children = [];
    for (var i = 0; i < widget.preparationList.length; i++) {
      PreparationStepWithSelection step = widget.preparationList[i];
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).requestFocus(focusNodes[i]),
            child: Tile(
                style: TileStyle(
                  padding: EdgeInsets.all(16.0),
                ),
                key: ValueKey<String>(step.id),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CheckButton(
                        isChecked: step.isSelected,
                        onPressed: () => onStepSelected(i),
                      )),
                ),
                child: Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 19.0),
                    child: PreparationNameTextField(
                      preparationName: step.preparationName,
                      focusNode: focusNodes[i],
                      onChanged: (value) {},
                      onsubmitted: (value) {
                        widget.preparationList[i].preparationName = value;
                        widget.onSelectedStepChanged(widget.preparationList);
                      },
                    ),
                  ),
                )),
          ),
        ),
      );
    }
    children.addAll([
      isAdding
          ? Tile(
              key: ValueKey<String>('adding'),
              style: TileStyle(padding: EdgeInsets.all(16.0)),
              leading: SizedBox(
                  width: 30,
                  height: 30,
                  child: CheckButton(
                    isChecked: false,
                    onPressed: () {},
                  )),
              child: Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19.0),
                  child: PreparationNameTextField(
                    preparationName: '',
                    focusNode: tmpAddFocusNode,
                    onChanged: (value) {},
                    onsubmitted: (value) {
                      setState(() {
                        isAdding = false;
                      });
                      widget.preparationList.add(PreparationStepWithSelection(
                          id: Uuid().v4(),
                          preparationName: value,
                          isSelected: true));
                      focusNodes.add(FocusNode());
                      widget.onSelectedStepChanged(widget.preparationList);
                    },
                    onFocusChange: (value) {
                      if (!value) {
                        setState(() {
                          isAdding = false;
                        });
                      }
                    },
                  ),
                ),
              ))
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
              tmpAddFocusNode.requestFocus();
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
    return ListView(
      children: _listViewChildren(context),
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
      preparationStepSelectingList = [
        PreparationStepWithSelection(
          id: Uuid().v7(),
          preparationName: '1',
          isSelected: false,
        ),
        PreparationStepWithSelection(
          id: Uuid().v7(),
          preparationName: '2',
          isSelected: false,
        ),
        PreparationStepWithSelection(
          id: Uuid().v7(),
          preparationName: '3',
          isSelected: false,
        ),
        PreparationStepWithSelection(
          id: Uuid().v7(),
          preparationName: '4',
          isSelected: false,
        ),
      ];
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
    return OnboardingPageViewLayout(
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
    );
  }
}
