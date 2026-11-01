import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import 'game_common.dart';

/// Photo + four names. One wrong answer ends the run, like the TV show.
/// Two safety levels, three jokers.
class MillionenshowGame extends StatefulWidget {
  const MillionenshowGame({super.key, required this.classId, required this.pool});
  final String classId;
  final List<Student> pool;

  @override
  State<MillionenshowGame> createState() => _MillionenshowGameState();
}

class _MillionenshowGameState extends State<MillionenshowGame> {
  static const ladder = [50, 100, 200, 300, 500, 1000, 2000, 4000, 8000, 15000, 30000, 75000, 150000, 300000, 1000000];
  static const safety = {4, 9}; // indexes of € 500 and € 15.000

  late final AppStore store = context.read<AppStore>();
  final _rnd = Random();
  late List<Student> _questions;
  int _q = 0;
  late List<Student> _options;
  final Set<String> _removed = {};
  String? _picked;
  int _xp = 0;
  final List<Student> _missed = [];

  bool _joker5050 = true, _jokerAudience = true, _jokerHint = true;
  Map<String, int>? _audience;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _questions = [];
    while (_questions.length < ladder.length) {
      _questions.addAll(store.pickForPractice(widget.pool, min(widget.pool.length, ladder.length - _questions.length)));
    }
    _setupQuestion();
  }

  Student get _target => _questions[_q];

  void _setupQuestion() {
    _options = [_target, ...store.distractors(_target, widget.pool, 3)]..shuffle(_rnd);
    _removed.clear();
    _picked = null;
    _audience = null;
    _showHint = false;
  }

  String _money(int v) {
    final s = v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '€ $s';
  }

  int get _securedAmount {
    var amount = 0;
    for (final i in safety) {
      if (_q > i) amount = max(amount, ladder[i]);
    }
    return amount;
  }

  Future<void> _answer(Student s) async {
    final correct = s.id == _target.id;
    setState(() => _picked = s.id);
    hapticFor(correct);
    _xp += store.recordAnswer(_target, correct, points: 10 + _q * 2);
    if (!correct) _missed.add(_target);
    await Future.delayed(Duration(milliseconds: correct ? 900 : 1600));
    if (!mounted) return;

    if (!correct) {
      _end(_securedAmount, _q);
    } else if (_q == ladder.length - 1) {
      _end(ladder.last, ladder.length);
    } else {
      setState(() {
        _q++;
        _setupQuestion();
      });
    }
  }

  void _walkAway() => _end(_q == 0 ? 0 : ladder[_q - 1], _q);

  void _end(int amount, int correctCount) {
    finishGame(
      context,
      classId: widget.classId,
      pool: widget.pool,
      result: GameResult(
        modeTitleKey: 'gMillion',
        correct: correctCount,
        total: ladder.length,
        xp: _xp,
        missed: _missed,
        headline: _money(amount),
        score: amount,
      ),
    );
  }

  void _use5050() {
    final wrong = _options.where((o) => o.id != _target.id).toList()..shuffle(_rnd);
    setState(() {
      _joker5050 = false;
      _removed.addAll(wrong.take(2).map((s) => s.id));
    });
  }

  void _useAudience() {
    // The "audience" knows weak students less well.
    final confidence = 0.35 + 0.1 * _target.level + _rnd.nextDouble() * 0.15;
    final live = _options.where((o) => !_removed.contains(o.id)).toList();
    final rest = 1 - confidence;
    final weights = [for (final _ in live) _rnd.nextDouble() + 0.1];
    final wSum = weights.fold<double>(0, (a, b) => a + b) - weights[live.indexOf(_target)];
    final result = <String, int>{};
    for (var i = 0; i < live.length; i++) {
      final o = live[i];
      result[o.id] = o.id == _target.id ? (confidence * 100).round() : (rest * weights[i] / wSum * 100).round();
    }
    setState(() {
      _jokerAudience = false;
      _audience = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const letters = ['A', 'B', 'C', 'D'];

    return GameShell(
      modeKey: 'gMillion',
      progress: _q / ladder.length,
      trailing: TextButton(onPressed: _picked == null ? _walkAway : null, child: Text(context.tr('walkAway'))),
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: safety.contains(_q) ? scheme.tertiaryContainer : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${context.tr('question')} ${_q + 1} · ${_money(ladder[_q])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        GamePhoto(_target, maxSize: 280),
        if (_showHint)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              context.tr('hintInitials', {'i': _target.initials}),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 18),
        for (var i = 0; i < _options.length; i++) ...[
          Builder(builder: (ctx) {
            final o = _options[i];
            final removed = _removed.contains(o.id);
            AnswerState state = AnswerState.idle;
            if (removed) state = AnswerState.dimmed;
            if (_picked != null) {
              if (o.id == _target.id) {
                state = AnswerState.correct;
              } else if (o.id == _picked) {
                state = AnswerState.wrong;
              } else {
                state = AnswerState.dimmed;
              }
            }
            final pct = _audience?[o.id];
            return AnswerButton(
              prefix: letters[i],
              label: removed ? '' : (pct != null ? '${o.fullName}   $pct%' : o.fullName),
              state: state,
              onTap: () => _answer(o),
            );
          }),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Joker(label: '50:50', enabled: _joker5050 && _picked == null, onTap: _use5050),
          _Joker(icon: Icons.groups_rounded, enabled: _jokerAudience && _picked == null, onTap: _useAudience),
          _Joker(
            icon: Icons.lightbulb_outline_rounded,
            enabled: _jokerHint && _picked == null,
            onTap: () => setState(() {
              _jokerHint = false;
              _showHint = true;
            }),
          ),
        ]),
      ]),
    );
  }
}

class _Joker extends StatelessWidget {
  const _Joker({this.label, this.icon, required this.enabled, required this.onTap});
  final String? label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Opacity(
        opacity: enabled ? 1 : 0.3,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onTap : null,
          child: Container(
            width: 72,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              shape: StadiumBorder(side: BorderSide(color: scheme.primary, width: 2)),
            ),
            child: label != null
                ? Text(label!, style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary))
                : Icon(icon, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}
