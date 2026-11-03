import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';

/// How many students of a group are new, being learned, or known.
///   new      – level 0 (never answered right, or forgotten again)
///   learning – level 1–4
///   known    – level 5 (top of the dots)
class LearningCounts {
  LearningCounts(Iterable<Student> students)
      : fresh = students.where((s) => s.level <= 0).length,
        learning = students.where((s) => s.level > 0 && s.level < Student.maxLevel).length,
        known = students.where((s) => s.level >= Student.maxLevel).length;

  final int fresh, learning, known;
  int get total => fresh + learning + known;
}

/// The three colours, shared by the bar and its legend.
class LearningColors {
  static Color fresh(ColorScheme s, {Color? onColor}) => (onColor ?? s.onSurface).withValues(alpha: 0.22);
  static Color learning(ColorScheme s) => Brand.amber;
  static Color known(ColorScheme s) => s.secondary;
}

/// One bar split into new / learning / known.
class LearningBar extends StatelessWidget {
  const LearningBar(this.counts, {super.key, this.height = 10, this.onColor});
  final LearningCounts counts;
  final double height;

  /// Text colour of the surface the bar sits on (for the "new" part).
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      (counts.known, LearningColors.known(scheme)),
      (counts.learning, LearningColors.learning(scheme)),
      (counts.fresh, LearningColors.fresh(scheme, onColor: onColor)),
    ].where((p) => p.$1 > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: parts.isEmpty
            ? Container(color: LearningColors.fresh(scheme, onColor: onColor))
            : Row(children: [
                for (var i = 0; i < parts.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(flex: parts[i].$1, child: Container(color: parts[i].$2)),
                ],
              ]),
      ),
    );
  }
}

/// "● 4 New   ● 19 Learning   ● 0 Known"
class LearningLegend extends StatelessWidget {
  const LearningLegend(this.counts, {super.key, this.onColor});
  final LearningCounts counts;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = onColor ?? scheme.onSurface;
    Widget item(Color dot, int n, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$n', style: TextStyle(fontWeight: FontWeight.w800, color: text)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: text.withValues(alpha: 0.75))),
        ]);
    return Wrap(spacing: 16, runSpacing: 6, children: [
      item(LearningColors.known(scheme), counts.known, context.tr('lvKnown')),
      item(LearningColors.learning(scheme), counts.learning, context.tr('lvLearning')),
      item(LearningColors.fresh(scheme, onColor: onColor), counts.fresh, context.tr('lvNew')),
    ]);
  }
}
