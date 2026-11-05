import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/badges.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/learning_bar.dart';
import '../widgets/student_photo.dart';

/// Streak, XP, accuracy, the last two weeks, badges and who needs practice.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Selected school year; null = the current one.
  String? _yearId;

  @override
  void initState() {
    super.initState();
    // Badges that don't depend on a single game (e.g. a fully mastered class
    // after an import) are unlocked here too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppStore>().checkBadges();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final years = store.yearsSorted;
    final year = store.yearById(_yearId ?? '') ?? store.currentYear ?? (years.isEmpty ? null : years.first);

    // Everything below except streak and badges counts for this school year only.
    final yearName = year?.name ?? '';
    final totals = store.totalsIn(yearName);
    final range = AppStore.yearRange(yearName);
    final yearStudents = year == null ? store.students : store.studentsOfYear(year.id);
    final yearStudentIds = yearStudents.map((s) => s.id).toSet();
    final accuracy = totals.answers == 0 ? null : totals.correct / totals.answers;
    final weakest = store.weakest.where((s) => yearStudentIds.contains(s.id)).take(5).toList();
    final counts = LearningCounts(yearStudents);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('stats')),
        actions: [
          if (year != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: years.length < 2
                  ? Center(child: Text(year.name, style: TextStyle(color: scheme.outline)))
                  : PopupMenuButton<String>(
                      tooltip: context.tr('schoolYear'),
                      initialValue: year.id,
                      onSelected: (id) => setState(() => _yearId = id),
                      itemBuilder: (ctx) => [for (final y in years) PopupMenuItem(value: y.id, child: Text(y.name))],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(year.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const Icon(Icons.arrow_drop_down),
                        ]),
                      ),
                    ),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Row(children: [
          _Tile(
            icon: Icons.local_fire_department_rounded,
            color: Brand.coral,
            value: '${store.currentStreak}',
            label: context.tr('statStreak'),
            sub: context.tr('statBest', {'n': store.bestStreak}),
          ),
          const SizedBox(width: 10),
          _Tile(
            icon: Icons.star_rounded,
            color: scheme.tertiary,
            value: '${totals.xp}',
            label: 'XP',
            sub: context.tr('statGames', {'n': totals.games}),
          ),
          const SizedBox(width: 10),
          _Tile(
            icon: Icons.track_changes_rounded,
            color: scheme.secondary,
            value: accuracy == null ? '–' : '${(accuracy * 100).round()}%',
            label: context.tr('statAccuracy'),
            sub: context.tr('statAnswers', {'n': totals.answers}),
          ),
        ]),
        const SizedBox(height: 24),
        _Section(context.tr('statLast14')),
        _ActivityChart(store: store, until: range.end.subtract(const Duration(days: 1))),
        const SizedBox(height: 24),
        _Section(context.tr('statMastered', {'n': counts.known, 'total': counts.total})),
        _MasteryList(store: store, yearId: year?.id),
        const SizedBox(height: 10),
        LearningLegend(counts),
        const SizedBox(height: 24),
        _Section(context.tr('badges', {'n': store.unlockedBadges.length, 'total': badges.length})),
        _BadgeGrid(store: store),
        if (weakest.isNotEmpty) ...[
          const SizedBox(height: 24),
          _Section(context.tr('statNeedsPractice')),
          for (final s in weakest)
            _WeakRow(
              student: s,
              className: store.classById(s.classId) == null ? '' : store.classLabel(store.classById(s.classId)!),
            ),
        ],
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.value, required this.label, required this.sub});
  final IconData icon;
  final Color color;
  final String value, label, sub;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.outline;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: [FontFeature.tabularFigures()])),
            ),
            // One line: long words like "Treffsicherheit" shrink instead of breaking.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: muted)),
          ]),
        ),
      ),
    );
  }
}

