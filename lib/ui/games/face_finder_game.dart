import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../l10n/strings.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets/student_photo.dart';
import 'game_common.dart';

/// The reverse direction: a name, four faces.
class FaceFinderGame extends StatefulWidget {
  const FaceFinderGame({super.key, required this.classId, required this.pool});
  final String classId;
  final List<Student> pool;

  @override
  State<FaceFinderGame> createState() => _FaceFinderGameState();
}

class _FaceFinderGameState extends State<FaceFinderGame> {
  static const rounds = 10;
  late final AppStore store = context.read<AppStore>();
  late final List<Student> _targets;
  int _i = 0, _correct = 0, _xp = 0;
  late List<Student> _options;
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

  Student get _target => _targets[_i];

  void _setup() {
    _options = [_target, ...store.distractors(_target, widget.pool, 3)]..shuffle(Random());
    _picked = null;
  }

  Future<void> _answer(Student s) async {
    if (_picked != null) return;
    final ok = s.id == _target.id;
    setState(() => _picked = s.id);
    hapticFor(ok);
    if (ok) _correct++;
    if (!ok) _missed.add(_target);
    _xp += store.recordAnswer(_target, ok);
    await Future.delayed(Duration(milliseconds: ok ? 700 : 1400));
    if (!mounted) return;
    if (_i == rounds - 1) {
      finishGame(context,
          classId: widget.classId,
          pool: widget.pool,
          result: GameResult(modeTitleKey: 'gFinder', correct: _correct, total: rounds, xp: _xp, missed: _missed));
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
    return GameShell(
      modeKey: 'gFinder',
      progress: _i / rounds,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(context.tr('whoIs'), style: TextStyle(color: scheme.outline, fontSize: 16)),
          const SizedBox(height: 4),
          Text(_target.fullName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final o in _options)
                      GestureDetector(
                        onTap: () => _answer(o),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              width: 5,
                              color: _picked == null
                                  ? Colors.transparent
                                  : o.id == _target.id
                                      ? AppTheme.good
                                      : o.id == _picked
                                          ? AppTheme.bad
                                          : Colors.transparent,
                            ),
                          ),
                          child: Stack(fit: StackFit.expand, children: [
                            StudentPhoto(o, radius: 15, hideInitials: true),
                            // After answering, show who the other faces are – free extra learning.
                            if (_picked != null)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                                  ),
                                  child: Text(o.firstName,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                ),
                              ),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
