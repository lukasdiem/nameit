import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_store.dart';

/// One badge. Title and description come from the string table:
/// `b_<id>` and `b_<id>Desc`.
class BadgeDef {
  const BadgeDef(this.id, this.icon, this.color, this.test);

  final String id;
  final IconData icon;
  final Color color;

  /// Checked after every game ([r] = that game) and when stats open (r = null).
  final bool Function(AppStore s, GameResult? r) test;

  String get titleKey => 'b_$id';
  String get descKey => 'b_${id}Desc';
}

bool _mode(GameResult? r, String key) => r != null && r.modeTitleKey == key;

final badges = <BadgeDef>[
  BadgeDef('firstGame', Icons.rocket_launch_rounded, const Color(0xFF7C2AD6), (s, r) => s.gamesTotal >= 1),
  BadgeDef('streak3', Icons.local_fire_department_rounded, const Color(0xFFF08C00), (s, r) => s.bestStreak >= 3),
  BadgeDef('streak7', Icons.local_fire_department_rounded, const Color(0xFFE5484D), (s, r) => s.bestStreak >= 7),
  BadgeDef('streak30', Icons.whatshot_rounded, const Color(0xFFB4232A), (s, r) => s.bestStreak >= 30),
  BadgeDef('perfect', Icons.verified_rounded, const Color(0xFF0E7A5A),
      (s, r) => r != null && r.total >= 8 && r.correct == r.total),
  BadgeDef('millionaire', Icons.emoji_events_rounded, const Color(0xFFE0A526),
      (s, r) => _mode(r, 'gMillion') && (r!.score ?? 0) >= 1000000),
  BadgeDef('memory', Icons.grid_view_rounded, const Color(0xFF00897B),
      (s, r) => _mode(r, 'gMemory') && r!.score != null && r.score! <= r.total + 2),
  BadgeDef('blitz', Icons.bolt_rounded, const Color(0xFFF4511E), (s, r) => _mode(r, 'gBlitz') && (r!.score ?? 0) >= 30),
  BadgeDef('typist', Icons.keyboard_rounded, const Color(0xFF1E88E5),
      (s, r) => _mode(r, 'gType') && r!.total > 0 && r.correct == r.total),
  BadgeDef('names25', Icons.groups_rounded, const Color(0xFF5A1BA3), (s, r) => s.masteredCount >= 25),
  BadgeDef('names100', Icons.diversity_3_rounded, const Color(0xFF3A0E73), (s, r) => s.masteredCount >= 100),
  BadgeDef('wholeClass', Icons.school_rounded, const Color(0xFF2E7D32), (s, r) => s.hasMasteredClass),
  BadgeDef('allModes', Icons.auto_awesome_rounded, const Color(0xFF8E24AA), (s, r) => s.modesPlayed >= 7),
  BadgeDef('early', Icons.wb_twilight_rounded, const Color(0xFFFF8F00),
      (s, r) => r != null && DateTime.now().hour >= 5 && DateTime.now().hour < 7),
  BadgeDef('night', Icons.nightlight_round, const Color(0xFF3949AB),
      (s, r) => r != null && (DateTime.now().hour >= 22 || DateTime.now().hour < 5)),
];

BadgeDef badgeById(String id) => badges.firstWhere((b) => b.id == id);
