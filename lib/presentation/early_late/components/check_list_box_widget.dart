import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/early_late/bloc/early_late_screen_bloc.dart';
import 'package:on_time_front/presentation/early_late/components/check_list_item_widget.dart';

class ChecklistBox extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;
  final List<String> items; // 체크리스트 항목들

  const ChecklistBox({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EarlyLateScreenBloc, EarlyLateScreenState>(
      builder: (context, state) {
        if (state is EarlyLateScreenLoadSuccess) {
          return Center(
            child: SizedBox(
              width: screenWidth * 0.9,
              height: screenHeight * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xffF6F6F6),
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '나가기 전에 확인하세요',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(
                          items.length,
                          (index) => Padding(
                            padding:
                                EdgeInsets.only(bottom: screenHeight * 0.01),
                            child: ChecklistItemWidget(
                              index: index,
                              label: items[index],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
