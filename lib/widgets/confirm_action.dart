import 'package:flutter/material.dart';

import 'icon_tip.dart';

Future<bool> confirmChoice(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTip(
              icon: Icons.close,
              message: 'Cancel',
              onPressed: () => Navigator.pop(context, false),
            ),
            IconTip(
              icon: Icons.check,
              message: 'Confirm',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
