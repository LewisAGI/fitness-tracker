import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../services/dates.dart';
import '../services/export_summary.dart';
import '../services/share_export.dart';
import '../theme/app_theme.dart';
import 'icon_tip.dart';

const _titles = ['Workout', 'Day', 'Week', 'Month'];

Future<void> showShareDeck(BuildContext context, Store store) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Share',
    barrierColor: AppColors.ink.withValues(alpha: 0.72),
    pageBuilder: (context, _, _) => _ShareDeck(store: store),
  );
}

class _ShareDeck extends StatefulWidget {
  const _ShareDeck({required this.store});

  final Store store;

  @override
  State<_ShareDeck> createState() => _ShareDeckState();
}

class _ShareDeckState extends State<_ShareDeck> {
  final _controller = PageController(viewportFraction: 0.86);
  var _page = 0;
  List<ExportFiles?> _files = List<ExportFiles?>.filled(4, null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final today = dateOnly(widget.store.now());
    final bundle = await widget.store.loadDay(today);
    ExportFiles? workout;
    if (bundle.sessions.isNotEmpty) {
      workout = await widget.store.exportSession(bundle.sessions.last);
    }
    final day = await widget.store.exportRange(
      start: today,
      end: today,
      kind: 'day',
    );
    final start = weekStart(today);
    final week = await widget.store.exportRange(
      start: start,
      end: start.add(const Duration(days: 6)),
      kind: 'week',
    );
    final monthStart = DateTime(today.year, today.month);
    final month = await widget.store.exportRange(
      start: monthStart,
      end: DateTime(today.year, today.month + 1, 0),
      kind: 'month',
    );
    if (!mounted) {
      return;
    }
    setState(() => _files = [workout, day, week, month]);
  }

  ExportFiles? get _current =>
      _page >= 0 && _page < _files.length ? _files[_page] : null;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconTip(
                icon: Icons.close,
                message: 'Close',
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('share-deck'),
                controller: _controller,
                itemCount: _titles.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: _card(index),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _titles.length; i++)
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.accent : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _action(
                  key: const ValueKey('share-copy'),
                  icon: Icons.copy,
                  message: 'Copy',
                  filled: false,
                  onPressed: (_) async {
                    final text = _current?.plain;
                    if (text == null || text.isEmpty) {
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: text));
                  },
                ),
                const SizedBox(width: 22),
                _action(
                  key: const ValueKey('share-grok'),
                  icon: Icons.auto_awesome,
                  message: 'Grok',
                  filled: true,
                  onPressed: (buttonContext) async {
                    final text = _current?.plain;
                    if (text == null ||
                        text.isEmpty ||
                        !buttonContext.mounted) {
                      return;
                    }
                    await shareText(buttonContext, text);
                  },
                ),
                const SizedBox(width: 22),
                _action(
                  key: const ValueKey('share-files'),
                  icon: Icons.ios_share,
                  message: 'Share',
                  filled: false,
                  onPressed: (buttonContext) async {
                    final files = _current;
                    if (files == null || !buttonContext.mounted) {
                      return;
                    }
                    await shareExport(buttonContext, files);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _card(int index) {
    final files = _files[index];
    final preview = files?.plain ?? '';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                _titles[index].toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Text(
                preview,
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action({
    required Key key,
    required IconData icon,
    required String message,
    required bool filled,
    required Future<void> Function(BuildContext buttonContext) onPressed,
  }) {
    return Tooltip(
      message: message,
      child: Builder(
        builder: (buttonContext) => Material(
          key: key,
          color: filled ? AppColors.accent : AppColors.accentSoft,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onPressed(buttonContext),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                icon,
                color: filled ? Colors.white : AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
