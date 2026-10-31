import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../../services/photo_service.dart';
import '../dialogs.dart';
import '../widgets/student_photo.dart';

/// Add a new student (student == null) or edit an existing one.
class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key, required this.classId, this.student});
  final String classId;
  final Student? student;

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  late final _first = TextEditingController(text: widget.student?.firstName ?? '');
  late final _last = TextEditingController(text: widget.student?.lastName ?? '');
  Student? _student;
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _store = context.read<AppStore>();
  }

  @override
  void dispose() {
    // A new student that got a photo but was never named is discarded.
    final s = _student;
    if (_isNew && s != null && s.fullName.isEmpty) {
      final f = _first.text.trim(), l = _last.text.trim();
      final store = _store;
      // Not during dispose itself: the widget tree is locked then.
      Future.microtask(() {
        if (f.isEmpty && l.isEmpty) {
          store.deleteStudent(s);
        } else {
          store.updateStudent(s, firstName: f, lastName: l);
        }
      });
    }
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  bool get _isNew => widget.student == null;

  /// New students are created on first photo pick or on save.
  Student _ensureStudent(AppStore store) => _student ??= store.upsertStudent(
        classId: widget.classId,
        firstName: _first.text.trim(),
        lastName: _last.text.trim(),
      );

  Future<void> _pickPhoto(bool camera) async {
    final store = context.read<AppStore>();
    try {
      final bytes = await PhotoService.pick(camera: camera);
      if (bytes == null) return;
      await store.setPhoto(_ensureStudent(store), bytes);
      setState(() {});
    } catch (e) {
      if (mounted) toast(context, context.tr('photoError'));
    }
  }

  void _save() {
    final store = context.read<AppStore>();
    if (_first.text.trim().isEmpty && _last.text.trim().isEmpty) return;
    if (_student == null) {
      _ensureStudent(store);
    } else {
      store.updateStudent(_student!, firstName: _first.text.trim(), lastName: _last.text.trim());
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = _student;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? context.tr('addStudent') : context.tr('editStudent')),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirm(context, title: context.tr('deleteStudentQ', {'name': s!.fullName}));
                if (ok && context.mounted) {
                  store.deleteStudent(s!);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: SizedBox(
            width: 200,
            height: 200,
            child: s != null
                ? StudentPhoto(s, radius: 24)
                : Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.person, size: 90, color: scheme.outline),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton.icon(
            onPressed: () => _pickPhoto(true),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(context.tr('camera')),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _pickPhoto(false),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(context.tr('gallery')),
          ),
        ]),
        if (s?.hasPhoto ?? false)
          Center(
            child: TextButton(
              onPressed: () {
                store.removePhoto(s!);
                setState(() {});
              },
              child: Text(context.tr('removePhoto')),
            ),
          ),
        const SizedBox(height: 20),
        TextField(
          controller: _first,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.tr('firstName')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _last,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.tr('lastName')),
        ),
        if (s != null && !_isNew) ...[
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _Stat(label: context.tr('level'), value: '${s.level}/${Student.maxLevel}'),
                _Stat(label: context.tr('correct'), value: '${s.correct}'),
                _Stat(label: context.tr('wrong'), value: '${s.wrong}'),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: Text(context.tr('save'))),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      ]);
}
