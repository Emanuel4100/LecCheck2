import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoAlertDialog,
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoDialogAction,
        CupertinoTheme,
        CupertinoThemeData,
        showCupertinoDialog,
        showCupertinoModalPopup;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/local_date.dart';
import '../l10n/gen/app_localizations.dart';
import 'format.dart';
import 'widgets/common.dart';

/// How people interact with this platform, independent of window size: a
/// narrow desktop window still has a mouse and keyboard, an iPad has touch.
///
/// Reads [defaultTargetPlatform], so tests can switch platforms with
/// `debugDefaultTargetPlatformOverride`.
abstract final class AppIdiom {
  static bool get isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.macOS => true,
    _ => false,
  };

  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;

  /// iOS and macOS: Cupertino dialogs and pickers, ⌘ instead of Ctrl.
  static bool get isApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Phones and tablets: swipe gestures, long-press, bottom sheets.
  static bool get usesTouch => !isDesktop;
}

/// A bottom sheet on touch screens with a compact window, a dialog elsewhere
/// (desktop, tablets). [builder] content should not assume either; the
/// dialog adds the top spacing the sheet's drag handle would provide.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollControlled = false,
}) {
  if (AppIdiom.usesTouch && WindowSize.of(context) == WindowSize.compact) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: scrollControlled,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Builder(builder: builder),
        ),
      ),
    ),
  );
}

/// One button of [showChoiceDialog].
class DialogChoice<T> {
  const DialogChoice(
    this.label,
    this.value, {
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final T value;

  /// The emphasized (default) action.
  final bool primary;
  final bool destructive;
}

/// A short question with a few answers: a Cupertino alert on iPhone and
/// macOS, a Material dialog elsewhere. Returns the chosen value, or null when
/// dismissed.
Future<T?> showChoiceDialog<T>(
  BuildContext context, {
  required String title,
  String? body,
  required List<DialogChoice<T>> choices,
}) {
  if (AppIdiom.isApple) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          for (final c in choices)
            CupertinoDialogAction(
              isDefaultAction: c.primary,
              isDestructiveAction: c.destructive,
              onPressed: () => Navigator.pop(context, c.value),
              child: Text(c.label),
            ),
        ],
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: body == null ? null : Text(body),
        actions: [
          for (final c in choices)
            if (c.primary)
              FilledButton(
                style: c.destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      )
                    : null,
                onPressed: () => Navigator.pop(context, c.value),
                child: Text(c.label),
              )
            else
              TextButton(
                style: c.destructive
                    ? TextButton.styleFrom(foregroundColor: scheme.error)
                    : null,
                onPressed: () => Navigator.pop(context, c.value),
                child: Text(c.label),
              ),
        ],
      );
    },
  );
}

/// Cancel / [confirmLabel] question. True only when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  bool destructive = false,
}) async =>
    await showChoiceDialog<bool>(
      context,
      title: title,
      body: body,
      choices: [
        DialogChoice(AppLocalizations.of(context).cancel, false),
        DialogChoice(
          confirmLabel,
          true,
          primary: true,
          destructive: destructive,
        ),
      ],
    ) ??
    false;

final _firstDay = DateTime(2020);
final _lastDay = DateTime(2040, 12, 31);

/// Date picker: an iOS wheel on iPhone, the Material calendar elsewhere.
Future<LocalDate?> pickDate(BuildContext context, LocalDate initial) async {
  final start = DateTime(initial.year, initial.month, initial.day);
  if (AppIdiom.isIOS) {
    final picked = await _cupertinoPicker(
      context,
      mode: CupertinoDatePickerMode.date,
      initial: start,
    );
    return picked == null ? null : LocalDate.fromDateTime(picked);
  }
  final picked = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: _firstDay,
    lastDate: _lastDay,
  );
  return picked == null ? null : LocalDate.fromDateTime(picked);
}

/// Time picker returning minutes after midnight. An iOS wheel on iPhone; on
/// desktop the Material picker opens in keyboard-entry mode ("14:30").
Future<int?> pickTime(BuildContext context, int initialMinutes) async {
  final fmt = Fmt.of(context);
  if (AppIdiom.isIOS) {
    final picked = await _cupertinoPicker(
      context,
      mode: CupertinoDatePickerMode.time,
      initial: DateTime(2000, 1, 1, initialMinutes ~/ 60, initialMinutes % 60),
      use24h: fmt.use24h,
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: initialMinutes ~/ 60,
      minute: initialMinutes % 60,
    ),
    initialEntryMode: AppIdiom.isDesktop
        ? TimePickerEntryMode.input
        : TimePickerEntryMode.dial,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: fmt.use24h),
      child: child!,
    ),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}

Future<DateTime?> _cupertinoPicker(
  BuildContext context, {
  required CupertinoDatePickerMode mode,
  required DateTime initial,
  bool use24h = false,
}) {
  final l = AppLocalizations.of(context);
  var value = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (popup) {
      final theme = Theme.of(context);
      return Container(
        height: 320,
        color: theme.colorScheme.surfaceContainerHigh,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(popup),
                    child: Text(l.cancel),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(popup, value),
                    child: Text(l.done),
                  ),
                ],
              ),
              Expanded(
                // Follow the app's light/dark choice, not the system's.
                child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: theme.brightness),
                  child: CupertinoDatePicker(
                    mode: mode,
                    initialDateTime: initial,
                    minimumDate: _firstDay,
                    maximumDate: _lastDay,
                    use24hFormat: use24h,
                    onDateTimeChanged: (v) => value = v,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Rebuilds with `true` while a mouse pointer is over [builder]'s child.
class HoverBuilder extends StatefulWidget {
  const HoverBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, _hovered),
  );
}
