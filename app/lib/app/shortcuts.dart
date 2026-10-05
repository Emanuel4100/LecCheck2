import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/gen/app_localizations.dart';
import 'adaptive.dart';

/// Ctrl+[key] on Linux and Windows, ⌘+[key] on Apple platforms.
SingleActivator primaryKey(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(
      key,
      control: !AppIdiom.isApple,
      meta: AppIdiom.isApple,
      shift: shift,
    );

/// True while a text field has focus: single-key shortcuts stay quiet so
/// typing "t" in a note doesn't jump to this week.
bool get isTyping {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorStateOfType<EditableTextState>() != null;
}

/// [action] that does nothing while the user is typing.
VoidCallback unlessTyping(VoidCallback action) => () {
  if (!isTyping) action();
};

/// Keyboard shortcuts for one pushed page: [bindings] plus Esc to go back
/// (which still runs the page's PopScope, e.g. "discard changes?"). Takes
/// focus when shown so the keys work without clicking first, unless
/// [autofocus] is off because a field inside should get it instead.
class PageShortcuts extends StatelessWidget {
  const PageShortcuts({
    super.key,
    this.bindings = const {},
    this.autofocus = true,
    required this.child,
  });

  final Map<ShortcutActivator, VoidCallback> bindings;
  final bool autofocus;
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.maybePop(context),
      ...bindings,
    },
    child: Focus(autofocus: autofocus, child: child),
  );
}

/// Lists every keyboard shortcut (F1, Ctrl+/ or Settings).
Future<void> showShortcutsHelp(BuildContext context) {
  final l = AppLocalizations.of(context);
  final mod = AppIdiom.isApple ? '⌘' : 'Ctrl';
  final rows = <(String, String)>[
    ('$mod+1 … 4', l.shortcutTabs),
    ('$mod+N', l.addCourse),
    ('$mod+Shift+N', l.addOneTimeSession),
    ('$mod+F', l.shortcutSearch),
    ('$mod+R  ·  F5', l.syncNow),
    ('$mod+,', l.settings),
    ('←  →  ·  PgUp  PgDn', l.shortcutWeeks),
    ('T  ·  Home', l.goToToday),
    ('$mod+=  $mod+−  $mod+0', l.shortcutZoom),
    ('1 … 5', l.shortcutMark),
    ('$mod+S', l.save),
    ('Esc', l.shortcutBack),
    ('F1  ·  $mod+/', l.shortcutHelp),
  ];
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text(l.keyboardShortcuts),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (keys, action) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            action,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            keys,
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.close),
          ),
        ],
      );
    },
  );
}
