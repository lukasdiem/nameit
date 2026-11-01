import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../services/file_import.dart';
import '../../services/webuntis_service.dart';
import '../dialogs.dart';
import 'home_screen.dart' show defaultYearName;

const _secure = FlutterSecureStorage();
const _pwKey = 'untis_password';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.tr('importData')),
            bottom: TabBar(tabs: [
              const Tab(text: 'WebUntis'),
              Tab(text: context.tr('file')),
              Tab(text: context.tr('manual')),
            ]),
          ),
          body: const TabBarView(children: [_WebUntisTab(), _FileTab(), _ManualTab()]),
        ),
      );
}

// =====================================================================
// WebUntis
// =====================================================================

enum _Step { login, select, running, done }

class _WebUntisTab extends StatefulWidget {
  const _WebUntisTab();
  @override
  State<_WebUntisTab> createState() => _WebUntisTabState();
}

class _WebUntisTabState extends State<_WebUntisTab> with AutomaticKeepAliveClientMixin {
  final _link = TextEditingController();
  final _server = TextEditingController();
  final _school = TextEditingController();
  final _user = TextEditingController();
  final _pw = TextEditingController();
  final _filter = TextEditingController();
  bool _remember = false;
  bool _busy = false;
  String? _error;

  _Step _step = _Step.login;
  WebUntisClient? _client;
  List<UntisYear> _years = [];
  UntisYear? _year;
  List<UntisClass> _classes = [];
  final Set<int> _selected = {};
  bool _loadPhotos = true;

