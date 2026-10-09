import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/adaptive.dart';
import '../../app/diagnostics.dart';
import '../../core/dev/dev_log.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/notifications/android_device.dart';
import '../../core/report/report_sender.dart';
import '../../core/update/update_service.dart';
import '../../l10n/gen/app_localizations.dart';

final reportSenderProvider = Provider<ReportSender>((ref) => ReportSender());

/// The error the previous session ended with ([DevLog.takeLastError]),
/// until Today's prompt is answered.
class LastErrorController extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> load() async {
    final error = await DevLog.takeLastError();
    if (ref.mounted && error != null && ReportSender.available) state = error;
  }

  void dismiss() => state = null;
}

final lastErrorProvider = NotifierProvider<LastErrorController, String?>(
  LastErrorController.new,
);

/// The report as it's sent (and shown before sending).
@visibleForTesting
String reportPreview(Map<String, Object?> report) => [
  for (final MapEntry(:key, :value) in report.entries)
    if (key != 'diagnostics' && '$value'.isNotEmpty) '$key: $value',
  if ('${report['diagnostics'] ?? ''}'.isNotEmpty) ...[
    '',
    '${report['diagnostics']}',
  ],
].join('\n');

/// Settings → About → Report a problem: what happened, optionally an email
/// and diagnostics, shown in full before sending. Reports become issues in
/// a private GitHub repository, through the sync server; without a
/// connection they wait on the device.
class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key, this.lastError});

  /// From Today's prompt: the error the previous session ended with.
  final String? lastError;

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _description = TextEditingController();
  final _contact = TextEditingController();
  bool _includeDiagnostics = true;
  bool _sending = false;

  /// What doesn't change while the page is open: app, device, diagnostics.
  Future<(Map<String, Object?>, String)>? _fixed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fixed ??= (_about(), collectDiagnostics(context, ref)).wait;
  }

  @override
  void dispose() {
    _description.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<Map<String, Object?>> _about() async {
    final locale = Localizations.localeOf(context).languageCode;
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } on Object {
      info = null;
    }
    final android = AppIdiom.isAndroid ? await AndroidDevice.info() : null;
    final now = DateTime.now();
    return {
      'appVersion': info?.version ?? '',
      'build': info == null ? null : installedBuild(info.buildNumber),
      'platform': defaultTargetPlatform.name,
      'os': android != null
          ? 'Android ${android['release']} (SDK ${android['sdk']})'
          : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      'device': android == null
          ? ''
          : '${android['maker']} ${android['model']}',
      'locale': locale,
      'tz': '${now.timeZoneName} (UTC${utcOffset(now.timeZoneOffset)})',
    };
  }

  /// The report with what's typed now.
  Map<String, Object?> _report((Map<String, Object?>, String) fixed) {
    final lastError = widget.lastError;
    return {
      ...fixed.$1,
      'description': [
        _description.text.trim(),
        if (lastError != null) 'Last error: $lastError',
      ].join('\n\n'),
      'diagnostics': _includeDiagnostics ? fixed.$2 : '',
      'contact': _contact.text.trim(),
    };
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final result = await ref
        .read(reportSenderProvider)
        .send(_report(await _fixed!));
    if (!mounted) return;
    setState(() => _sending = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (result) {
          ReportResult.sent => l.reportSent,
          ReportResult.queued => l.reportSaved,
          ReportResult.refused => l.reportRefused,
        }),
      ),
    );
    if (result != ReportResult.refused) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final available = ReportSender.available;
    return Scaffold(
      appBar: AppBar(title: Text(l.reportProblem)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              if (!available)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    l.reportUnavailable,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              TextField(
                controller: _description,
                minLines: 4,
                maxLines: 12,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.reportDescription,
                  hintText: l.reportDescriptionHint,
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contact,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l.reportContact,
                  prefixIcon: const Icon(LecIcons.account),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.reportIncludeDiagnostics),
                subtitle: Text(l.reportIncludeDiagnosticsSubtitle),
                value: _includeDiagnostics,
                onChanged: (on) => setState(() => _includeDiagnostics = on),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.reportPreview),
                children: [
                  FutureBuilder(
                    future: _fixed,
                    builder: (context, snapshot) => SelectableText(
                      snapshot.hasData
                          ? reportPreview(_report(snapshot.data!))
                          : '…',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: available && !_sending && _description.text.trim().isNotEmpty
            ? _send
            : null,
        icon: const Icon(LecIcons.check),
        label: Text(l.reportSend),
      ),
    );
  }
}

/// "Something went wrong last time", on Today after an uncaught error.
class LastErrorCard extends ConsumerWidget {
  const LastErrorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(lastErrorProvider);
    if (error == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final controller = ref.read(lastErrorProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(LecIcons.warning),
                title: Text(l.lastErrorTitle),
                subtitle: Text(l.lastErrorSubtitle),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: controller.dismiss,
                      child: Text(l.notNow),
                    ),
                    FilledButton(
                      onPressed: () {
                        controller.dismiss();
                        context.push(
                          '/report?error=${Uri.encodeQueryComponent(error)}',
                        );
                      },
                      child: Text(l.reportProblem),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
