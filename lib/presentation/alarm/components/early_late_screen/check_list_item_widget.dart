import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/ealy_late_screen/early_late_screen_bloc.dart';

class ChecklistItemWidget extends StatelessWidget {
  final int index;
  final String label;

  const ChecklistItemWidget(
      {super.key, required this.index, required this.label});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EarlyLateScreenBloc, EarlyLateScreenState>(
      builder: (context, state) {
        if (state is EarlyLateScreenLoadSuccess) {
          bool isChecked = state.checklist[index];

          return GestureDetector(
            onTap: () {
              context
                  .read<EarlyLateScreenBloc>()
                  .add(ChecklistItemToggled(index));
            },
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    border: Border.all(
                      color: const Color(0xff5C79FB),
                      width: 2,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(5)),
                    color: isChecked
                        ? const Color(0xff5C79FB)
                        : Colors.transparent,
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 15),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isChecked ? const Color(0xff5C79FB) : Colors.black,
                    decoration: isChecked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
