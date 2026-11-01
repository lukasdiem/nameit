import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import 'game_common.dart';

/// The photo hides behind 16 tiles that disappear one by one.
/// The earlier you answer, the more points.
class RevealGame extends StatefulWidget {
  const RevealGame({super.key, required this.classId, required this.pool});
  final String classId;
  final List<Student> pool;

  @override
  State<RevealGame> createState() => _RevealGameState();
}

class _RevealGameState extends State<RevealGame> {
  static const rounds = 8;
  static const tiles = 16;
  late final AppStore store = context.read<AppStore>();
  final _rnd = Random();

  late final List<Student> _targets;
  int _i = 0, _correct = 0, _xp = 0, _points = 0;
  late List<Student> _options;
  late List<int> _order; // tile removal order
  int _revealed = 0;
  Timer? _timer;
  String? _picked;
  final List<Student> _missed = [];

  @override
  void initState() {
    super.initState();
    _targets = [];
    while (_targets.length < rounds) {
      _targets.addAll(store.pickForPractice(widget.pool, min(widget.pool.length, rounds - _targets.length)));
    }
    _setup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Student get _target => _targets[_i];

  void _setup() {
    _options = [_target, ...store.distractors(_target, widget.pool, 3)]..shuffle(_rnd);
    _order = List.generate(tiles, (i) => i)..shuffle(_rnd);
    _revealed = 1;
    _picked = null;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 650), (t) {
      if (_revealed >= tiles) {
        t.cancel();
      } else {
        setState(() => _revealed++);
      }
    });
  }

  Future<void> _answer(Student s) async {
    if (_picked != null) return;
    _timer?.cancel();
    final ok = s.id == _target.id;
    final earned = ok ? max(1, (tiles - _revealed) * 10) : 0;
    setState(() {
      _picked = s.id;
      _revealed = tiles; // show the full photo
    });
    hapticFor(ok);
    if (ok) {
      _correct++;
      _points += earned;
    } else {
      _missed.add(_target);
    }
    _xp += store.recordAnswer(_target, ok, points: 10 + earned ~/ 15);
    await Future.delayed(Duration(milliseconds: ok ? 900 : 1600));
    if (!mounted) return;
    if (_i == rounds - 1) {
      finishGame(context,
          classId: widget.classId,
          pool: widget.pool,
          result: GameResult(
            modeTitleKey: 'gReveal',
            correct: _correct,
            total: rounds,
            xp: _xp,
            missed: _missed,
            headline: context.tr('nPoints', {'n': _points}),
            score: _points,
          ));
    } else {
      setState(() {
        _i++;
        _setup();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hidden = _order.skip(_revealed).toSet();
    final potential = max(1, (tiles - _revealed) * 10);

    return GameShell(
      modeKey: 'gReveal',
      progress: _i / rounds,
      trailing: Text(context.tr('nPoints', {'n': _points}), style: const TextStyle(fontWeight: FontWeight.w700)),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(fit: StackFit.expand, children: [
                  GamePhoto(_target),
                  GridView.count(
                    crossAxisCount: 4,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var t = 0; t < tiles; t++)
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: hidden.contains(t) ? 1 : 0,
                          child: Container(
                            margin: const EdgeInsets.all(0.5),
                            color: Color.lerp(scheme.primary, scheme.tertiary, t / tiles),
                          ),
                        ),
                    ],
                  ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _picked == null ? '+$potential' : '',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary, fontSize: 18),
        ),
        const SizedBox(height: 8),
        for (final o in _options) ...[
          AnswerButton(
            label: o.fullName,
            state: _picked == null
                ? AnswerState.idle
                : o.id == _target.id
                    ? AnswerState.correct
                    : o.id == _picked
                        ? AnswerState.wrong
                        : AnswerState.dimmed,
            onTap: () => _answer(o),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}
