import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../services/file_import.dart';
import '../../services/untis_credentials.dart';
import '../../services/untis_mobile_api.dart';
import '../../services/webuntis_service.dart';
import '../dialogs.dart';
import 'home_screen.dart' show defaultYearName;
import 'qr_scan_screen.dart';

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

/// connecting: automatic sign-in with the stored login
/// start:      first time – scan the QR code (or use a password)
/// password:   username + password form
enum _Step { connecting, start, password, select, running, done }

class _WebUntisTab extends StatefulWidget {
  const _WebUntisTab();
  @override
  State<_WebUntisTab> createState() => _WebUntisTabState();
}

class _WebUntisTabState extends State<_WebUntisTab> with AutomaticKeepAliveClientMixin {
  final _server = TextEditingController();
  final _school = TextEditingController();
  final _user = TextEditingController();
  final _pw = TextEditingController();
  final _filter = TextEditingController();
  bool _busy = false;
  String? _error;

  _Step _step = _Step.connecting;
  WebUntisClient? _client;
  /// Stored accounts, the signed-in one first.
  List<UntisCredentials> _accounts = [];
  UntisCredentials? _active;

  /// True while adding a further account (first-time page with a way back).
  bool _adding = false;
  List<UntisYear> _years = [];
  UntisYear? _year;
  List<UntisClass> _classes = [];
  /// `c<classId>` for a class, `g<key>` for a lesson shared by classes.
  final Set<String> _selected = {};
  TeachingGroups? _groups;
  bool _groupsLoading = false;
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
    // A pasted WebUntis link fills in server and school.
    _server.addListener(() {
      if (!_server.text.contains('://')) return;
      final parsed = WebUntisClient.parseLoginUrl(_server.text);
      if (parsed == null) return;
      if (parsed.school.isNotEmpty) _school.text = parsed.school;
      _server.text = parsed.server;
    });
    _autoLogin();
  }

  @override
  void dispose() {
    _client?.logout();
    for (final c in [_server, _school, _user, _pw, _filter]) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ sign-in

  Future<void> _autoLogin() async {
    _accounts = await UntisCredentials.loadAll();
    if (!mounted) return;
    if (_accounts.isEmpty) {
      setState(() => _step = _Step.start);
      return;
    }
    final ok = await _signIn(_accounts.first);
    if (!ok && mounted) {
      setState(() {
        _step = _Step.start;
        _error = context.tr('autoLoginFailed');
      });
    }
  }

  /// Signs in with another stored account and loads its classes.
  Future<void> _switchTo(UntisCredentials creds) async {
    setState(() {
      _step = _Step.connecting;
      _error = null;
    });
    if (!await _signIn(creds) && mounted) {
      // Stay on the account that worked; the error explains what failed.
      if (_active != null && await _signIn(_active!)) {
        if (mounted) toast(context, _error ?? context.tr('connectError'));
      } else if (mounted) {
        setState(() => _step = _Step.start);
      }
    }
  }

  /// Opens the first-time page to connect a further account.
  void _addAccount() => setState(() {
        _adding = true;
        _error = null;
        _step = _Step.start;
      });

  void _cancelAdd() => setState(() {
        _adding = false;
        _error = null;
        _step = _client != null ? _Step.select : _Step.start;
      });

  Future<void> _scanQr() async {
    final creds = await Navigator.push<UntisCredentials>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (creds == null || !mounted) return;
    final previous = _step;
    setState(() {
      _step = _Step.connecting;
      _error = null;
    });
    if (!await _signIn(creds) && mounted) setState(() => _step = previous);
  }

  Future<void> _passwordLogin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await _signIn(UntisCredentials(
      server: WebUntisClient.normalizeHost(_server.text),
      school: _school.text.trim(),
      user: _user.text.trim(),
      password: _pw.text,
    ));
    if (mounted) setState(() => _busy = false);
  }

  /// Signs in, stores the login for next time and opens the class list.
  /// Returns false (and sets [_error]) when it fails.
  Future<bool> _signIn(UntisCredentials creds) async {
    final store = context.read<AppStore>();
    try {
      final client = WebUntisClient(server: creds.server, school: creds.school);
      if (creds.secret != null) {
        await client.loginWithSecret(creds.user, creds.secret!);
      } else {
        await client.login(creds.user, creds.password ?? '');
      }
      // Keep only the app key when the server hands it out, not the password.
      final secret = await client.appSecret();
      var saved = creds.copyWith(server: client.host, secret: secret);
      if (saved.schoolName == null) {
        final name = await WebUntisClient.schoolDisplayName(client.school);
        if (name != null) saved = saved.copyWith(schoolName: name);
      }
      await saved.saveAndActivate();
      store.setSchoolName(AppStore.schoolKey(client.host, client.school), saved.label);
      store.updateSettings((s) {
        s.untisServer = client.host;
        s.untisSchool = client.school;
        s.untisUser = creds.user;
      });

      final years = await client.schoolYears();
      final current = await client.currentSchoolYear();
      _client?.logout();
      _client = client;
      _active = saved;
      _accounts = await UntisCredentials.loadAll();
      _adding = false;
      _years = years;
      _year = years.where((y) => y.id == current?.id).firstOrNull ?? (years.isNotEmpty ? years.first : null);
      await _loadClasses();
      if (mounted) setState(() => _step = _Step.select);
      return true;
    } on WebUntisException catch (e) {
      if (mounted) {
        setState(() => _error = e.isBadCredentials ? context.tr('badLogin') : '${context.tr('connectError')} ($e)');
      }
    } catch (e) {
      if (mounted) setState(() => _error = '${context.tr('connectError')} ($e)');
    }
    return false;
  }

  /// Removes the signed-in account; switches to the next stored one if any.
  Future<void> _signOut() async {
    final remaining = await (_active?.remove() ?? Future.value(<UntisCredentials>[]));
    _client?.logout();
    if (!mounted) return;
    setState(() {
      _client = null;
      _active = null;
      _accounts = remaining;
      _pw.clear();
      _error = null;
      _step = _Step.start;
    });
    if (remaining.isNotEmpty) await _switchTo(remaining.first);
  }

  Future<void> _loadClasses() async {
    if (_year == null) return;
    _classes = await _client!.classes(_year!.id);
    _selected.clear();
    _loadGroups();
  }

  /// Finds the classes the teacher teaches (and their students) through the
  /// mobile interface, then preselects them.
  Future<void> _loadGroups() async {
    final year = _year;
    if (year == null) return;
    setState(() {
      _groupsLoading = true;
      _groups = null;
    });
    TeachingGroups? groups;
    try {
      groups = await _client!.mobile.teachingGroups(year.sampleDate);
    } catch (e) {
      debugPrint('Teaching groups unavailable: $e');
    }
    if (!mounted || _year != year) return;
    setState(() {
      _groupsLoading = false;
      _groups = groups;
      if (groups != null && _selected.isEmpty) {
        for (final c in _classes) {
          if (groups.forClass(c.id) != null) _selected.add('c${c.id}');
        }
        for (final g in groups.mixed) {
          _selected.add('g${g.classIds.join('+')}');
        }
      }
    });
  }

  Future<void> _runImport() async {
    final store = context.read<AppStore>();
    final client = _client!;
    final year = _year!;
    // Classes first (in list order), then lessons shared by several classes.
    final chosen = <({String name, UntisClass? cls, TeachingGroup? group})>[
      for (final c in _classes)
        if (_selected.contains('c${c.id}')) (name: c.name, cls: c, group: _groups?.forClass(c.id)),
      for (final g in _groups?.mixed ?? const <TeachingGroup>[])
        if (_selected.contains('g${g.classIds.join('+')}')) (name: g.name, cls: null, group: g),
    ];
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

      List<UntisStudent> roster = [];
      final cls = uc.cls;
      if (cls == null) {
        // Lesson shared by several classes: its students come from the lessons.
        roster = uc.group!.students;
      } else {
        try {
          // Full class list – WebUntis only allows this for your own class.
          roster = await client.classStudents(cls.id, year.sampleDate);
        } on ClassRosterUnavailable {
          if (uc.group != null && uc.group!.students.isNotEmpty) {
            // Students from the lessons you teach in this class.
            roster = uc.group!.students;
          } else {
            // Last resort: let the teacher pick the students of this class.
            try {
              _allStudentsCache ??= await client.allStudents();
            } catch (_) {
              _allStudentsCache = [];
            }
            if (!mounted) return;
            if (_allStudentsCache!.isEmpty) {
              toast(context, context.tr('noRosterAccess'));
            } else {
              roster = await Navigator.push<List<UntisStudent>>(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _PickStudentsScreen(className: cls.name, all: _allStudentsCache!)),
                  ) ??
                  [];
            }
          }
        }
      }

      final localClass = store.addClass(
        localYear.id,
        uc.name,
        untisId: uc.cls?.id,
        school: AppStore.schoolKey(client.host, client.school),
      );
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
      _Step.connecting => _buildConnecting(),
      _Step.start => _buildStart(),
      _Step.password => _buildPassword(),
      _Step.select => _buildSelect(),
      _Step.running => _buildRunning(),
      _Step.done => _buildDone(),
    };
  }

  Widget _buildConnecting() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.tr('connecting')),
        ]),
      );

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(_error!,
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        );

  /// First time: one big button to scan the QR code from WebUntis.
  Widget _buildStart() {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.outline);
    return ListView(padding: const EdgeInsets.fromLTRB(24, 32, 24, 24), children: [
      if (_adding)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _cancelAdd,
            icon: const Icon(Icons.arrow_back),
            label: Text(context.tr('backToAccount', {'name': _active?.label ?? ''})),
          ),
        ),
      Icon(Icons.qr_code_2_rounded, size: 88, color: scheme.primary),
      const SizedBox(height: 16),
      Text(context.tr('qrTitle'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 20),
      for (final (i, step) in [context.tr('qrStep1'), context.tr('qrStep2'), context.tr('qrStep3')].indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: scheme.primaryContainer,
              child: Text('${i + 1}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onPrimaryContainer)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(step)),
          ]),
        ),
      const SizedBox(height: 20),
      _errorText(),
      FilledButton.icon(
        onPressed: _scanQr,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text(context.tr('scanQr')),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() {
          _error = null;
          _step = _Step.password;
        }),
        child: Text(context.tr('usePassword')),
      ),
      const SizedBox(height: 16),
      Text(context.tr('privacyNote'), textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
      const SizedBox(height: 8),
      Text(context.tr('untisNote'), textAlign: TextAlign.center, style: muted.copyWith(fontSize: 12)),
    ]);
  }

  /// Alternative: username and password.
  Widget _buildPassword() => ListView(padding: const EdgeInsets.all(24), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _error = null;
              _step = _Step.start;
            }),
            icon: const Icon(Icons.arrow_back),
            label: Text(context.tr('scanQrInstead')),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _server,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.tr('server'), hintText: 'xyz.webuntis.com'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _school,
          autocorrect: false,
          decoration: InputDecoration(labelText: context.tr('school')),
        ),
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
          onSubmitted: (_) => _passwordLogin(),
        ),
        const SizedBox(height: 20),
        _errorText(),
        FilledButton(
          onPressed: _busy ? null : _passwordLogin,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(context.tr('signIn')),
        ),
        const SizedBox(height: 12),
        Text(context.tr('serverHint'), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
      ]);

  Widget _buildSelect() {
    final q = _filter.text.toLowerCase();
    bool match(String a, [String b = '']) => q.isEmpty || a.toLowerCase().contains(q) || b.toLowerCase().contains(q);
    final groups = _groups;
    final mine = _classes.where((c) => groups?.forClass(c.id) != null && match(c.name, c.longName)).toList();
    final mixed = (groups?.mixed ?? const <TeachingGroup>[]).where((g) => match(g.name)).toList();
    final others = _classes.where((c) => groups?.forClass(c.id) == null && match(c.name, c.longName)).toList();
    final scheme = Theme.of(context).colorScheme;

    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
        );
    Widget tile(String key, String title, String? subtitle) => CheckboxListTile(
          value: _selected.contains(key),
          onChanged: (v) => setState(() => v! ? _selected.add(key) : _selected.remove(key)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: subtitle == null ? null : Text(subtitle),
        );

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
        child: Row(children: [
          Icon(Icons.verified_user_outlined, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: _AccountSwitcher(active: _active, accounts: _accounts, onSelected: _switchTo)),
          IconButton(
            tooltip: context.tr('addAccount'),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: _addAccount,
          ),
          TextButton(onPressed: _signOut, child: Text(context.tr('signOut'))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
        child: ListView(children: [
          if (_groupsLoading)
            ListTile(
              leading: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
              title: Text(context.tr('findingMyClasses')),
            ),
          if (mine.isNotEmpty || mixed.isNotEmpty) ...[
            header(context.tr('myClasses')),
            for (final c in mine)
              tile('c${c.id}', c.name,
                  context.tr('taughtStudents', {'n': groups!.forClass(c.id)!.students.length})),
            for (final g in mixed)
              tile('g${g.classIds.join('+')}', g.name, context.tr('sharedLesson', {'n': g.students.length})),
          ],
          if (others.isNotEmpty) ...[
            if (mine.isNotEmpty || mixed.isNotEmpty) header(context.tr('otherClasses')),
            for (final c in others)
              tile('c${c.id}', c.name, c.longName.isNotEmpty && c.longName != c.name ? c.longName : null),
          ],
        ]),
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
                onPressed: _selected.isEmpty || _groupsLoading ? null : _runImport,
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

/// "alice · HTL Rankweil ▾" – a menu of the stored accounts when there are
/// several, plain text otherwise.
class _AccountSwitcher extends StatelessWidget {
  const _AccountSwitcher({required this.active, required this.accounts, required this.onSelected});
  final UntisCredentials? active;
  final List<UntisCredentials> accounts;
  final ValueChanged<UntisCredentials> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = active;
    if (a == null) return const SizedBox.shrink();
    final text = Text('${a.user} · ${a.label}',
        overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.outline));
    if (accounts.length < 2) return text;
    return PopupMenuButton<UntisCredentials>(
      tooltip: context.tr('switchAccount'),
      onSelected: (c) {
        if (c.id != a.id) onSelected(c);
      },
      itemBuilder: (ctx) => [
        for (final c in accounts)
          PopupMenuItem(
            value: c,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(c.id == a.id ? Icons.check_rounded : Icons.school_outlined,
                  color: c.id == a.id ? scheme.primary : null),
              title: Text(c.label),
              subtitle: Text(c.user),
            ),
          ),
      ],
      child: Row(children: [
        Flexible(
          child: Text('${a.user} · ${a.label}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
        ),
        Icon(Icons.arrow_drop_down, color: scheme.onSurface),
      ]),
    );
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
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'xlsx'],
    );
    if (f == null) return;
    try {
      final parsed = FileImporter.parse(f.name, await f.readAsBytes());
      if (!mounted) return;
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
