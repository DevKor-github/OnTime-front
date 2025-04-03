import 'package:flutter/material.dart';

mixin OverlayStateMixin<T extends StatefulWidget> on State<T> {
  OverlayEntry? _overlayEntry;

  bool get isOverlayShown => _overlayEntry != null;

  void toggleOverlay(Widget child) =>
      isOverlayShown ? removeOverlay() : _insertOverlay(child);

  void showOverlay(Widget child) {
    if (isOverlayShown) {
      return;
    }
    _insertOverlay(child);
  }

  void removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _dismissibleOverlay(Widget child) => Stack(
        children: [
          child,
        ],
      );

  void _insertOverlay(Widget child) {
    _overlayEntry = OverlayEntry(
      builder: (_) => _dismissibleOverlay(child),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }
}
