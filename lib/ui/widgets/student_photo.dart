import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';

/// Shows the student's photo, or a coloured initials tile when there is none.
class StudentPhoto extends StatelessWidget {
  const StudentPhoto(this.student, {super.key, this.size, this.radius = 16, this.hideInitials = false});

  final Student student;
  final double? size;
  final double radius;

  /// In games the initials would give the answer away.
  final bool hideInitials;

  @override
  Widget build(BuildContext context) {
    final file = context.read<AppStore>().photoOf(student);
    final scheme = Theme.of(context).colorScheme;
    final fallbackColor = HSLColor.fromAHSL(1, (student.id.hashCode.abs() % 360).toDouble(), 0.35, 0.75).toColor();

    Widget child;
    if (file != null && file.existsSync()) {
      child = Image.file(file, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      child = Container(
        color: fallbackColor,
        alignment: Alignment.center,
        child: hideInitials
            ? Icon(Icons.person, size: (size ?? 80) * 0.5, color: scheme.onSurface.withValues(alpha: 0.5))
            : FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(student.initials,
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Colors.black54)),
                ),
              ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

/// Five small dots showing a student's level.
class LevelDots extends StatelessWidget {
  const LevelDots(this.level, {super.key});
  final int level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        Student.maxLevel,
        (i) => Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < level ? scheme.primary : scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
