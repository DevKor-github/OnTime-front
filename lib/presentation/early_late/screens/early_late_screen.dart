import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/early_late/bloc/early_late_screen_bloc.dart';
import 'package:on_time_front/presentation/early_late/components/check_list_box_widget.dart';
import 'package:on_time_front/presentation/early_late/components/early_late_message_image_widget.dart';
import 'package:on_time_front/presentation/shared/utils/time_format.dart';

class EarlyLateScreen extends StatelessWidget {
  final int earlyLateTime;
  final bool isLate;

  const EarlyLateScreen({
    super.key,
    required this.earlyLateTime,
    required this.isLate,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EarlyLateScreenBloc()
        ..add(LoadEarlyLateInfo(earlyLateTime: earlyLateTime))
        ..add(ChecklistLoaded(checklist: List.generate(3, (index) => false))),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            BlocBuilder<EarlyLateScreenBloc, EarlyLateScreenState>(
              builder: (context, state) {
                if (state is EarlyLateScreenLoadSuccess) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 70),
                        child: _EarlyLateSection(
                          earlyLateTime: earlyLateTime,
                          isLate: isLate,
                          screenHeight: MediaQuery.of(context).size.height,
                          earlylateMessage: state.earlylateMessage,
                          earlylateImage: state.earlylateImage,
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const _ButtonSection(),
          ],
        ),
      ),
    );
  }
}

class _EarlyLateSection extends StatelessWidget {
  final int earlyLateTime;
  final bool isLate;
  final double screenHeight;
  final String earlylateMessage;
  final String earlylateImage;

  const _EarlyLateSection({
    required this.earlyLateTime,
    required this.isLate,
    required this.screenHeight,
    required this.earlylateMessage,
    required this.earlylateImage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          _EarlyLateText(
            earlyLateTime: earlyLateTime,
            isLate: isLate,
          ),
          const SizedBox(height: 20),
          EarlyLateMessageImageWidget(
            screenHeight: screenHeight,
            earlylateMessage: earlylateMessage,
            earlylateImage: earlylateImage,
          ),
        ],
      ),
    );
  }
}

class _EarlyLateText extends StatelessWidget {
  final int earlyLateTime;
  final bool isLate;

  const _EarlyLateText({
    required this.earlyLateTime,
    required this.isLate,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isLate ? const Color(0xffFF6953) : const Color(0xff5C79FB);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatEalyLateTime(earlyLateTime),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          TextSpan(
            text: isLate
                ? AppLocalizations.of(context)!.late
                : AppLocalizations.of(context)!.early,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _CheckListBoxSection extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;
  final List<String> checkList;
  final List<bool> checkedStates;
  final Function(int) onItemToggled;

  const _CheckListBoxSection({
    required this.screenWidth,
    required this.screenHeight,
    required this.checkList,
    required this.checkedStates,
    required this.onItemToggled,
  });

  @override
  Widget build(BuildContext context) {
    return CheckListBoxWidget(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      checkList: checkList,
      checkedStates: checkedStates,
      onItemToggled: onItemToggled,
    );
  }
}

class _ButtonSection extends StatelessWidget {
  const _ButtonSection();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton(
          onPressed: () {
            context.go('/home');
          },
          child: Text(AppLocalizations.of(context)!.letsGo),
        ),
      ),
    );
  }
}
