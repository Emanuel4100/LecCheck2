import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/recordings_controller.dart';
import '../../core/recordings/panopto_api.dart';
import '../../core/recordings/panopto_pairing.dart';
import '../../l10n/gen/app_localizations.dart';
import 'panopto_section.dart';

/// "Use it here": asks the device that set Panopto up for the vault key,
/// shows the code to compare, and uses the key once it's allowed.
Future<void> usePanoptoHere(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final device = ref.read(panoptoProvider).device ?? '';
  final done = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _PairDialog(device: device),
  );
  if (done == true) {
    messenger.showSnackBar(SnackBar(content: Text(l.panoptoPairDone)));
  }
}

class _PairDialog extends ConsumerStatefulWidget {
  const _PairDialog({required this.device});

  final String device;

  @override
  ConsumerState<_PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends ConsumerState<_PairDialog> {
  PairingRequest? _request;
  PairingStep _step = const PairingWaiting();
  String? _error;
  Timer? _timer;
  bool _polling = false;

  PanoptoController get _controller => ref.read(panoptoProvider.notifier);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _step = const PairingWaiting();
    });
    try {
      _request = await _controller.requestPairing();
    } on PanoptoException catch (e) {
      if (mounted) setState(() => _error = e.code);
      return;
    }
    if (!mounted) {
      unawaited(_request?.cancel());
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    unawaited(_poll());
  }

  Future<void> _poll() async {
    final request = _request;
    if (request == null || _polling || !mounted) return;
    _polling = true;
    try {
      final step = await _controller.pollPairing(request);
      if (!mounted) return;
      if (step is PairingDone) {
        _timer?.cancel();
        Navigator.pop(context, true);
        return;
      }
      if (step is PairingDenied || step is PairingGone) {
        _timer?.cancel();
        _request = null;
      }
      setState(() {
        _step = step;
        _error = null;
      });
    } on PanoptoException catch (e) {
      // Keep asking: the connection may come back.
      if (mounted) setState(() => _error = e.code);
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_request?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ended = _step is PairingDenied || _step is PairingGone;
    final text = switch (_step) {
      PairingCode() => l.panoptoPairCheck(widget.device),
      PairingDenied() => l.panoptoPairDenied(widget.device),
      PairingGone() => l.panoptoPairExpired,
      _ => l.panoptoPairWaiting(widget.device),
    };
    return AlertDialog(
      title: Text(l.panoptoPairTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (_step case PairingCode(:final code)) ...[
            const SizedBox(height: 16),
            Center(child: PairingCodeText(code)),
          ],
          if (_step is PairingWaiting && _error == null) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error case final code?) ...[
            const SizedBox(height: 12),
            Text(
              panoptoErrorText(code, l),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        if (ended || (_request == null && _error != null))
          TextButton(onPressed: _start, child: Text(l.retry)),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(ended ? l.close : l.cancel),
        ),
      ],
    );
  }
}

/// A pairing code, "123 456", the same way round in both languages.
class PairingCodeText extends StatelessWidget {
  const PairingCodeText(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      '${code.substring(0, 3)} ${code.substring(3)}',
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 4,
      ),
    ),
  );
}

/// On a device holding the key: allow [prompt]'s device after comparing
/// codes.
Future<void> showAllowPairing(
  BuildContext context,
  PanoptoController controller,
  PairingPrompt prompt,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final allow = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(l.panoptoAllowTitle(prompt.device)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.panoptoAllowBody(prompt.device)),
          const SizedBox(height: 16),
          Center(child: PairingCodeText(prompt.code)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.panoptoDeny),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.panoptoAllow),
        ),
      ],
    ),
  );
  if (allow != true) {
    await controller.deny(prompt);
    return;
  }
  try {
    await controller.allow(prompt);
    messenger.showSnackBar(
      SnackBar(content: Text(l.panoptoAllowed(prompt.device))),
    );
  } on PanoptoException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(panoptoErrorText(e.code, l))),
    );
  }
}
