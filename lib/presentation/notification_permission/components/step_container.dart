import 'package:flutter/material.dart';

class StepContainer extends StatelessWidget {
  const StepContainer({
    super.key,
    required this.step,
    required this.title,
    required this.image,
  });

  final int step;
  final RichText title;
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color.fromARGB(255, 242, 242, 247),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Title(
              step: step,
              title: title,
            ),
            const SizedBox(height: 12),
            image,
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({
    required this.step,
    required this.title,
  });

  final int step;
  final RichText title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step $step',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.outlineVariant,
          ),
        ),
        const SizedBox(height: 2),
        title,
      ],
    );
  }
}