  double _progress = 0;
  String _status = '';
  List<UntisStudent>? _allStudentsCache;
  int _importedStudents = 0, _importedPhotos = 0;
  final List<({String name, int students, int photos})> _summary = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>().settings;
    _server.text = s.untisServer;
    _school.text = s.untisSchool;
    _user.text = s.untisUser;
    _remember = s.rememberPassword;
    if (_remember) {
      _secure.read(key: _pwKey).then((v) {
        if (v != null && mounted) setState(() => _pw.text = v);
      });
    }
    _link.addListener(() {
      final parsed = WebUntisClient.parseLoginUrl(_link.text);
      if (parsed != null) {
        _server.text = parsed.server;
        if (parsed.school.isNotEmpty) _school.text = parsed.school;
      }
    });
  }

  @override
  void dispose() {
    _client?.logout();
    for (final c in [_link, _server, _school, _user, _pw, _filter]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    try {
      final client = WebUntisClient(server: _server.text, school: _school.text.trim());
      await client.login(_user.text.trim(), _pw.text);
      store.updateSettings((s) {
        s.untisServer = client.host;
        s.untisSchool = client.school;
        s.untisUser = _user.text.trim();
        s.rememberPassword = _remember;
      });
      if (_remember) {
        await _secure.write(key: _pwKey, value: _pw.text);
      } else {
        await _secure.delete(key: _pwKey);
      }
      final years = await client.schoolYears();
      final current = await client.currentSchoolYear();
      _client = client;
      _years = years;
      _year = years.where((y) => y.id == current?.id).firstOrNull ?? (years.isNotEmpty ? years.first : null);
      await _loadClasses();
      if (mounted) setState(() => _step = _Step.select);
    } on WebUntisException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.isBadCredentials ? context.tr('badLogin') : '${context.tr('connectError')} ($e)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '${context.tr('connectError')} ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadClasses() async {
    if (_year == null) return;
    _classes = await _client!.classes(_year!.id);
    _selected.clear();
  }

  Future<void> _runImport() async {
    final store = context.read<AppStore>();
    final client = _client!;
    final year = _year!;
    final chosen = _classes.where((c) => _selected.contains(c.id)).toList();
    final template = store.settings.photoUrlTemplate;
    final photos = _loadPhotos;

    setState(() {
      _step = _Step.running;
      _progress = 0;
      _importedStudents = 0;
      _importedPhotos = 0;
      _summary.clear();
    });

    final localYear = store.addYear(year.name, untisId: year.id);

    for (var i = 0; i < chosen.length; i++) {
      final uc = chosen[i];
      if (!mounted) return;
      setState(() => _status = context.tr('importingClass', {'name': uc.name}));

      List<UntisStudent> roster;
      try {
        roster = await client.classStudents(uc.id, year.sampleDate);
      } on ClassRosterUnavailable {
        // Fallback: let the teacher pick the students of this class.
        try {
          _allStudentsCache ??= await client.allStudents();
        } catch (_) {
          _allStudentsCache = [];
        }
        if (!mounted) return;
        if (_allStudentsCache!.isEmpty) {
          toast(context, context.tr('noRosterAccess'));
          roster = [];
        } else {
          roster = await Navigator.push<List<UntisStudent>>(
                context,
                MaterialPageRoute(
                    builder: (_) => _PickStudentsScreen(className: uc.name, all: _allStudentsCache!)),
              ) ??
              [];
        }
      }

      final localClass = store.addClass(localYear.id, uc.name, untisId: uc.id);
      final photosBefore = _importedPhotos;
      for (var j = 0; j < roster.length; j++) {
        final us = roster[j];
        final s = store.upsertStudent(
          classId: localClass.id,
          firstName: us.firstName,
          lastName: us.lastName,
          untisId: us.id,
          notify: false,
        );
        _importedStudents++;
        if (photos) {
          try {
            final bytes = await client.photo(template, us.id);
            if (bytes != null) {
              await store.setPhoto(s, bytes, notify: false);
              _importedPhotos++;
            }
          } catch (_) {}
        }
        if (mounted) setState(() => _progress = (i + (j + 1) / roster.length) / chosen.length);
      }
      _summary.add((name: uc.name, students: roster.length, photos: _importedPhotos - photosBefore));
      store.commit();
    }
    if (mounted) setState(() => _step = _Step.done);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return switch (_step) {
      _Step.login => _buildLogin(),
      _Step.select => _buildSelect(),
      _Step.running => _buildRunning(),
      _Step.done => _buildDone(),
    };
  }

  Widget _buildLogin() => ListView(padding: const EdgeInsets.all(20), children: [
        Text(context.tr('untisIntro')),
        const SizedBox(height: 16),
        TextField(
          controller: _link,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: context.tr('untisLink'),
            hintText: 'https://….webuntis.com/WebUntis/?school=…',
            prefixIcon: const Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(controller: _server, decoration: InputDecoration(labelText: context.tr('server'))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(controller: _school, decoration: InputDecoration(labelText: context.tr('school'))),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _user,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.tr('username')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          obscureText: true,
          decoration: InputDecoration(labelText: context.tr('password')),
          onSubmitted: (_) => _connect(),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _remember,
          onChanged: (v) => setState(() => _remember = v ?? false),
          title: Text(context.tr('rememberPw')),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(context.tr('connect')),
        ),
        const SizedBox(height: 16),
        Text(context.tr('privacyNote'),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
      ]);

  Widget _buildSelect() {
    final q = _filter.text.toLowerCase();
    final visible = _classes
        .where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || c.longName.toLowerCase().contains(q))
        .toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(children: [
          DropdownButtonFormField<int>(
            initialValue: _year?.id,
            decoration: InputDecoration(labelText: context.tr('schoolYear')),
            items: [for (final y in _years) DropdownMenuItem(value: y.id, child: Text(y.name))],
            onChanged: (id) async {
              _year = _years.firstWhere((y) => y.id == id);
              await _loadClasses();
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _filter,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('searchClass')),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: visible.length,
          itemBuilder: (ctx, i) {
            final c = visible[i];
            return CheckboxListTile(
              value: _selected.contains(c.id),
              onChanged: (v) => setState(() => v! ? _selected.add(c.id) : _selected.remove(c.id)),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: c.longName.isNotEmpty && c.longName != c.name ? Text(c.longName) : null,
            );
          },
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _loadPhotos,
              onChanged: (v) => setState(() => _loadPhotos = v),
              title: Text(context.tr('loadPhotos')),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty ? null : _runImport,
                child: Text(context.tr('importNClasses', {'n': _selected.length})),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildRunning() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: _progress, minHeight: 10, borderRadius: BorderRadius.circular(6)),
            const SizedBox(height: 16),
            Text(_status),
          ]),
        ),
      );

  Widget _buildDone() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Icon(Icons.check_circle_rounded, size: 72, color: scheme.primary),
      const SizedBox(height: 16),
      Text(context.tr('importDone', {'n': _importedStudents, 'p': _importedPhotos}), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      Card(
        child: Column(children: [
          for (final c in _summary)
            ListTile(
              dense: true,
              leading: Icon(
                c.students == 0 ? Icons.warning_amber_rounded : Icons.groups_outlined,
                color: c.students == 0 ? scheme.error : scheme.primary,
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text(
                context.tr('classSummary', {'n': c.students, 'p': c.photos}),
                style: TextStyle(color: c.students == 0 ? scheme.error : null),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 24),
      FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('done'))),
    ]);
  }
}

/// Fallback when WebUntis doesn't tell us who is in a class.
class _PickStudentsScreen extends StatefulWidget {
  const _PickStudentsScreen({required this.className, required this.all});
  final String className;
  final List<UntisStudent> all;

  @override
  State<_PickStudentsScreen> createState() => _PickStudentsScreenState();
}

class _PickStudentsScreenState extends State<_PickStudentsScreen> {
  final _picked = <int>{};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.all
        .where((s) => _q.isEmpty || s.fullName.toLowerCase().contains(_q.toLowerCase()))
        .toList()
      ..sort((a, b) => a.lastName.compareTo(b.lastName));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('pickStudentsFor', {'name': widget.className}))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(context.tr('pickStudentsHint')),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('search')),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) => CheckboxListTile(
              value: _picked.contains(list[i].id),
              onChanged: (v) => setState(() => v! ? _picked.add(list[i].id) : _picked.remove(list[i].id)),
              title: Text('${list[i].lastName} ${list[i].firstName}'),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, widget.all.where((s) => _picked.contains(s.id)).toList()),
                child: Text(context.tr('takeN', {'n': _picked.length})),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// Shared: choose school year + class target
