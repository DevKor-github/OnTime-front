import 'package:flutter/material.dart';

class MultiPageFormField extends Form {
  const MultiPageFormField({
    super.key,
    super.autovalidateMode,
    super.onChanged,
    super.canPop,
    required super.child,
    super.onPopInvokedWithResult,
    this.onSaved,
  });

  final VoidCallback? onSaved;

  @override
  _MultiPageFormFieldState createState() => _MultiPageFormFieldState();
}

class _MultiPageFormFieldState extends FormState {
  @override
  MultiPageFormField get widget => super.widget as MultiPageFormField;

  @override
  void save() {
    super.save();
    widget.onSaved!();
  }
}
