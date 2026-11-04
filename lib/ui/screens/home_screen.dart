import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../services/demo_data.dart';
import '../dialogs.dart';
import '../theme.dart';
import '../widgets/learning_bar.dart';
import '../widgets/nameit_logo.dart';
import 'class_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// School years as sections, classes as cards.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final years = store.yearsSorted;

    return Scaffold(
      appBar: AppBar(
        title: const NameItLockup(),
        actions: [
          // Tapping the flame or the stars opens the stats and badges.
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
            child: Tooltip(
              message: context.tr('stats'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _StatChip(icon: Icons.local_fire_department_rounded, value: '${store.currentStreak}', color: Brand.coral),
                const SizedBox(width: 6),
                _StatChip(icon: Icons.star_rounded, value: '${store.xpThisYear}', color: Theme.of(context).colorScheme.tertiary),
              ]),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.tr('settings'),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addMenu(context),
        tooltip: context.tr('add'),
        child: const Icon(Icons.add),
      ),
      body: years.isEmpty
          ? _EmptyState(onImport: () => _openImport(context))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                for (final y in years) ...[
                  _YearHeader(year: y),
                  // Year → school → class. With classes from one source only,
                  // the school heading is left out and nothing changes.
                  if (store.classesBySchool(y.id).length < 2)
                    _ClassGrid(classes: store.classesOf(y.id))
                  else
                    for (final (school, classes) in store.classesBySchool(y.id)) ...[
                      _SchoolHeader(school == null ? context.tr('otherClasses') : store.schoolName(school)),
                      _ClassGrid(classes: classes),
                      const SizedBox(height: 12),
                    ],
                  const SizedBox(height: 20),
                ],
              ],
            ),
    );
  }

  static void _openImport(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportScreen()));

  Future<void> _addMenu(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.cloud_download_outlined),
            title: Text(ctx.tr('importData')),
            subtitle: Text(ctx.tr('importDataSub')),
            onTap: () => Navigator.pop(ctx, 'import'),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(ctx.tr('demoLoad')),
            subtitle: Text(ctx.tr('demoLoadSub')),
            onTap: () => Navigator.pop(ctx, 'demo'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(ctx.tr('newYear')),
            onTap: () => Navigator.pop(ctx, 'year'),
          ),
          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(ctx.tr('newClass')),
            onTap: () => Navigator.pop(ctx, 'class'),
          ),
        ]),
      ),
    );
    if (!context.mounted || choice == null) return;
    final store = context.read<AppStore>();
    switch (choice) {
      case 'import':
        _openImport(context);
      case 'demo':
        await loadDemo(context);
      case 'year':
        {
          final name = await askText(context, title: context.tr('newYear'), hint: defaultYearName());
          if (name != null && name.isNotEmpty) store.addYear(name);
        }
      case 'class':
        {
          var years = store.yearsSorted;
          if (years.isEmpty) {
            store.addYear(defaultYearName());
            years = store.yearsSorted;
          }
          if (!context.mounted) return;
          final name = await askText(context, title: context.tr('newClass'), hint: '3B');
          if (name != null && name.isNotEmpty) store.addClass(years.first.id, name);
        }
    }
  }
}

/// Loads the demo classes and says which ones were added.
Future<void> loadDemo(BuildContext context) async {
  final names = await DemoData.load(context.read<AppStore>());
  if (context.mounted) toast(context, context.tr('demoLoaded', {'names': names.join(', ')}));
}

/// "2026/27" for the school year that contains today (starts in September).
String defaultYearName() {
  final now = DateTime.now();
  final start = now.month >= 8 ? now.year : now.year - 1;
  return '$start/${(start + 1) % 100}';
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value, required this.color});
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.year});
  final SchoolYear year;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(children: [
        Text(year.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                )),
        const Spacer(),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          onSelected: (v) async {
            if (v == 'rename') {
              final n = await askText(context, title: context.tr('rename'), initial: year.name);
              if (n != null && n.isNotEmpty) store.renameYear(year, n);
            } else if (v == 'class') {
              final n = await askText(context, title: context.tr('newClass'), hint: '3B');
              if (n != null && n.isNotEmpty) store.addClass(year.id, n);
            } else if (v == 'delete') {
              final ok = await confirm(context,
                  title: context.tr('deleteYearQ', {'name': year.name}), message: context.tr('deleteYearMsg'));
              if (ok) store.deleteYear(year);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'class', child: Text(ctx.tr('newClass'))),
            PopupMenuItem(value: 'rename', child: Text(ctx.tr('rename'))),
            PopupMenuItem(value: 'delete', child: Text(ctx.tr('delete'))),
          ],
        ),
      ]),
    );
  }
}

class _SchoolHeader extends StatelessWidget {
  const _SchoolHeader(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(Icons.school_outlined, size: 16, color: scheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: scheme.outline)),
        ),
      ]),
    );
  }
}

class _ClassGrid extends StatelessWidget {
  const _ClassGrid({required this.classes});
  final List<SchoolClass> classes;

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return Text(context.tr('noClassesYet'), style: TextStyle(color: Theme.of(context).colorScheme.outline));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemCount: classes.length,
      itemBuilder: (ctx, i) => _ClassCard(cls: classes[i]),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.cls});
  final SchoolClass cls;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final counts = LearningCounts(store.studentsOf(cls.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClassScreen(classId: cls.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cls.name, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: scheme.primary)),
            Text(context.tr('nStudents', {'n': counts.total}), style: TextStyle(color: scheme.outline)),
            const Spacer(),
            LearningBar(counts, height: 8),
            const SizedBox(height: 6),
            Text(context.tr('knownOf', {'n': counts.known, 'total': counts.total}),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const NameItLogo(size: 96),
            const SizedBox(height: 20),
            Text(context.tr('welcomeTitle'),
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(context.tr('welcomeText'), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(context.tr('importData')),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => loadDemo(context),
              icon: const Icon(Icons.science_outlined),
              label: Text(context.tr('demoTry')),
            ),
          ]),
        ),
      );
}