// =====================================================================

class _TargetPicker extends StatelessWidget {
  const _TargetPicker({
    required this.yearId,
    required this.onYear,
    required this.classCtrl,
    this.showClass = true,
  });

  final String? yearId;
  final ValueChanged<String> onYear;
  final TextEditingController classCtrl;
  final bool showClass;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final years = store.yearsSorted;
    final classNames = yearId == null ? <String>[] : store.classesOf(yearId!).map((c) => c.name).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('${yearId}_${years.length}'),
            initialValue: yearId,
            decoration: InputDecoration(labelText: context.tr('schoolYear')),
            items: [for (final y in years) DropdownMenuItem(value: y.id, child: Text(y.name))],
            onChanged: (v) {
              if (v != null) onYear(v);
            },
          ),
        ),
        IconButton(
          tooltip: context.tr('newYear'),
          icon: const Icon(Icons.add),
          onPressed: () async {
            final n = await askText(context, title: context.tr('newYear'), initial: defaultYearName());
            if (n != null && n.isNotEmpty) onYear(store.addYear(n).id);
          },
        ),
      ]),
      if (showClass) ...[
        const SizedBox(height: 12),
        TextField(
          controller: classCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: context.tr('className'), hintText: '3B'),
        ),
        if (classNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final n in classNames) ActionChip(label: Text(n), onPressed: () => classCtrl.text = n),
          ]),
        ],
      ],
    ]);
  }
}

String? _defaultYearId(AppStore store) {
  final ys = store.yearsSorted;
  return ys.isEmpty ? null : ys.first.id;
}

// =====================================================================
// CSV / Excel
// =====================================================================

class _FileTab extends StatefulWidget {
  const _FileTab();
  @override
  State<_FileTab> createState() => _FileTabState();
}

