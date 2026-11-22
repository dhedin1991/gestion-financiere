enum InvoiceStatus { brouillon, envoyee, payee, annulee }

extension InvoiceStatusInfo on InvoiceStatus {
  String get label => const ['Brouillon', 'Envoyée', 'Payée', 'Annulée'][index];
}

enum InvoiceTemplate { classique, moderne, minimal, institutionnel }

extension InvoiceTemplateInfo on InvoiceTemplate {
  String get label => const ['Classique', 'Moderne', 'Minimaliste', 'Institutionnel'][index];
  String get hint => const [
        'Bandeau marine, tableau encadré',
        'Couleur vive, totaux en carte',
        'Noir et blanc, très épuré',
        'Style banque : marine et or, mentions légales',
      ][index];
  int get accent => const [0xFF1F3A5F, 0xFF0F9D8A, 0xFF222222, 0xFFB8912F][index];
  int get header => const [0xFF1F3A5F, 0xFF0F9D8A, 0xFFFFFFFF, 0xFF0B1F3A][index];
}

class InvoiceItem {
  final int? id;
  final String description;
  final double quantity;
  final double unitPrice;
  const InvoiceItem({this.id, required this.description, this.quantity = 1, this.unitPrice = 0});

  double get total => quantity * unitPrice;
}

class Invoice {
  final int? id;
  final String number;
  final InvoiceTemplate template;
  final InvoiceStatus status;
  final String clientName;
  final String? clientAddress;
  final String? clientPhone;
  final String? clientEmail;
  final DateTime issueDate;
  final DateTime? dueDate;
  final String currency;

  /// Taux de TVA / taxe en % (0 = sans taxe).
  final double taxRate;

  /// Remise globale (montant).
  final double discount;
  final double paidAmount;
  final int? accountId;
  final String? notes;
  final List<InvoiceItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Invoice({
    this.id,
    required this.number,
    this.template = InvoiceTemplate.classique,
    this.status = InvoiceStatus.brouillon,
    required this.clientName,
    this.clientAddress,
    this.clientPhone,
    this.clientEmail,
    required this.issueDate,
    this.dueDate,
    this.currency = 'XOF',
    this.taxRate = 0,
    this.discount = 0,
    this.paidAmount = 0,
    this.accountId,
    this.notes,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.total);
  double get taxable => (subtotal - discount).clamp(0, double.infinity).toDouble();
  double get taxAmount => taxable * taxRate / 100;
  double get total => taxable + taxAmount;
  double get remaining => (total - paidAmount).clamp(0, double.infinity).toDouble();
  bool get isOverdue =>
      status == InvoiceStatus.envoyee && dueDate != null && dueDate!.isBefore(DateTime.now()) && remaining > 0;

  Invoice copyWith({
    int? id,
    String? number,
    InvoiceTemplate? template,
    InvoiceStatus? status,
    String? clientName,
    String? clientAddress,
    String? clientPhone,
    String? clientEmail,
    DateTime? issueDate,
    DateTime? dueDate,
    String? currency,
    double? taxRate,
    double? discount,
    double? paidAmount,
    int? accountId,
    String? notes,
    List<InvoiceItem>? items,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      number: number ?? this.number,
      template: template ?? this.template,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      clientAddress: clientAddress ?? this.clientAddress,
      clientPhone: clientPhone ?? this.clientPhone,
      clientEmail: clientEmail ?? this.clientEmail,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      currency: currency ?? this.currency,
      taxRate: taxRate ?? this.taxRate,
      discount: discount ?? this.discount,
      paidAmount: paidAmount ?? this.paidAmount,
      accountId: accountId ?? this.accountId,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

/// Coordonnées de l'entreprise émettrice (imprimées sur chaque facture).
class CompanyProfile {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String taxId; // IFU / NIF / RCCM
  final String bank; // coordonnées bancaires / Mobile Money
  final String footer;
  const CompanyProfile({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.taxId = '',
    this.bank = '',
    this.footer = 'Merci pour votre confiance.',
  });

  CompanyProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? email,
    String? taxId,
    String? bank,
    String? footer,
  }) =>
      CompanyProfile(
        name: name ?? this.name,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        taxId: taxId ?? this.taxId,
        bank: bank ?? this.bank,
        footer: footer ?? this.footer,
      );
}
