import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/onboarding/components/onboarding_page_view_layout.dart';
import 'package:on_time_front/presentation/onboarding/preparation_order/cubit/preparation_order_cubit.dart';
import 'package:on_time_front/presentation/shared/components/tile.dart';
import 'package:on_time_front/presentation/shared/theme/tile_style.dart';

class PreparationReorderableList extends StatelessWidget {
  PreparationReorderableList(
      {super.key,
      required this.preparationOrderingList,
      required this.onReorder});

  final List<PreparationStepOrderState> preparationOrderingList;
  final Function(int oldIndex, int newIndex) onReorder;

  final Widget dragIndicatorSvg = SvgPicture.asset(
    'assets/drag_indicator.svg',
    semanticsLabel: 'drag indicator',
    height: 14,
    width: 14,
    fit: BoxFit.contain,
  );

  @override
  Widget build(BuildContext context) {
    Widget proxyDecorator(
        Widget child, int index, Animation<double> animation) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          return SizedBox(
            child: child,
          );
        },
        child: child,
      );
    }

    return SingleChildScrollView(
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        proxyDecorator: proxyDecorator,
        itemCount: preparationOrderingList.length,
        itemBuilder: (context, index) => Padding(
          key: ValueKey<String>(preparationOrderingList[index].preparationId),
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Tile(
            style: TileStyle(
              backgroundColor: Color(0xFFE6E9F9),
            ),
            trailing: ReorderableDragStartListener(
              index: index,
              child: dragIndicatorSvg,
            ),
            child: Text(
              preparationOrderingList[index].preparationName,
            ),
          ),
        ),
        onReorder: onReorder,
      ),
    );
  }
}

class PreparationReorderField extends StatefulWidget {
  const PreparationReorderField({
    super.key,
    required this.formKey,
  });

  final GlobalKey<FormState> formKey;

  @override
  State<PreparationReorderField> createState() =>
      _PreparationReorderFieldState();
}

class _PreparationReorderFieldState extends State<PreparationReorderField> {
  @override
  void initState() {
    context.read<PreparationOrderCubit>().initialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return OnboardingPageViewLayout(
      title: Text(
        '평소 준비 과정의 순서로\n조정해주세요',
        style: textTheme.titleLarge,
      ),
      child: Form(
        key: widget.formKey,
        child: BlocBuilder<PreparationOrderCubit, PreparationOrderState>(
            builder: (context, state) {
          return PreparationReorderableList(
            preparationOrderingList: state.preparationStepList,
            onReorder: (oldIndex, newIndex) {
              context
                  .read<PreparationOrderCubit>()
                  .preparationOrderChanged(oldIndex, newIndex);
            },
          );
        }),
      ),
    );
  }
}
