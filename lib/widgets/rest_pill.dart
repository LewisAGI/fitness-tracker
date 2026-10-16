import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RestPill extends StatefulWidget {
  const RestPill({super.key});

  @override
  State<RestPill> createState() => _RestPillState();
}

class _RestPillState extends State<RestPill> {
  static const _span = 90;
  var _left = _span;
  var _running = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_left <= 0) {
      _left = _span;
    }
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      if (_left <= 1) {
        _timer?.cancel();
        setState(() {
          _left = 0;
          _running = false;
        });
        return;
      }
      setState(() => _left -= 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _left ~/ 60;
    final seconds = (_left % 60).toString().padLeft(2, '0');
    return Tooltip(
      message: 'Rest',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('rest-pill'),
          onTap: _toggle,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.accent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_outlined,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
