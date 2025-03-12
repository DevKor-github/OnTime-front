import 'package:flutter/material.dart';

class TopBar extends StatelessWidget {
  const TopBar(
      {super.key,
      required this.onNextPAgeButtonClicked,
      required this.onPreviousPageButtonClicked});

  final void Function()? onNextPAgeButtonClicked;
  final void Function() onPreviousPageButtonClicked;

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
        TextButton(
          child: const Text('다음'),
          onPressed: onNextPAgeButtonClicked,
        ),
      ],
    );
  }
}
