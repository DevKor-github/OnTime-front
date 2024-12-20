import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/presentation/onboarding/mutly_page_form.dart';
import 'package:on_time_front/presentation/onboarding/preparation_select_list.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageViewController;
  late TabController _tabController;
  late List<GlobalKey<FormState>> formKeys;
  PreparationFormData preparationFormData = PreparationFormData();
  int _currentPageIndex = 0;
  final int _numberOfPages = 3;

  List<PreparationStepWithSelection> preparationStepList = [
    PreparationStepWithSelection(
      id: '1',
      preparationName: 'Preparation 1',
      isSelected: false,
    ),
    PreparationStepWithSelection(
      id: '2',
      preparationName: 'Preparation 2',
      isSelected: false,
    ),
    PreparationStepWithSelection(
      id: '3',
      preparationName: 'Preparation 3',
      isSelected: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    formKeys = List.generate(_numberOfPages, (index) => GlobalKey<FormState>());
    _pageViewController = PageController();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            PageIndicator(
              tabController: _tabController,
              currentPageIndex: _currentPageIndex,
              onUpdateCurrentPageIndex: _updateCurrentPageIndex,
            ),
            Expanded(
              child: PageView(
                /// [PageView.scrollDirection] defaults to [Axis.horizontal].
                /// Use [Axis.vertical] to scroll vertically.
                controller: _pageViewController,
                onPageChanged: _handlePageViewChanged,
                children: <Widget>[
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 27.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              '주로 하는 준비 과정을\n선택해주세요',
                              style: textTheme.titleLarge,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Form(
                          key: formKeys[0],
                          child: FormField<List<PreparationStepWithNameAndId>>(
                            key: const Key('field'),
                            initialValue:
                                preparationFormData.preparationStepList
                                    .map((e) => PreparationStepWithNameAndId(
                                          id: e.id,
                                          preparationName: e.preparationName,
                                        ))
                                    .toList(),
                            onSaved: (newValue) {
                              setState(() {
                                preparationFormData =
                                    preparationFormData.copyWith(
                                        preparationStepList: newValue!
                                            .map((e) => PreparationStepFormData(
                                                  id: e.id,
                                                  preparationName:
                                                      e.preparationName,
                                                ))
                                            .toList());
                              });
                            },
                            builder: (field) => PreparationSelectList(
                              preparationList: preparationStepList,
                              onSelectedStepChanged:
                                  (preparationStepWithSelection) {
                                field.didChange(preparationStepWithSelection
                                    .where((element) => element.isSelected)
                                    .map((e) {
                                  return PreparationStepWithNameAndId(
                                    id: e.id,
                                    preparationName: e.preparationName,
                                  );
                                }).toList());
                                setState(() {
                                  preparationStepList =
                                      preparationStepWithSelection;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Center(
                    child: ListView.builder(
                        itemCount:
                            preparationFormData.preparationStepList.length,
                        itemBuilder: (context, index) {
                          return Text(
                              '${preparationFormData.preparationStepList[index].preparationName}');
                        }),
                  ),
                  Center(
                    child: TextFormField(
                      onChanged: (value) {
                        debugPrint('Form changed');
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
                height: 58,
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _onNextPageButtonClicked,
                    child: const Text('다음'))),
          ],
        ),
      ),
    );
  }

  void _onNextPageButtonClicked() {
    formKeys[_currentPageIndex].currentState!.save();
    if (_currentPageIndex < _numberOfPages - 1) {
      _updateCurrentPageIndex(_currentPageIndex + 1);
    }
  }

  void _handlePageViewChanged(int currentPageIndex) {
    _tabController.index = currentPageIndex;
    setState(() {
      _currentPageIndex = currentPageIndex;
    });
  }

  void _updateCurrentPageIndex(int index) {
    _tabController.index = index;
    _pageViewController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }
}

class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.tabController,
    required this.currentPageIndex,
    required this.onUpdateCurrentPageIndex,
  });

  final int currentPageIndex;
  final TabController tabController;
  final void Function(int) onUpdateCurrentPageIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    const double iconButtonSize = 32.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        SizedBox(
          width: iconButtonSize,
          height: iconButtonSize,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              if (currentPageIndex == 0) {
                return;
              }
              onUpdateCurrentPageIndex(currentPageIndex - 1);
            },
            icon: const Icon(
              Icons.arrow_left_rounded,
              size: 24.0,
            ),
          ),
        ),
        TabPageSelector(
          controller: tabController,
          color: colorScheme.surface,
          selectedColor: colorScheme.primary,
        ),
        SizedBox(
          width: iconButtonSize,
        )
      ],
    );
  }
}

class Test {
  Test({this.a, this.b});
  final String? a;
  final String? b;

  Test copyWith({String? a, String? b}) {
    return Test(a: a ?? this.a, b: b ?? this.b);
  }
}

class PreparationFormData {
  PreparationFormData({this.preparationStepList = const []});
  final List<PreparationStepFormData> preparationStepList;

  PreparationFormData copyWith(
      {List<PreparationStepFormData>? preparationStepList}) {
    return PreparationFormData(
      preparationStepList: preparationStepList ?? this.preparationStepList,
    );
  }
}

class PreparationStepFormData {
  PreparationStepFormData(
      {required this.id,
      required this.preparationName,
      this.preparationTime,
      this.nextPreparationId});
  final String id;
  final String preparationName;
  final int? preparationTime;
  final String? nextPreparationId;
}

class CustomFormField<T> extends FormField<T> {
  CustomFormField({super.key, required})
      : super(
          builder: (FormFieldState<T> field) {
            return Column(
              children: [
                TextField(
                  onChanged: (value) {
                    field.didChange(value as T);
                  },
                ),
              ],
            );
          },
        );
}
