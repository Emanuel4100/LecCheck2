import 'package:material_ui/material_ui.dart';

import '../../domain/recording_match.dart';
import '../../l10n/gen/app_localizations.dart';

/// Which group's recordings are the user's: a chip per group (with its
/// room), the suggestion or current group selected, and Save. Used by the
/// course page's question and Change, and by Find in Panopto.
class GroupChoice extends StatefulWidget {
  const GroupChoice({
    super.key,
    required this.options,
    required this.onSave,
    this.selected,
    this.hint,
    this.busy = false,
    this.allowNone = false,
  });

  final List<GroupOption> options;

  /// Preselected: the suggestion, or the group chosen now.
  final String? selected;

  /// Why [selected] is suggested, shown while it stays selected.
  final GroupHint? hint;
  final bool busy;

  /// Offers "No group" (saved as `''`: asked again after the next look).
  final bool allowNone;
  final ValueChanged<String> onSave;

  @override
  State<GroupChoice> createState() => _GroupChoiceState();
}

class _GroupChoiceState extends State<GroupChoice> {
  late String? _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final hint = switch (widget.hint) {
      GroupHint.links => l.panoptoHintLinks,
      GroupHint.room => l.panoptoHintRoom,
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in widget.options)
              ChoiceChip(
                label: Text(
                  [
                    l.panoptoGroupOption(o.group),
                    if (o.room != null) o.room!,
                  ].join(' · '),
                ),
                selected: _selected == o.group,
                onSelected: (_) => setState(() => _selected = o.group),
              ),
            if (widget.allowNone)
              ChoiceChip(
                label: Text(l.panoptoGroupNone),
                selected: _selected == '',
                onSelected: (_) => setState(() => _selected = ''),
              ),
          ],
        ),
        if (hint != null && _selected == widget.selected) ...[
          const SizedBox(height: 8),
          Text(hint, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: _selected == null || widget.busy
                ? null
                : () => widget.onSave(_selected!),
            child: Text(l.save),
          ),
        ),
      ],
    );
  }
}
