import 'package:material_ui/material_ui.dart';

import '../../app/labels.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';

/// Something@something.something, without spaces: enough to catch typos.
final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isEmailAddress(String text) => _emailPattern.hasMatch(text.trim());

class ContactDraft {
  ContactDraft([CourseContact? contact])
    : name = TextEditingController(text: contact?.name ?? ''),
      email = TextEditingController(text: contact?.email ?? ''),
      role = contact?.role ?? ContactRole.lecturer;

  final TextEditingController name;
  final TextEditingController email;
  ContactRole role;

  /// Null when both fields are empty.
  CourseContact? toContact() {
    final name = this.name.text.trim();
    final email = this.email.text.trim();
    if (name.isEmpty && email.isEmpty) return null;
    return CourseContact(name: name, role: role, email: email);
  }

  void dispose() {
    name.dispose();
    email.dispose();
  }
}

/// The course's contacts as cards: name and role, then email.
class ContactsEditor extends StatelessWidget {
  const ContactsEditor({
    super.key,
    required this.contacts,
    required this.onChanged,
  });

  final List<ContactDraft> contacts;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final contact in contacts)
          _ContactCard(
            key: ObjectKey(contact),
            draft: contact,
            onChanged: onChanged,
            onRemove: () {
              contacts.remove(contact);
              contact.dispose();
              onChanged();
            },
          ),
        TextButton.icon(
          onPressed: () {
            // The first one is usually the lecturer, then the TAs.
            contacts.add(
              ContactDraft(
                CourseContact(
                  name: '',
                  role: contacts.isEmpty
                      ? ContactRole.lecturer
                      : ContactRole.assistant,
                ),
              ),
            );
            onChanged();
          },
          icon: const Icon(LecIcons.add),
          label: Text(l.addContact),
        ),
      ],
    );
  }
}

class _ContactCard extends StatefulWidget {
  const _ContactCard({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final ContactDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard> {
  /// The email is checked once you leave the field, not while typing.
  bool _emailTouched = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = widget.draft;
    final email = draft.email.text.trim();
    final emailError =
        _emailTouched && email.isNotEmpty && !isEmailAddress(email);
    return Card(
      color: theme.colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: draft.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l.contactName),
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButton<ContactRole>(
                    isExpanded: true,
                    value: draft.role,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final r in ContactRole.values)
                        DropdownMenuItem(value: r, child: Text(r.label(l))),
                    ],
                    onChanged: (r) {
                      if (r == null) return;
                      draft.role = r;
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: l.remove,
                  icon: const Icon(LecIcons.close),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Focus(
                onFocusChange: (focused) {
                  if (!focused) setState(() => _emailTouched = true);
                },
                child: TextField(
                  controller: draft.email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.contactEmail,
                    prefixIcon: const Icon(LecIcons.email),
                    errorText: emailError ? l.contactEmailInvalid : null,
                  ),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
