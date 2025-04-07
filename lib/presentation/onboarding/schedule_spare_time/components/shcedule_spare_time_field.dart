import 'package:flutter/widgets.dart';
import 'package:on_time_front/presentation/onboarding/screens/onboarding_screen.dart';
import 'package:on_time_front/presentation/shared/components/error_message_bubble.dart';
import 'package:on_time_front/presentation/shared/components/time_stepper.dart';

class ScheduleSpareTimeField extends StatelessWidget {
  ScheduleSpareTimeField({
    super.key,
    required this.lowerBound,
    required this.spareTime,
    required this.onSpareTimeDecreased,
    required this.onSpareTimeIncreased,
  });

  final Duration spareTime;
  final Duration lowerBound;
  final VoidCallback onSpareTimeIncreased;
  final VoidCallback onSpareTimeDecreased;
  final GlobalKey _fieldKey = GlobalKey();

  Rect? _getFieldPosition() {
    // Get the position and size of the ScheduleSpareTimeField
    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final topLeft = renderBox.localToGlobal(Offset.zero); // Top-left corner
      final bottomRight = renderBox.localToGlobal(Offset(
          renderBox.size.width, renderBox.size.height)); // Bottom-right corner

      return Rect.fromLTRB(
        topLeft.dx, // Left x
        topLeft.dy, // Top y
        bottomRight.dx, // Right x
        bottomRight.dy, // Bottom y
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = PageNotifierProvider.of(context);
    final OverlayPortalController overlayController = OverlayPortalController();

    Rect? fieldPosition;

    return ValueListenableBuilder(
      valueListenable: currentPage,
      builder: (context, value, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Safely get the field position after layout
          fieldPosition = _getFieldPosition();

          if (spareTime <= lowerBound &&
              value == value.roundToDouble() &&
              !overlayController.isShowing) {
            overlayController.show();
          } else if (overlayController.isShowing) {
            overlayController.hide();
          }
        });

        return Padding(
          padding: EdgeInsets.only(top: 90.0),
          child: Column(
            children: [
              TimeStepper(
                key: _fieldKey,
                onSpareTimeIncreased: onSpareTimeIncreased,
                onSpareTimeDecreased: onSpareTimeDecreased,
                lowerBound: lowerBound,
                value: spareTime,
              ),
              OverlayPortal(
                controller: overlayController,
                overlayChildBuilder: (context) => Positioned(
                  top: fieldPosition?.bottom, // Adjust position dynamically
                  left: fieldPosition?.left,
                  child: ErrorMessageBubble(
                    errorMessage:
                        Text('여유시간은 ${lowerBound.inMinutes}분 아래로 설정할 수 없어요 '),
                    tailPosition: TailPosition.top,
                  ),
                ),
              ),
              Expanded(child: SizedBox()),
            ],
          ),
        );
      },
    );
  }
}
