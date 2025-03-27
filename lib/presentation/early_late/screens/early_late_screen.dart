import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/early_late/bloc/early_late_screen_bloc.dart';
import 'package:on_time_front/presentation/early_late/components/check_list_box_widget.dart';
import 'package:on_time_front/presentation/early_late/components/early_late_message_image_widget.dart';
import 'package:on_time_front/presentation/shared/components/button.dart';
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
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Center(
                    child: Column(
                      children: [
                        BlocBuilder<EarlyLateScreenBloc, EarlyLateScreenState>(
                          builder: (context, state) {
                            if (state is EarlyLateScreenLoadSuccess) {
                              final textColor = isLate
                                  ? const Color(0xffFF6953)
                                  : const Color(0xff5C79FB);

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
                                      text: isLate ? ' 지각했어요' : ' 일찍 준비했어요',
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
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 20),
                        // 지각/일찍 준비 문구 + 이미지 표시
                        EarlyLateMessageImageWidget(
                          screenHeight: MediaQuery.of(context).size.height,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 체크리스트 박스
                ChecklistBox(
                  screenWidth: MediaQuery.of(context).size.width,
                  screenHeight: MediaQuery.of(context).size.height,
                  items: ["우산 챙기기", "지갑 챙기기", "문 잠그기"],
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Button(
                  text: '까먹지 않고 출발',
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
