import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.onNextPageButtonClicked,
    required this.onPreviousPageButtonClicked,
    required this.isNextButtonEnabled,
  });

  final void Function()? onNextPageButtonClicked;
  final void Function() onPreviousPageButtonClicked;
  final bool isNextButtonEnabled; // 버튼 활성화 여부

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            onPreviousPageButtonClicked();
          },
        ),
        Expanded(
          child: Center(
              child: Text('약속 추가하기',
                  style: Theme.of(context).textTheme.titleMedium)),
        ),
        // 다음 페이지 버튼
        // 버튼 활성화 여부에 따라 색상 변화 추후 추가 가능
        TextButton(
          onPressed: onNextPageButtonClicked,
          child: const Text('다음'),
        ),
      ],
    );
  }
}
