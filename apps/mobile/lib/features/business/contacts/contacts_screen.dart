import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/account/account_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_error_view.dart';
import 'contacts_providers.dart';
import 'models/contact.dart';

/// Customers, vendors, and anyone else dealt with — shared across MAKE,
/// PROTECT, and RECOVER. Mirrors
/// `apps/web/src/app/(app)/business/contacts/page.tsx`.
class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: SafeArea(
        child: contactsAsync.when(
          data: (contacts) => _ContactsBody(contacts: contacts),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AsyncErrorView(
            error: error,
            onRetry: () => ref.invalidate(contactsProvider),
          ),
        ),
      ),
    );
  }
}

class _ContactsBody extends ConsumerWidget {
  const _ContactsBody({required this.contacts});

  final List<Contact> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(contactsProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Customers, vendors, and anyone else you deal with — shared '
            'across MAKE, PROTECT, and RECOVER.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          const _CreateContactForm(),
          const SizedBox(height: AppSpacing.lg),
          if (contacts.isEmpty)
            const Text('No contacts yet.')
          else
            for (final contact in contacts) _ContactTile(contact: contact),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      contact.company,
      contact.email,
      contact.phone,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.displayName, style: theme.textTheme.bodyLarge),
              Text(
                details.isEmpty ? 'No details' : details,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateContactForm extends ConsumerStatefulWidget {
  const _CreateContactForm();

  @override
  ConsumerState<_CreateContactForm> createState() => _CreateContactFormState();
}

class _CreateContactFormState extends ConsumerState<_CreateContactForm> {
  final _nameController = TextEditingController();
  final _companyController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final accountId = ref.read(activeAccountProvider).id;
      await ref
          .read(contactsRepositoryProvider)
          .createContact(
            accountId: accountId,
            displayName: name,
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            company: _companyController.text.trim().isEmpty
                ? null
                : _companyController.text.trim(),
          );
      if (!mounted) return;
      _nameController.clear();
      _companyController.clear();
      _emailController.clear();
      _phoneController.clear();
      ref.invalidate(contactsProvider);
      ref.invalidate(contactRefsProvider);
    } catch (_) {
      if (mounted) {
        setState(() => _error = userSafeActionError('add this contact'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add contact'),
                ),
                if (_error != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
