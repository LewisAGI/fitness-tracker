import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/training.dart';
import '../services/patterns.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, required this.store});

  final Store store;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  List<StoredPattern> _patterns = [];

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final patterns = await widget.store.patterns();
    if (mounted) {
      setState(() => _patterns = patterns);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: ListView(
        children: [
          for (final pattern in _patterns)
            ListTile(
              title: Text(prettyPatternKey(pattern.key)),
              trailing: Text(
                'N ${pattern.n}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${pattern.meanNextReadiness.round()} · ${pattern.meanNextFatigue.round()}',
              ),
            ),
        ],
      ),
    );
  }
}
