import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/recordings_controller.dart';
import '../../app/widgets/common.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/recordings/panopto_api.dart';
import '../../core/recordings/panopto_connection.dart';
import '../../domain/local_date.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_actions.dart';

/// What a [PanoptoException] code means for the user.
String panoptoErrorText(String code, AppLocalizations l) => switch (code) {
  'client' => l.panoptoErrorClient,
  'denied' => l.panoptoErrorDenied,
  'reconnect' => l.panoptoErrorReconnect,
  'network' => l.panoptoErrorNetwork,
  _ => l.panoptoErrorOther(code),
};

/// A small "Experimental" label.
class ExperimentalBadge extends StatelessWidget {
  const ExperimentalBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          AppLocalizations.of(context).panoptoExperimental,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}

/// Settings → Panopto recordings: setting up, and this device's connection.
class PanoptoSection extends ConsumerWidget {
  const PanoptoSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final view = ref.watch(panoptoProvider);
    final controller = ref.read(panoptoProvider.notifier);
    final found = ref.watch(foundRecordingCountProvider).value ?? 0;
    final courses = ref.watch(semesterDataProvider).value?.courses ?? const [];
    final report = view.report;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    String courseName(String id) =>
        courses.where((c) => c.id == id).firstOrNull?.name ?? '';
    final attention = <(String, String)>[
      for (final id in {for (final q in report.questions) q.courseId})
        (id, l.panoptoAskGroup),
      for (final id in report.chooseFolder) (id, l.panoptoAskFolder),
    ].where((a) => courseName(a.$1).isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExperimentalBadge(),
              const SizedBox(height: 8),
              Text(l.panoptoIntro, style: muted),
            ],
          ),
        ),
        if (ref.watch(panoptoRedirectProvider) == null)
          ListTile(
            leading: const Icon(LecIcons.info),
            subtitle: Text(l.panoptoNoServer),
          )
        else
          switch (view.status) {
            PanoptoStatus.off => ListTile(
              leading: const Icon(LecIcons.recording),
              title: Text(l.panoptoSetUp),
              subtitle: Text(l.panoptoSetUpSubtitle),
              trailing: const Icon(LecIcons.chevronEnd),
              onTap: () => context.push('/panopto-setup'),
            ),
            PanoptoStatus.reconnect => ListTile(
              leading: const Icon(LecIcons.warning),
              title: Text(l.panoptoErrorReconnect),
              subtitle: view.site == null ? null : Text(view.site!),
              trailing: TextButton(
                onPressed: view.busy ? null : () => _reconnect(context, ref),
                child: Text(l.panoptoReconnect),
              ),
            ),
            PanoptoStatus.connected => ListTile(
              leading: const Icon(LecIcons.check),
              title: Text(l.panoptoConnectedTo(view.site ?? '')),
              subtitle: Text(
                [
                  if (report.at != null)
                    l.panoptoLastLook(_when(context, report.at!)),
                  l.panoptoFoundCount(found),
                ].join(' · '),
              ),
            ),
          },
        if (view.busy) const LinearProgressIndicator(),
        if (view.status == PanoptoStatus.connected) ...[
          if (report.error != null && report.error != 'reconnect')
            ListTile(
              leading: const Icon(LecIcons.warning),
              subtitle: Text(panoptoErrorText(report.error!, l)),
            ),
          for (final (courseId, ask) in attention)
            ListTile(
              leading: const Icon(LecIcons.courses),
              title: Text(courseName(courseId)),
              subtitle: Text(ask),
              trailing: const Icon(LecIcons.chevronEnd),
              onTap: () => context.go('/courses/$courseId'),
            ),
          ListTile(
            leading: const Icon(LecIcons.refresh),
            title: Text(view.busy ? l.panoptoLooking : l.panoptoLookNow),
            enabled: !view.busy,
            onTap: controller.lookNow,
          ),
        ],
        if (view.status != PanoptoStatus.off)
          ListTile(
            leading: const Icon(LecIcons.close),
            title: Text(l.panoptoDisconnect),
            enabled: !view.busy,
            onTap: () => _disconnect(context, ref, found),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(l.panoptoOneDevice, style: muted),
        ),
      ],
    );
  }

  static String _when(BuildContext context, DateTime at) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final day = LocalDate.fromDateTime(at);
    return '${fmt.relativeDay(day, LocalDate.today(), l)} '
        '${fmt.time(at.hour * 60 + at.minute)}';
  }

  static Future<void> _reconnect(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(panoptoProvider.notifier);
    final setup = await controller.savedSetup();
    if (!context.mounted) return;
    if (setup == null) {
      await context.push('/panopto-setup');
      return;
    }
    await connectPanopto(context, ref, setup);
  }

  static Future<void> _disconnect(
    BuildContext context,
    WidgetRef ref,
    int found,
  ) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    var removeLinks = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l.panoptoDisconnectTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.panoptoDisconnectBody),
              if (found > 0)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: removeLinks,
                  title: Text(l.panoptoRemoveFound(found)),
                  onChanged: (v) => setState(() => removeLinks = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.panoptoDisconnect),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final removed = await ref
        .read(panoptoProvider.notifier)
        .disconnect(removeLinks: removeLinks);
    if (removed > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.panoptoRemoved(removed))),
      );
    }
  }
}

