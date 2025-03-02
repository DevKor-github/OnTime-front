import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/presentation/alarm/bloc/ealy_late_screen/early_late_screen_bloc.dart';

class EarlyLateMessageImageWidget extends StatelessWidget {
  final double screenHeight;

  const EarlyLateMessageImageWidget({super.key, required this.screenHeight});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EarlyLateScreenBloc, EarlyLateScreenState>(
      builder: (context, state) {
        if (state is EarlyLateScreenLoadSuccess) {
          return Column(
            children: [
              SizedBox(
                width: 292,
                height: 60,
                child: Text(
                  state.earlylateMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.01),
                child: Image.asset(
                  'assets/character.png',
                  width: 150,
                  height: 150,
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
