import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';

// Game colours: the brand palette plus a few neighbours, all of similar
// strength so no game looks more important than another.
import 'blitz_game.dart';
import 'flashcards_game.dart';
import 'face_finder_game.dart';
import 'memory_game.dart';
import 'millionenshow_game.dart';
import 'reveal_game.dart';
import 'type_game.dart';

typedef GameBuilder = Widget Function(String classId, List<Student> pool);

class GameMode {
  const GameMode({
    required this.key,
    required this.icon,
    required this.color,
    required this.minStudents,
    required this.builder,
  });

  /// Translation key prefix: `key` = title, `keySub` = subtitle.
  final String key;
  final IconData icon;
  final Color color;
  final int minStudents;
  final GameBuilder builder;
}

final gameModes = <GameMode>[
  GameMode(
    key: 'gMillion',
    icon: Icons.emoji_events_rounded,
    color: const Color(0xFFD98E00),
    minStudents: 4,
    builder: (c, p) => MillionenshowGame(classId: c, pool: p),
  ),
  GameMode(
    key: 'gMemory',
    icon: Icons.grid_view_rounded,
    color: const Color(0xFF0E9F74),
    minStudents: 3,
    builder: (c, p) => MemoryGame(classId: c, pool: p),
  ),
  GameMode(
    key: 'gFinder',
    icon: Icons.person_search_rounded,
    color: const Color(0xFF7C2AD6),
    minStudents: 4,
    builder: (c, p) => FaceFinderGame(classId: c, pool: p),
  ),
  GameMode(
    key: 'gBlitz',
    icon: Icons.bolt_rounded,
    color: const Color(0xFFE5484D),
    minStudents: 2,
    builder: (c, p) => BlitzGame(classId: c, pool: p),
  ),
  GameMode(
    key: 'gReveal',
    icon: Icons.blur_on_rounded,
    color: const Color(0xFF5B5FE0),
    minStudents: 4,
    builder: (c, p) => RevealGame(classId: c, pool: p),
  ),
  GameMode(
    key: 'gType',
    icon: Icons.keyboard_rounded,
    color: const Color(0xFF2A8BD6),
    minStudents: 1,
    builder: (c, p) => TypeGame(classId: c, pool: p),
  ),
  GameMode(
    key: 'gCards',
    icon: Icons.style_rounded,
    color: const Color(0xFFC2409A),
    minStudents: 1,
    builder: (c, p) => FlashcardsGame(classId: c, pool: p),
  ),
];

void showGamePicker(BuildContext context, String classId) {
  final store = context.read<AppStore>();
  final pool = store.studentsOf(classId).where((s) => s.hasPhoto).toList();

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text(ctx.tr('chooseGame'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final m in gameModes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ModeTile(
                mode: m,
                enabled: pool.length >= m.minStudents,
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => m.builder(classId, pool)));
                },
              ),
            ),
          if (pool.length < 4)
            Text(ctx.tr('needPhotos', {'n': pool.length}),
                style: TextStyle(color: Theme.of(ctx).colorScheme.outline)),
        ]),
      ),
    ),
  );
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.mode, required this.enabled, required this.onTap});
  final GameMode mode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mode.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(mode.icon, color: mode.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr(mode.key), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(context.tr('${mode.key}Sub'),
                        style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
          ),
        ),
      );
}

GameMode modeByKey(String key) => gameModes.firstWhere((m) => m.key == key);
