import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class IconTip extends StatelessWidget {
  const IconTip({
    super.key,
    required this.icon,
    required this.message,
    this.onPressed,
    this.color,
    this.size = 24,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color ?? AppColors.accent, size: size),
      ),
    );
  }
}
