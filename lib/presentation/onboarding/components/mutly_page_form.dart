import 'package:flutter/material.dart';

class MultiPageFormField extends Form {
  const MultiPageFormField({
    super.key,
    super.autovalidateMode,
    super.onChanged,
    super.canPop,
    required super.child,
    super.onPopInvokedWithResult,
    required this.onSaved,
  });

  final VoidCallback onSaved;

  @override
  // ignore: library_private_types_in_public_api
  _MultiPageFormFieldState createState() => _MultiPageFormFieldState();
}

class _MultiPageFormFieldState extends FormState {
  @override
  MultiPageFormField get widget => super.widget as MultiPageFormField;

  @override
  void save() {
    super.save();
    widget.onSaved();
  }
}