class _FileTabState extends State<_FileTab> with AutomaticKeepAliveClientMixin {
  String? _yearId;
  final _className = TextEditingController();
  ImportParseResult? _parsed;
  String? _fileName;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yearId = _defaultYearId(context.read<AppStore>());
  }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xlsx'],
      withData: true,
    );
    final f = r?.files.single;
    if (f == null || f.bytes == null) return;
    try {
      final parsed = FileImporter.parse(f.name, f.bytes!);
      setState(() {
        _parsed = parsed;
        _fileName = f.name;
      });
    } catch (e) {
      if (mounted) toast(context, context.tr('fileError'));
    }
  }

  void _import() {
    final store = context.read<AppStore>();
    final p = _parsed!;
    var yearId = _yearId;
    yearId ??= store.addYear(defaultYearName()).id;
    final fallbackClass = _className.text.trim();
    var n = 0;
    final byClass = <String, String>{};
    for (final row in p.rows) {
      final cname = (row.className?.isNotEmpty ?? false) ? row.className! : fallbackClass;
      if (cname.isEmpty) continue;
      final cid = byClass[cname] ??= store.addClass(yearId, cname).id;
      store.upsertStudent(classId: cid, firstName: row.firstName, lastName: row.lastName, notify: false);
      n++;
    }
    store.commit();
    toast(context, context.tr('importedN', {'n': n}));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = _parsed;
    final classesInFile = p == null ? <String>{} : p.rows.map((r) => r.className).whereType<String>().toSet();
    final needsClass = p != null && !p.hasClassColumn;

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(context.tr('fileIntro')),
      const SizedBox(height: 16),
      _TargetPicker(
        yearId: _yearId,
        onYear: (id) => setState(() => _yearId = id),
        classCtrl: _className,
        showClass: needsClass,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _pick,
        icon: const Icon(Icons.upload_file),
        label: Text(_fileName ?? context.tr('chooseFile')),
      ),
      if (p != null) ...[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('foundN', {'n': p.rows.length}), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (classesInFile.isNotEmpty) Text('${context.tr('classes')}: ${classesInFile.join(', ')}'),
              const SizedBox(height: 8),
              for (final r in p.rows.take(5)) Text('• ${r.firstName} ${r.lastName}'),
              if (p.rows.length > 5) const Text('…'),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 16),
      ListenableBuilder(
        listenable: _className,
        builder: (ctx, _) => FilledButton(
          onPressed: p != null && p.rows.isNotEmpty && (!needsClass || _className.text.trim().isNotEmpty)
              ? _import
              : null,
          child: Text(context.tr('import')),
        ),
      ),
    ]);
  }
}

// =====================================================================
// Manual: paste a list of names
// =====================================================================

class _ManualTab extends StatefulWidget {
  const _ManualTab();
  @override
  State<_ManualTab> createState() => _ManualTabState();
}

class _ManualTabState extends State<_ManualTab> with AutomaticKeepAliveClientMixin {
  String? _yearId;
  final _className = TextEditingController();
  final _names = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _yearId = _defaultYearId(context.read<AppStore>());
  }

  void _import() {
    final store = context.read<AppStore>();
    final yearId = _yearId ?? store.addYear(defaultYearName()).id;
    final cls = store.addClass(yearId, _className.text.trim());
    var n = 0;
    for (final line in _names.text.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      String first, last;
      if (t.contains(',')) {
        // "Lastname, Firstname"
        final parts = t.split(',');
        last = parts[0].trim();
        first = parts.sublist(1).join(',').trim();
      } else {
        final cut = t.lastIndexOf(' ');
        first = cut > 0 ? t.substring(0, cut) : t;
        last = cut > 0 ? t.substring(cut + 1) : '';
      }
      store.upsertStudent(classId: cls.id, firstName: first, lastName: last, notify: false);
      n++;
    }
    store.commit();
    toast(context, context.tr('importedN', {'n': n}));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(context.tr('manualIntro')),
      const SizedBox(height: 16),
      _TargetPicker(yearId: _yearId, onYear: (id) => setState(() => _yearId = id), classCtrl: _className),
      const SizedBox(height: 12),
      TextField(
        controller: _names,
        minLines: 6,
        maxLines: 14,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: context.tr('namesOnePerLine'),
          hintText: 'Anna Berger\nMax Huber\nLeitner, Sophie',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 16),
      ListenableBuilder(
        listenable: Listenable.merge([_className, _names]),
        builder: (ctx, _) => FilledButton(
          onPressed: _className.text.trim().isEmpty || _names.text.trim().isEmpty ? null : _import,
          child: Text(context.tr('import')),
        ),
      ),
      const SizedBox(height: 12),
      Text(context.tr('manualPhotoHint'), style: TextStyle(color: Theme.of(context).colorScheme.outline)),
    ]);
  }
}
