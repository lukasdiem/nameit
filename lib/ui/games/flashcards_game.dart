import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import 'game_common.dart';

/// Calm learning mode. Flip the card, be honest with yourself.
/// Cards you didn't know come back until you know them.
class FlashcardsGame extends StatefulWidget {
  const FlashcardsGame({super.key, required this.classId, required this.pool});
  final String classId;
  final List<Student> pool;

  @override
  State<FlashcardsGame> createState() => _FlashcardsGameState();
}

class _FlashcardsGameState extends State<FlashcardsGame> with SingleTickerProviderStateMixin {
  late final AppStore store = context.read<AppStore>();
  late final List<Student> _queue;
  late final int _total;
  final Set<String> _firstTry = {};
  final Set<String> _seen = {};
  final List<Student> _missed = [];
  int _xp = 0, _done = 0;
  bool _faceFirst = true;

  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

  @override
  void initState() {
    super.initState();
    _queue = store.pickForPractice(widget.pool, min(20, widget.pool.length));
    _total = _queue.length;
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  bool get _flipped => _flip.value > 0.5;

  void _rate(bool knew) {
    final s = _queue.removeAt(0);
    final first = !_seen.contains(s.id);
    _seen.add(s.id);
    if (knew) {
      if (first) _firstTry.add(s.id);
      _done++;
    } else {
      // Put it back a few cards later.
      _queue.insert(min(3, _queue.length), s);
      if (first) _missed.add(s);
    }
    // Only the first rating of a card counts for the long-term level.
    if (first) _xp += store.recordAnswer(s, knew, points: 5);
    _flip.value = 0;

    if (_queue.isEmpty) {
      finishGame(context,
          classId: widget.classId,
          pool: widget.pool,
          result: GameResult(
            modeTitleKey: 'gCards',
            correct: _firstTry.length,
            total: _total,
            xp: _xp,
            missed: _missed,
          ));
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _queue.first;

    Widget photoSide() => GamePhoto(s, maxSize: 320);
    Widget nameSide() => Container(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(24)),
          child: AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(s.fullName,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: scheme.onSecondaryContainer)),
              ),
            ),
          ),
        );

    return GameShell(
      modeKey: 'gCards',
      progress: _done / _total,
      trailing: IconButton(
        tooltip: context.tr('switchDirection'),
        icon: const Icon(Icons.swap_horiz_rounded),
        onPressed: () => setState(() {
          _faceFirst = !_faceFirst;
          _flip.value = 0;
        }),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(context.tr('cardsLeft', {'n': _queue.length}), style: TextStyle(color: scheme.outline)),
          const SizedBox(height: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _flipped ? _flip.reverse() : _flip.forward(),
              child: AnimatedBuilder(
                animation: _flip,
                builder: (ctx, _) {
                  final angle = _flip.value * pi;
                  final showBack = _flip.value > 0.5;
                  final front = _faceFirst ? photoSide() : nameSide();
                  final back = _faceFirst ? nameSide() : photoSide();
                  return Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(angle),
                      child: showBack
                          ? Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()..rotateY(pi),
                              child: back,
                            )
                          : front,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _flip,
            builder: (ctx, _) => _flipped
                ? Row(children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.bad),
                        onPressed: () => _rate(false),
                        child: Text(context.tr('notYet')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.good),
                        onPressed: () => _rate(true),
                        child: Text(context.tr('knewIt')),
                      ),
                    ),
                  ])
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(onPressed: _flip.forward, child: Text(context.tr('tapToFlip'))),
                  ),
          ),
        ]),
      ),
    );
  }
}
