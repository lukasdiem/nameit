import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/badges.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/student_photo.dart';
import '../screens/stats_screen.dart' show BadgeIcon;
import 'game_modes.dart';

/// Scaffold for all games: close button, title, optional progress bar.
class GameShell extends StatelessWidget {
  const GameShell({
    super.key,
    required this.modeKey,
    required this.child,
    this.progress,
    this.trailing,
  });

  final String modeKey;
  final Widget child;
  final double? progress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final mode = modeByKey(modeKey);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          Icon(mode.icon, color: mode.color),
          const SizedBox(width: 8),
          // Shrinks a long name next to buttons like "Walk away" instead of cutting it off.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(context.tr(modeKey)),
            ),
          ),
        ]),
        actions: [if (trailing != null) Padding(padding: const EdgeInsets.only(right: 16), child: trailing)],
        bottom: progress == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(6),
                child: LinearProgressIndicator(value: progress, minHeight: 6, color: mode.color),
              ),
      ),
      body: SafeArea(child: child),
    );
  }
}

enum AnswerState { idle, correct, wrong, dimmed }

/// Big tappable answer button that turns green/red.
class AnswerButton extends StatelessWidget {
  const AnswerButton({super.key, required this.label, required this.state, this.onTap, this.prefix});
  final String label;
  final String? prefix;
  final AnswerState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (state) {
      AnswerState.correct => (AppTheme.good, Colors.white),
      AnswerState.wrong => (AppTheme.bad, Colors.white),
      AnswerState.dimmed => (scheme.surfaceContainerHighest.withValues(alpha: 0.4), scheme.outline),
      AnswerState.idle => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: state == AnswerState.idle ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              if (prefix != null) ...[
                Text(prefix!, style: TextStyle(fontWeight: FontWeight.w800, color: fg.withValues(alpha: 0.6))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: fg),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              if (state == AnswerState.correct) const Icon(Icons.check_circle, color: Colors.white),
              if (state == AnswerState.wrong) const Icon(Icons.cancel, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}

void hapticFor(bool correct) {
  if (correct) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.heavyImpact();
  }
}

/// Replaces the game with the result screen.
void finishGame(
  BuildContext context, {
  required GameResult result,
  required String classId,
  required List<Student> pool,
}) {
  final newBadges = context.read<AppStore>().recordGame(result);
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => ResultScreen(result: result, classId: classId, pool: pool, newBadges: newBadges),
    ),
  );
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.classId,
    required this.pool,
    this.newBadges = const [],
  });
  final GameResult result;
  final String classId;
  final List<Student> pool;
  final List<BadgeDef> newBadges;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mode = modeByKey(result.modeTitleKey);
    final missed = {for (final s in result.missed) s.id: s}.values.toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 400 + i * 250),
                curve: Curves.elasticOut,
                builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
                child: Icon(
                  Icons.star_rounded,
                  size: i == 1 ? 84 : 64,
                  color: i < result.stars ? AppTheme.gold : scheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(result.stars == 3
                ? 'resPerfect'
                : result.stars == 2
                    ? 'resGreat'
                    : result.stars == 1
                        ? 'resGood'
                        : 'resKeepGoing'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (result.headline != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(result.headline!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: mode.color)),
            ),
          const SizedBox(height: 20),
          Row(children: [
            _Big(label: context.tr('correct'), value: '${result.correct}/${result.total}'),
            _Big(label: 'XP', value: '+${result.xp}'),
          ]),
          for (final b in newBadges)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
                child: Card(
                  color: b.color.withValues(alpha: 0.10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      BadgeIcon(badge: b, unlocked: true, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(context.tr('newBadge'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: b.color)),
                          Text(context.tr(b.titleKey),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          Text(context.tr(b.descKey), style: TextStyle(color: scheme.outline, fontSize: 13)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(context.tr('practiceThese'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            for (final s in missed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  StudentPhoto(s, size: 52, radius: 12),
                  const SizedBox(width: 12),
                  Text(s.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => mode.builder(classId, pool)),
            ),
            icon: const Icon(Icons.replay),
            label: Text(context.tr('playAgain')),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('backToClass'))),
        ]),
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(children: [
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            ]),
          ),
        ),
      );
}

/// Big square photo used by most games.
class GamePhoto extends StatelessWidget {
  const GamePhoto(this.student, {super.key, this.maxSize = 320});
  final Student student;
  final double maxSize;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxSize, maxHeight: maxSize),
          child: AspectRatio(aspectRatio: 1, child: StudentPhoto(student, radius: 24, hideInitials: true)),
        ),
      );
}
