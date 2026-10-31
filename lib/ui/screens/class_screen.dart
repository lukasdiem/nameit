import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../dialogs.dart';
import '../games/game_modes.dart';
import '../widgets/student_photo.dart';
import 'student_screen.dart';

class ClassScreen extends StatelessWidget {
  const ClassScreen({super.key, required this.classId});
  final String classId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cls = store.classById(classId);
    if (cls == null) return const Scaffold(); // deleted while open
    final students = store.studentsOf(classId);
    final withPhoto = students.where((s) => s.hasPhoto).length;
    final mastered = students.where((s) => s.level >= Student.maxLevel).length;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(cls.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: context.tr('addStudent'),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => StudentScreen(classId: classId))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final n = await askText(context, title: context.tr('rename'), initial: cls.name);
                if (n != null && n.isNotEmpty) store.renameClass(cls, n);
              } else if (v == 'delete') {
                final ok = await confirm(context, title: context.tr('deleteClassQ', {'name': cls.name}));
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  store.deleteClass(cls);
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'rename', child: Text(ctx.tr('rename'))),
              PopupMenuItem(value: 'delete', child: Text(ctx.tr('delete'))),
            ],
          ),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(context.tr('masteredOf', {'n': mastered, 'total': students.length}),
                          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
                    ),
                    Text('${(store.mastery(classId) * 100).round()}%',
                        style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer)),
                  ]),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: store.mastery(classId),
                      minHeight: 10,
                      backgroundColor: scheme.surface.withValues(alpha: 0.5),
                    ),
                  ),
                  if (withPhoto < students.length) ...[
                    const SizedBox(height: 10),
                    Text(context.tr('missingPhotos', {'n': students.length - withPhoto}),
                        style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: students.isEmpty ? null : () => showGamePicker(context, classId),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(context.tr('play')),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        if (students.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(context.tr('noStudentsYet'))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 130,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: students.length,
              itemBuilder: (ctx, i) => _StudentTile(student: students[i]),
            ),
          ),
      ]),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student});
  final Student student;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StudentScreen(classId: student.classId, student: student)),
        ),
        child: Column(children: [
          AspectRatio(aspectRatio: 1, child: StudentPhoto(student)),
          const SizedBox(height: 6),
          Text(student.firstName,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(student.lastName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 4),
          LevelDots(student.level),
        ]),
      );
}
