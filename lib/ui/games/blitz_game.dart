import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import 'game_common.dart';

/// 60 seconds: does the name fit the face? Yes / no, as fast as you can.
/// Correct answers in a row build a combo multiplier.
class BlitzGame extends StatefulWidget {
  const BlitzGame({super.key, required this.classId, required this.pool});
  final String classId;
  final List<Student> pool;

  @override
  State<BlitzGame> createState() => _BlitzGameState();
}

class _BlitzGameState extends State<BlitzGame> {
  static const seconds = 60;
  late final AppStore store = context.read<AppStore>();
  final _rnd = Random();
  Timer? _timer;
  int _left = seconds;
  bool _started = false;

  late Student _face;
  late Student _name;
  int _score = 0, _combo = 0, _answered = 0, _correct = 0, _xp = 0;
  /// Result of the answer being shown (✓ or ✕), null while waiting for one.
  bool? _feedback;
  final List<Student> _missed = [];

  @override
  void initState() {
    super.initState();
    _next();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _started = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _finish();
      }
    });
  }

  void _next() {
    _face = store.pickForPractice(widget.pool, 1).first;
    _name = _rnd.nextBool() ? _face : store.distractors(_face, widget.pool, 1).first;
  }

  Future<void> _answer(bool saysMatch) async {
    if (!_started || _left <= 0 || _feedback != null) return;
    final ok = saysMatch == (_face.id == _name.id);
    hapticFor(ok);
    _answered++;
    if (ok) {
      _correct++;
      _combo++;
      _score += 1 * _multiplier;
    } else {
      _combo = 0;
      _missed.add(_face);
    }
    _xp += store.recordAnswer(_face, ok, points: 5);
    // Show ✓ / ✕ on the photo for a moment, then the next student.
    setState(() => _feedback = ok);
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted || _left <= 0) return;
    setState(() {
      _feedback = null;
      _next();
    });
  }

  int get _multiplier => _combo >= 10 ? 3 : _combo >= 5 ? 2 : 1;

  void _finish() {
    finishGame(
      context,
      classId: widget.classId,
      pool: widget.pool,
      result: GameResult(
        modeTitleKey: 'gBlitz',
        correct: _correct,
        total: _answered,
        xp: _xp,
        missed: _missed,
        headline: context.tr('nPoints', {'n': _score}),
        score: _score,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GameShell(
      modeKey: 'gBlitz',
      progress: _left / seconds,
      trailing: Text('${_left}s', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(context.tr('nPoints', {'n': _score}), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (_multiplier > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.gold, borderRadius: BorderRadius.circular(12)),
                child: Text('×$_multiplier', style: const TextStyle(fontWeight: FontWeight.w900, color: Brand.ink)),
              ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Stack(alignment: Alignment.center, children: [
              GamePhoto(_face, maxSize: 340),
              if (_feedback != null)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (ctx, v, child) => Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _feedback! ? AppTheme.good : AppTheme.bad,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                    ),
                    child: Icon(_feedback! ? Icons.check_rounded : Icons.close_rounded,
                        color: Colors.white, size: 72),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(_name.fullName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          if (!_started)
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _start, child: Text(context.tr('start'))),
            )
          else
            Row(children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.bad, minimumSize: const Size(0, 72)),
                  onPressed: () => _answer(false),
                  child: const Icon(Icons.close_rounded, size: 40),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.good, minimumSize: const Size(0, 72)),
                  onPressed: () => _answer(true),
                  child: const Icon(Icons.check_rounded, size: 40),
                ),
              ),
            ]),
          if (!_started)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(context.tr('blitzHelp'), textAlign: TextAlign.center, style: TextStyle(color: scheme.outline)),
            ),
        ]),
      ),
    );
  }
}
