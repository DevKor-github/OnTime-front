import 'package:flutter/material.dart';

class ChecklistItemWidget extends StatelessWidget {
  final int index;
  final String label;
  final bool isChecked;
  final VoidCallback onToggle;

  const ChecklistItemWidget({
    super.key,
    required this.index,
    required this.label,
    required this.isChecked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
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
              color: isChecked ? const Color(0xff5C79FB) : Colors.transparent,
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
              decoration:
                  isChecked ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