/// One bar per day: full height = answers, filled part = correct.
class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.store, required this.until});
  final AppStore store;

  /// Last day of the school year; the chart ends there for past years.
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = until.isBefore(now) ? until : now;
    final dayList = [for (var i = 13; i >= 0; i--) DateTime(today.year, today.month, today.day - i)];
    final data = dayList.map(store.dayStats).toList();
    final maxAnswers = data.fold<int>(0, (m, d) => d[0] > m ? d[0] : m);
    final weekday = MaterialLocalizations.of(context).narrowWeekdays; // Sunday first

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: maxAnswers == 0
            ? SizedBox(
                height: 90,
                child: Center(child: Text(context.tr('statNoActivity'), style: TextStyle(color: scheme.outline))),
              )
            : Column(children: [
                SizedBox(
                  height: 110,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    for (final d in data)
                      Expanded(
                        child: Tooltip(
                          message: context.tr('statDayTip', {'n': d[0], 'c': d[1]}),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _Bar(total: d[0], correct: d[1], max: maxAnswers),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  for (final day in dayList)
                    Expanded(
                      child: Text(
                        weekday[day.weekday % 7],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: day == dayList.last ? FontWeight.w800 : FontWeight.w400,
                          color: day == dayList.last ? scheme.onSurface : scheme.outline,
                        ),
                      ),
                    ),
                ]),
              ]),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.total, required this.correct, required this.max});
  final int total, correct, max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (ctx, box) {
      if (total == 0) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(height: 3, decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
        );
      }
      final h = (box.maxHeight * total / max).clamp(6.0, box.maxHeight);
      return Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
            height: h,
            child: Column(children: [
              if (total > correct)
                Expanded(flex: total - correct, child: Container(color: scheme.primary.withValues(alpha: 0.25))),
              if (correct > 0) Expanded(flex: correct, child: Container(color: scheme.primary)),
            ]),
          ),
        ),
      );
    });
  }
}

class _MasteryList extends StatelessWidget {
  const _MasteryList({required this.store, required this.yearId});
  final AppStore store;
  final String? yearId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      for (final y in store.yearsSorted)
        if (yearId == null || y.id == yearId)
          for (final c in store.classesOf(y.id))
            if (store.studentsOf(c.id).isNotEmpty) c,
    ];
    if (rows.isEmpty) {
      return Text(context.tr('noClassesYet'), style: TextStyle(color: scheme.outline));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: [
          for (final c in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(
                    width: 96,
                    child: Text(store.classLabel(c),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: LearningBar(LearningCounts(store.studentsOf(c.id)), height: 8)),
                SizedBox(
                  width: 56,
                  child: Text(
                      '${LearningCounts(store.studentsOf(c.id)).known}/${store.studentsOf(c.id).length}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.78,
        children: [
          for (final b in badges)
            BadgeTile(
              badge: b,
              unlocked: store.unlockedBadges.containsKey(b.id),
              onTap: () => _showBadge(context, b, store.unlockedBadges[b.id]),
            ),
        ],
      );

  void _showBadge(BuildContext context, BadgeDef b, String? date) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BadgeIcon(badge: b, unlocked: date != null, size: 84),
            const SizedBox(height: 14),
            Text(ctx.tr(b.titleKey), style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(ctx.tr(b.descKey), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              date == null
                  ? ctx.tr('badgeLocked')
                  : ctx.tr('badgeSince', {'d': MaterialLocalizations.of(ctx).formatMediumDate(DateTime.parse(date))}),
              style: TextStyle(color: Theme.of(ctx).colorScheme.outline),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Round badge icon; grey with a lock while locked.
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({super.key, required this.badge, required this.unlocked, this.size = 56});
  final BadgeDef badge;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: unlocked ? badge.color.withValues(alpha: 0.16) : scheme.surfaceContainerHighest,
            border: Border.all(color: unlocked ? badge.color : scheme.outlineVariant, width: 2),
          ),
          child: Icon(badge.icon, size: size * 0.5, color: unlocked ? badge.color : scheme.outline.withValues(alpha: 0.6)),
        ),
        if (!unlocked)
          Positioned(
            right: -2,
            bottom: -2,
            child: CircleAvatar(
              radius: size * 0.16,
              backgroundColor: scheme.surface,
              child: Icon(Icons.lock_rounded, size: size * 0.18, color: scheme.outline),
            ),
          ),
      ]),
    );
  }
}

class BadgeTile extends StatelessWidget {
  const BadgeTile({super.key, required this.badge, required this.unlocked, this.onTap});
  final BadgeDef badge;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(children: [
          BadgeIcon(badge: badge, unlocked: unlocked),
          const SizedBox(height: 6),
          Text(
            context.tr(badge.titleKey),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: unlocked ? null : Theme.of(context).colorScheme.outline,
            ),
          ),
        ]),
      );
}

class _WeakRow extends StatelessWidget {
  const _WeakRow({required this.student, required this.className});
  final Student student;
  final String className;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          StudentPhoto(student, size: 48, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(className, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
            ]),
          ),
          Text(context.tr('statWrongN', {'n': student.wrong}),
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
        ]),
      );
}
