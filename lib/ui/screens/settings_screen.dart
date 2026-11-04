import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../services/webuntis_service.dart';
import '../dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _template = TextEditingController(text: context.read<AppStore>().settings.photoUrlTemplate);

  @override
  void dispose() {
    _template.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final muted = TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
        _Header(context.tr('language')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'system', label: Text(context.tr('system'))),
              const ButtonSegment(value: 'de', label: Text('Deutsch')),
              const ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {s.locale},
            onSelectionChanged: (v) => store.updateSettings((x) => x.locale = v.first),
          ),
        ),
        _Header('WebUntis'),
        ListTile(
          title: Text(s.untisServer.isEmpty ? '–' : s.untisServer),
          subtitle: Text('${context.tr('school')}: ${s.untisSchool.isEmpty ? '–' : s.untisSchool}   '
              '${context.tr('username')}: ${s.untisUser.isEmpty ? '–' : s.untisUser}'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _template,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: context.tr('photoTemplate'),
                hintText: WebUntisClient.defaultPhotoTemplate,
              ),
              onChanged: (v) => store.updateSettings((x) => x.photoUrlTemplate = v.trim()),
            ),
            const SizedBox(height: 6),
            Text(context.tr('photoTemplateHelp'), style: muted),
          ]),
        ),
        _Header(context.tr('data')),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: Text(context.tr('resetProgress')),
          onTap: () async {
            final ok = await confirm(context, title: context.tr('resetProgressQ'), action: context.tr('reset'));
            if (ok) store.resetProgress();
          },
        ),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
          title: Text(context.tr('deleteAll')),
          onTap: () async {
            final ok = await confirm(context, title: context.tr('deleteAllQ'), message: context.tr('deleteAllMsg'));
            if (ok) await store.deleteEverything();
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(context.tr('privacyNote'), style: muted),
        ),
        // Version name from pubspec.yaml, build number from the CI run.
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (ctx, snap) => snap.hasData
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    ctx.tr('versionLine', {'v': snap.data!.version, 'b': snap.data!.buildNumber}),
                    style: muted,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text,
            style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
      );
}
