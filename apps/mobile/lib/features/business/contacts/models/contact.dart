/// A single row from `public.contacts` — customers, vendors, and anyone
/// else dealt with, shared across MAKE, PROTECT, and RECOVER.
class Contact {
  const Contact({
    required this.id,
    required this.accountId,
    required this.displayName,
    this.email,
    this.phone,
    this.company,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      accountId: json['account_id'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      company: json['company'] as String?,
    );
  }

  final String id;
  final String accountId;
  final String displayName;
  final String? email;
  final String? phone;
  final String? company;
}

/// A minimal contact reference used to populate "pick a contact" dropdowns
/// on the leads/opportunities/quotes forms.
class ContactRef {
  const ContactRef({required this.id, required this.displayName});

  factory ContactRef.fromJson(Map<String, dynamic> json) {
    return ContactRef(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
    );
  }

  final String id;
  final String displayName;
}
