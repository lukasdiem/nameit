import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/student_photo.dart';
import 'game_common.dart';

/// Classic memory: find the photo card and the matching name card.
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key, required this.classId, required this.pool});
  final String classId;
  final List<Student> pool;

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _Card {
  _Card(this.student, this.isPhoto);
  final Student student;
  final bool isPhoto;
  bool open = false;
  bool matched = false;
}

class _MemoryGameState extends State<MemoryGame> {
  late final AppStore store = context.read<AppStore>();
  late final List<_Card> _cards;
  late final int _pairs;
  final List<_Card> _open = [];
  int _moves = 0, _found = 0, _xp = 0;
  bool _locked = false;
  final Set<String> _mistakeStudents = {};

  @override
  void initState() {
    super.initState();
    final picked = store.pickForPractice(widget.pool, min(6, widget.pool.length));
    _pairs = picked.length;
    _cards = [for (final s in picked) ...[_Card(s, true), _Card(s, false)]]..shuffle(Random());
  }

  Future<void> _tap(_Card c) async {
    if (_locked || c.open || c.matched) return;
    setState(() {
      c.open = true;
      _open.add(c);
    });
    if (_open.length < 2) return;

    _moves++;
    final a = _open[0], b = _open[1];
    final match = a.student.id == b.student.id;
    if (match) {
      hapticFor(true);
      await Future.delayed(const Duration(milliseconds: 350));
      setState(() {
        a.matched = b.matched = true;
        _open.clear();
        _found++;
      });
      // A pair found at first try counts as "known".
      _xp += store.recordAnswer(a.student, !_mistakeStudents.contains(a.student.id), points: 8);
      if (_found == _pairs) _finish();
    } else {
      // A photo next to the wrong name is a real recognition mistake.
      if (a.isPhoto != b.isPhoto) {
        _mistakeStudents.add((a.isPhoto ? a : b).student.id);
      }
      _locked = true;
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        a.open = b.open = false;
        _open.clear();
        _locked = false;
      });
    }
  }

  Future<void> _finish() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final perfect = _pairs; // minimum possible moves
    final ratio = perfect / _moves;
    finishGame(
      context,
      classId: widget.classId,
      pool: widget.pool,
      result: GameResult(
        modeTitleKey: 'gMemory',
        correct: _pairs - _mistakeStudents.length,
        total: _pairs,
        xp: _xp,
        missed: widget.pool.where((s) => _mistakeStudents.contains(s.id)).toList(),
        headline: context.tr('nMoves', {'n': _moves}),
        score: _moves,
        starsOverride: ratio >= 0.6 ? 3 : ratio >= 0.4 ? 2 : 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameShell(
      modeKey: 'gMemory',
      progress: _found / _pairs,
      trailing: Text(context.tr('nMoves', {'n': _moves}), style: const TextStyle(fontWeight: FontWeight.w700)),
      child: LayoutBuilder(builder: (ctx, box) {
        const cols = 3;
        final rows = (_cards.length / cols).ceil();
        const gap = 10.0;
        final w = (box.maxWidth - 32 - gap * (cols - 1)) / cols;
        final h = (box.maxHeight - 32 - gap * (rows - 1)) / rows;
        final size = min(w, h);
        return Center(
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [
              for (final c in _cards)
                SizedBox(width: size, height: size, child: _MemoryTile(card: c, onTap: () => _tap(c))),
            ],
          ),
        );
      }),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.card, required this.onTap});
  final _Card card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showFace = card.open || card.matched;

    Widget face;
    if (!showFace) {
      face = Container(
        key: const ValueKey('back'),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(Icons.question_mark_rounded, color: scheme.onPrimary.withValues(alpha: 0.5), size: 32),
      );
    } else if (card.isPhoto) {
      face = StudentPhoto(card.student, key: const ValueKey('photo'), radius: 14, hideInitials: true);
    } else {
      face = Container(
        key: const ValueKey('name'),
        padding: const EdgeInsets.all(6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '${card.student.firstName}\n${card.student.lastName}',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: scheme.onSecondaryContainer),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: card.matched ? 0.35 : 1,
        child: Stack(fit: StackFit.expand, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: face,
          ),
          if (card.matched)
            const Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.check_circle, color: AppTheme.good, size: 22),
              ),
            ),
        ]),
      ),
    );
  }
}
