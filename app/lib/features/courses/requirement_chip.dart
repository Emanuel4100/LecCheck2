import 'package:material_ui/material_ui.dart';

import '../../app/labels.dart';
import '../../app/theme/colors.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/requirements.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';

String requirementText(RequirementProgress p, AppLocalizations l) =>
    switch (p.state) {
      RequirementState.failed => l.requirementFailed,
      RequirementState.met => l.requirementMet,
      RequirementState.atRisk => l.requirementAtRisk,
      _ => l.canMissMore(p.slack),
    };

/// Status-colored pill: "Can miss 2 more", "Must attend all remaining", …
class RequirementChip extends StatelessWidget {
  const RequirementChip({
    super.key,
    required this.progress,
    this.showType = false,
  });

  final RequirementProgress progress;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = StatusColors.of(context);
    final tones = switch (progress.state) {
      RequirementState.onTrack ||
      RequirementState.met => colors[AttendanceStatus.attended],
      RequirementState.warning => colors[AttendanceStatus.skipped],
      RequirementState.atRisk ||
      RequirementState.failed => colors[AttendanceStatus.missed],
    };
    final type = progress.requirement.type;
    final text = [
      if (showType) type == null ? l.allTypes : type.label(l),
      requirementText(progress, l),
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tones.container,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LecIcons.target, size: 14, color: tones.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: tones.onContainer),
            ),
          ),
        ],
      ),
    );
  }
}
