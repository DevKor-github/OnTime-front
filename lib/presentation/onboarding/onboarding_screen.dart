import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/presentation/onboarding/preparation_reordarable_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_select_list.dart';
import 'package:on_time_front/presentation/onboarding/preparation_time_input_list.dart';
import 'package:on_time_front/presentation/onboarding/schedule_spare_time_input.dart';

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
  Duration spareTime = const Duration(minutes: 0);
  int _currentPageIndex = 0;
  final int _numberOfPages = 4;

  @override
  void initState() {
    super.initState();
    formKeys = List.generate(_numberOfPages, (index) => GlobalKey<FormState>());
    _pageViewController = PageController();
    _tabController = TabController(length: _numberOfPages, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
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
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _pageViewController,
                  onPageChanged: _handlePageViewChanged,
                  children: <Widget>[
                    PreparationSelectField(
                      formKey: formKeys[0],
                      initailValue: preparationFormData
                          .toPreparationStepWithNameAndIdList(),
                      onSaved: (value) {
                        final PreparationFormData tmp =
                            PreparationFormData(preparationStepList: []);
                        int j = 0;
                        for (int i = 0; i < value.length; i++) {
                          while (j <
                                  preparationFormData
                                      .preparationStepList.length &&
                              preparationFormData.preparationStepList[j].id !=
                                  value[i].id) {
                            j++;
                          }
                          if (j ==
                              preparationFormData.preparationStepList.length) {
                            tmp.preparationStepList.add(PreparationStepFormData(
                                id: value[i].id,
                                preparationName: value[i].preparationName));
                            continue;
                          }
                          tmp.preparationStepList.add(preparationFormData
                              .preparationStepList[j]
                              .copyWith(
                                  preparationName: value[i].preparationName));
                        }
                        setState(() {
                          preparationFormData = tmp;
                        });
                      },
                    ),
                    PreparationReorderField(
                      formKey: formKeys[1],
                      initalValue: preparationFormData
                          .toPreparationStepWithOriginalIndexList(),
                      onSaved: (value) {
                        setState(
                          () {
                            for (int i = 0; i < value.length; i++) {
                              preparationFormData.preparationStepList[
                                  value[i]
                                      .originalIndex] = preparationFormData
                                  .preparationStepList[value[i].originalIndex]
                                  .copyWith(order: i);
                            }
                          },
                        );
                      },
                    ),
                    PreparationTimeInputFieldList(
                      formKey: formKeys[2],
                      initalValue: preparationFormData.sortByOrder(),
                      onSaved: (value) {
                        setState(
                          () {
                            preparationFormData = PreparationFormData(
                                preparationStepList: preparationFormData
                                    .preparationStepList
                                    .mapWithIndex((e, index) => e.copyWith(
                                        preparationTime: value[index]))
                                    .toList());
                          },
                        );
                      },
                    ),
                    ScheduleSpareTimeField(
                      formKey: formKeys[3],
                      initialValue: spareTime,
                      onSaved: (value) {
                        setState(
                          () {
                            spareTime = value;
                          },
                        );
                      },
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
      ),
    );
  }

  void _onNextPageButtonClicked() {
    formKeys[_currentPageIndex].currentState!.save();
    if (_currentPageIndex < _numberOfPages - 1) {
      _updateCurrentPageIndex(_currentPageIndex + 1);
    } else {
      context.go('/home');
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

  PreparationFormData sortByOrder() {
    final List<PreparationStepFormData> sortedList =
        List.from(preparationStepList)
          ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));
    return copyWith(preparationStepList: sortedList);
  }

  List<PreparationStepWithNameAndId> toPreparationStepWithNameAndIdList() {
    return preparationStepList
        .map((e) => e.toPreparationStepWithNameAndId())
        .toList();
  }

  List<PreparationStepWithOriginalIndex>
      toPreparationStepWithOriginalIndexList() {
    List<_PreparationStepWithOriginalIndexAndOrder> tmp = preparationStepList
        .mapWithIndex((e, index) => _PreparationStepWithOriginalIndexAndOrder(
              preparationStep: PreparationStepWithOriginalIndex(
                  preparationStep: e.toPreparationStepWithNameAndId(),
                  originalIndex: index),
              order: e.order ?? index,
            ));
    tmp.sort((a, b) => (a.order).compareTo(b.order));
    return tmp.map((e) => e.preparationStep).toList();
  }
}

class _PreparationStepWithOriginalIndexAndOrder {
  const _PreparationStepWithOriginalIndexAndOrder({
    required this.preparationStep,
    required this.order,
  });

  final PreparationStepWithOriginalIndex preparationStep;
  final int order;
}

class PreparationStepFormData {
  PreparationStepFormData({
    required this.id,
    required this.preparationName,
    this.preparationTime = const Duration(minutes: 0),
    this.order,
  });

  final String id;
  final String preparationName;
  final Duration preparationTime;
  final int? order;

  PreparationStepWithNameAndId toPreparationStepWithNameAndId() {
    return PreparationStepWithNameAndId(
      id: id,
      preparationName: preparationName,
    );
  }

  PreparationStepFormData copyWith(
      {String? id,
      String? preparationName,
      Duration? preparationTime,
      int? order}) {
    return PreparationStepFormData(
      id: id ?? this.id,
      preparationName: preparationName ?? this.preparationName,
      preparationTime: preparationTime ?? this.preparationTime,
      order: order ?? this.order,
    );
  }
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

extension MapWithIndex<T> on List<T> {
  List<R> mapWithIndex<R>(R Function(T, int i) callback) {
    List<R> result = [];
    for (int i = 0; i < length; i++) {
      R item = callback(this[i], i);
      result.add(item);
    }
    return result;
  }
}

class PreparationStepWithNameAndId {
  PreparationStepWithNameAndId({
    required this.id,
    required this.preparationName,
  });

  final String id;
  final String preparationName;
}