/// Connects with [setup] after the one-time experimental warning; shows
/// what went wrong. Returns whether it connected.
Future<bool> connectPanopto(
  BuildContext context,
  WidgetRef ref,
  PanoptoSetup setup,
) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(panoptoProvider.notifier);
  if (!controller.warned) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.panoptoWarnTitle),
        content: SingleChildScrollView(child: Text(l.panoptoWarnBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.panoptoWarnContinue),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await controller.markWarned();
  }
  try {
    await controller.connect(setup);
    return true;
  } on PanoptoException catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(panoptoErrorText(e.code, l))),
    );
    return false;
  }
}

/// The steps for creating a Panopto API client and connecting to it.
class PanoptoSetupPage extends ConsumerStatefulWidget {
  const PanoptoSetupPage({super.key});

  @override
  ConsumerState<PanoptoSetupPage> createState() => _PanoptoSetupPageState();
}

class _PanoptoSetupPageState extends ConsumerState<PanoptoSetupPage> {
  final _site = TextEditingController(text: PanoptoSetup.defaultSite);
  final _id = TextEditingController();
  final _secret = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(panoptoProvider.notifier).savedSetup().then((saved) {
      if (saved == null || !mounted) return;
      setState(() {
        _site.text = saved.site;
        _id.text = saved.clientId;
      });
    });
  }

  @override
  void dispose() {
    _site.dispose();
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  PanoptoSetup get _setup => PanoptoSetup(
    site: PanoptoSetup.siteFrom(_site.text),
    clientId: _id.text.trim(),
    clientSecret: _secret.text.trim(),
  );

  bool get _ready =>
      _setup.site.isNotEmpty &&
      _setup.clientId.isNotEmpty &&
      _setup.clientSecret.isNotEmpty;

  Future<void> _copy(String text) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(l.panoptoCopied)));
  }

  Future<void> _connect() async {
    if (await connectPanopto(context, ref, _setup) && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = ref.watch(panoptoProvider.select((v) => v.busy));
    final redirect = ref.watch(panoptoRedirectProvider) ?? '';
    Widget step(int n, String title, String body) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n. $title', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.panoptoSetupTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExperimentalBadge(),
              ),
              const SizedBox(height: 8),
              Text(l.panoptoWarning),
              step(1, l.panoptoStepOpen, l.panoptoStepOpenBody),
              TextField(
                controller: _site,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l.panoptoSite),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: _setup.site.isEmpty
                      ? null
                      : () => openUrl('https://${_setup.site}/Panopto'),
                  icon: const Icon(LecIcons.openLink),
                  label: Text(l.panoptoOpen),
                ),
              ),
              step(2, l.panoptoStepCreate, l.panoptoStepCreateBody),
              step(3, l.panoptoStepFill, l.panoptoStepFillBody),
              Card(
                child: ListTile(
                  title: Text(l.panoptoRedirect),
                  subtitle: SelectableText(
                    redirect,
                    textDirection: TextDirection.ltr,
                  ),
                  trailing: IconButton(
                    tooltip: l.panoptoCopy,
                    icon: const Icon(LecIcons.copy),
                    onPressed: () => _copy(redirect),
                  ),
                ),
              ),
              step(4, l.panoptoStepPaste, l.panoptoStepPasteBody),
              TextField(
                controller: _id,
                autocorrect: false,
                decoration: InputDecoration(labelText: l.panoptoClientId),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secret,
                autocorrect: false,
                obscureText: true,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l.panoptoClientSecret),
                onChanged: (_) => setState(() {}),
              ),
              step(5, l.panoptoStepConnect, l.panoptoStepConnectBody),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  onPressed: !_ready || busy || redirect.isEmpty
                      ? null
                      : _connect,
                  icon: const Icon(LecIcons.link),
                  label: Text(l.panoptoConnect),
                ),
              ),
              if (busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 16),
              Text(
                l.panoptoOneDevice,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A heading for Panopto parts elsewhere (the course page).
class PanoptoHeader extends StatelessWidget {
  const PanoptoHeader({super.key});

  @override
  Widget build(BuildContext context) => SectionHeader(
    title: AppLocalizations.of(context).panopto,
    trailing: const Padding(
      padding: EdgeInsetsDirectional.only(end: 8),
      child: ExperimentalBadge(),
    ),
  );
}
