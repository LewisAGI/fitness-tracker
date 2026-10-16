import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'icon_tip.dart';

Future<num?> showValuePicker({
  required BuildContext context,
  required List<num> values,
  required num current,
  required String Function(num value) label,
}) {
  return showDialog<num>(
    context: context,
    builder: (context) => _ValuePicker(
      values: values,
      current: current,
      label: label,
    ),
  );
}

class _ValuePicker extends StatefulWidget {
  const _ValuePicker({
    required this.values,
    required this.current,
    required this.label,
  });

  final List<num> values;
  final num current;
  final String Function(num value) label;

  @override
  State<_ValuePicker> createState() => _ValuePickerState();
}

class _ValuePickerState extends State<_ValuePicker> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    var index = 0;
    var best = double.infinity;
    for (var i = 0; i < widget.values.length; i++) {
      final gap = (widget.values[i] - widget.current).abs();
      if (gap < best) {
        best = gap.toDouble();
        index = i;
      }
    }
    _scroll = ScrollController(initialScrollOffset: (index - 2).clamp(0, 10000) * 48);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 220,
        height: 360,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconTip(
                icon: Icons.close,
                message: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemExtent: 48,
                itemCount: widget.values.length,
                itemBuilder: (context, index) {
                  final value = widget.values[index];
                  final selected = (value - widget.current).abs() < 0.001;
                  final text = widget.label(value);
                  return ListTile(
                    key: ValueKey('pick-$text'),
                    selected: selected,
                    selectedTileColor: AppColors.accentSoft,
                    title: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.accent : AppColors.ink,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, value),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
