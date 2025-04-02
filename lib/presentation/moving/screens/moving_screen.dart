import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class MovingScreen extends StatelessWidget {
  const MovingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Center(
              child: Column(
                children: [
                  _TextSection(),
                  Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: SvgPicture.asset(
                      'characters/character_success_1.svg',
                      package: 'assets',
                      width: 204,
                      height: 269,
                    ),
                  ),
                  const SizedBox(height: 60),
                  Text(
                    '약속 장소로 열심히 이동 중...',
                    style: TextStyle(
                      fontSize: 18,
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Progress Bar
                  _ProgressBarSection(),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ExpectingArrivalTimeText(),
          const SizedBox(height: 5),
          _RemainingMoveTimeText(),
        ],
      ),
    );
  }
}

class _ExpectingArrivalTimeText extends StatelessWidget {
  const _ExpectingArrivalTimeText();

  @override
  Widget build(BuildContext context) {
    return Text(
      '오후 6:18 도착',
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colorScheme.primary,
      ),
    );
  }
}

class _RemainingMoveTimeText extends StatelessWidget {
  const _RemainingMoveTimeText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '도착까지',
          style: TextStyle(
            fontSize: 28,
            color: colorScheme.onSurface,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '1시간 10분',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: ' 남았어요',
                  style: TextStyle(
                    fontSize: 28,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        )
      ],
    );
  }
}

class _ProgressBarSection extends StatelessWidget {
  const _ProgressBarSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Stack(
        children: [
          // Background Bar
          Container(
            width: 300,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          SizedBox(
            height: 8,
          ),
          // Progress Indicator
          Container(
            width: 100,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ],
      ),
    );
  }
}
