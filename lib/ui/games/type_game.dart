import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import 'game_common.dart';

/// Recall instead of recognition: type the first name.
/// Small typos are forgiven.
class TypeGame extends StatefulWidget {
  const TypeGame({super.key, required this.classId, required this.pool});
  final String classId;
  final List<Student> pool;

  @override
  State<TypeGame> createState() => _TypeGameState();
}

class _TypeGameState extends State<TypeGame> {
  static const rounds = 10;
  late final AppStore store = context.read<AppStore>();
  late final List<Student> _targets;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  int _i = 0, _correct = 0, _xp = 0;
  bool? _result; // null = not answered yet
  final List<Student> _missed = [];

  @override
  void initState() {
    super.initState();
    _targets = [];
    while (_targets.length < rounds) {
      _targets.addAll(store.pickForPractice(widget.pool, min(widget.pool.length, rounds - _targets.length)));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Student get _target => _targets[_i];

  static String _norm(String s) {
    const map = {'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss', 'é': 'e', 'è': 'e', 'á': 'a', 'à': 'a', 'ç': 'c', 'ć': 'c', 'č': 'c', 'š': 's', 'ž': 'z', 'ñ': 'n', 'ı': 'i', 'ş': 's', 'ğ': 'g'};
    final lower = s.toLowerCase().trim();
    return lower.split('').map((c) => map[c] ?? c).join().replaceAll(RegExp(r'[^a-z]'), '');
  }

  static int _distance(String a, String b) {
    final dp = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        ].reduce(min);
      }
    }
    return dp[a.length][b.length];
  }

  bool _isRight(String input) {
    final guess = _norm(input);
    if (guess.isEmpty) return false;
    // Accept the first given name alone, or the full first-name field.
    final candidates = {_norm(_target.firstName), _norm(_target.firstName.split(' ').first)};
    return candidates.any((c) => _distance(guess, c) <= (c.length >= 5 ? 1 : 0));
  }

  void _submit({bool giveUp = false}) {
    if (_result != null) return;
    final ok = !giveUp && _isRight(_ctrl.text);
    hapticFor(ok);
    if (ok) _correct++;
    if (!ok) _missed.add(_target);
    _xp += store.recordAnswer(_target, ok, points: 15);
    setState(() => _result = ok);
  }

  void _next() {
    if (_i == rounds - 1) {
      finishGame(context,
          classId: widget.classId,
          pool: widget.pool,
          result: GameResult(modeTitleKey: 'gType', correct: _correct, total: rounds, xp: _xp, missed: _missed));
      return;
    }
    setState(() {
      _i++;
      _result = null;
      _ctrl.clear();
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final answered = _result != null;
    return GameShell(
      modeKey: 'gType',
      progress: _i / rounds,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        GamePhoto(_target, maxSize: 260),
        const SizedBox(height: 20),
        TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          enabled: !answered,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.words,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: InputDecoration(hintText: context.tr('typeFirstName')),
          onSubmitted: (_) => answered ? _next() : _submit(),
        ),
        const SizedBox(height: 14),
        if (answered) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_result! ? Icons.check_circle : Icons.cancel,
                color: _result! ? AppTheme.good : AppTheme.bad, size: 28),
            const SizedBox(width: 8),
            Text(_target.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          FilledButton(onPressed: _next, child: Text(context.tr('next'))),
        ] else ...[
          FilledButton(onPressed: _submit, child: Text(context.tr('check'))),
          const SizedBox(height: 8),
          TextButton(onPressed: () => _submit(giveUp: true), child: Text(context.tr('dontKnow'))),
        ],
      ]),
    );
  }
}
