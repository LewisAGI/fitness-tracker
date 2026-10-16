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
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: IconButton(
        onPressed: onPressed,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        padding: compact ? EdgeInsets.zero : null,
        constraints: compact
            ? const BoxConstraints(minWidth: 32, minHeight: 32)
            : null,
        icon: Icon(icon, color: color ?? AppColors.accent, size: size),
      ),
    );
  }
}
