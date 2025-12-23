import 'package:flutter/material.dart';

TextButton appBarTextButton({
  required String label,
  required VoidCallback? onPressed,
}) {
  return TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: Colors.black,
      disabledForegroundColor: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    child: Text(label),
  );
}

AppBar standardAppBar({
  required String title,
  Widget? leading,
  double? leadingWidth,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 1,
    automaticallyImplyLeading: false,
    title: Text(title),
    leading: leading,
    leadingWidth: leadingWidth,
    actions: actions,
  );
}