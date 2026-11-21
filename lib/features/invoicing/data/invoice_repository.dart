import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/ledger/ledger.dart';
import '../../../core/utils/money.dart';
import '../domain/invoice.dart';

class InvoiceRepository {
  final AppDatabase _appDatabase;
  InvoiceRepository(this._appDatabase);

  Invoice _fromRow(Map<String, Object?> m, List<InvoiceItem> items) {
    InvoiceTemplate tpl = InvoiceTemplate.values.firstWhere(
      (t) => t.name == m['template'],
      orElse: () => InvoiceTemplate.classique,
    );
    InvoiceStatus st = InvoiceStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => InvoiceStatus.brouillon,
    );
    return Invoice(
      id: m['id'] as int?,
      number: m['number'] as String,
      template: tpl,
      status: st,
      clientName: m['client_name'] as String,
      clientAddress: m['client_address'] as String?,
      clientPhone: m['client_phone'] as String?,
      clientEmail: m['client_email'] as String?,
      issueDate: DateTime.parse(m['issue_date'] as String),
      dueDate: m['due_date'] == null ? null : DateTime.parse(m['due_date'] as String),
      currency: m['currency'] as String? ?? 'XOF',
      taxRate: (m['tax_rate'] as num?)?.toDouble() ?? 0,
      discount: Money.fromCents((m['discount'] as num? ?? 0).toInt()),
      paidAmount: Money.fromCents((m['paid_amount'] as num? ?? 0).toInt()),
      accountId: m['account_id'] as int?,
      notes: m['notes'] as String?,
      items: items,
      createdAt: DateTime.parse(m['created_at'] as String),
      updatedAt: DateTime.parse(m['updated_at'] as String),
    );
  }

  Future<List<InvoiceItem>> _items(DatabaseExecutor db, int invoiceId) async {
    final rows = await db.query('invoice_items',
        where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'position ASC, id ASC');
    return rows
        .map((r) => InvoiceItem(
              id: r['id'] as int?,
              description: r['description'] as String,
              quantity: (r['quantity'] as num).toDouble(),
              unitPrice: Money.fromCents((r['unit_price'] as num).toInt()),
            ))
        .toList();
  }

  Future<List<Invoice>> list() async {
    final db = await _appDatabase.database;
    final rows = await db.query('invoices', orderBy: 'issue_date DESC, id DESC');
    final out = <Invoice>[];
    for (final r in rows) {
      out.add(_fromRow(r, await _items(db, r['id'] as int)));
    }
    return out;
  }

  Future<Invoice?> get(int id) async {
    final db = await _appDatabase.database;
    final rows = await db.query('invoices', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first, await _items(db, id));
  }

  /// Prochain numéro libre : FAC-2026-0001, FAC-2026-0002...
  Future<String> nextNumber([DateTime? now]) async {
    final db = await _appDatabase.database;
    final year = (now ?? DateTime.now()).year;
    final prefix = 'FAC-$year-';
    final rows = await db.query('invoices',
        columns: ['number'], where: 'number LIKE ?', whereArgs: ['$prefix%']);
    var max = 0;
    for (final r in rows) {
      final n = int.tryParse((r['number'] as String).substring(prefix.length)) ?? 0;
      if (n > max) max = n;
    }
    return '$prefix${(max + 1).toString().padLeft(4, '0')}';
  }

  Map<String, Object?> _toRow(Invoice i) => {
        'number': i.number,
        'template': i.template.name,
        'status': i.status.name,
        'client_name': i.clientName,
        'client_address': i.clientAddress,
        'client_phone': i.clientPhone,
        'client_email': i.clientEmail,
        'issue_date': i.issueDate.toIso8601String(),
        'due_date': i.dueDate?.toIso8601String(),
        'currency': i.currency,
        'tax_rate': i.taxRate,
        'discount': Money.toCents(i.discount),
        'paid_amount': Money.toCents(i.paidAmount),
        'account_id': i.accountId,
        'notes': i.notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

  /// Crée ou met à jour la facture et remplace ses lignes (atomique).
  Future<int> save(Invoice i) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      int id;
      if (i.id == null) {
        id = await txn.insert('invoices', {..._toRow(i), 'created_at': DateTime.now().toIso8601String()});
      } else {
        id = i.id!;
        await txn.update('invoices', _toRow(i), where: 'id = ?', whereArgs: [id]);
        await txn.delete('invoice_items', where: 'invoice_id = ?', whereArgs: [id]);
      }
      var pos = 0;
      for (final it in i.items) {
        await txn.insert('invoice_items', {
          'invoice_id': id,
          'description': it.description,
          'quantity': it.quantity,
          'unit_price': Money.toCents(it.unitPrice),
          'position': pos++,
        });
      }
      return id;
    });
  }

  Future<void> setStatus(int id, InvoiceStatus status) async {
    final db = await _appDatabase.database;
    await db.update('invoices', {'status': status.name, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Encaisse la facture : elle passe en « Payée » ET le montant est crédité
  /// sur le compte choisi (revenu compté dans les statistiques), en une seule
  /// transaction.
  Future<void> collect(Invoice invoice, int accountId, {DateTime? date}) async {
    final id = invoice.id;
    if (id == null) throw StateError('Enregistre d’abord la facture.');
    final cents = Money.toCents(invoice.remaining);
    if (cents <= 0) return;
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await Ledger.post(
        txn,
        accountId: accountId,
        signedCents: cents,
        kind: LedgerKind.facture,
        refId: id,
        neutral: false,
        currency: invoice.currency,
        description: 'Facture ${invoice.number} — ${invoice.clientName}',
        date: date ?? DateTime.now(),
      );
      await txn.update(
        'invoices',
        {
          'status': InvoiceStatus.payee.name,
          'paid_amount': Money.toCents(invoice.total),
          'account_id': accountId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Annule l'encaissement (supprime le revenu et rouvre la facture).
  Future<void> uncollect(int id) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await Ledger.unpost(txn, kinds: [LedgerKind.facture], refId: id);
      await txn.update(
        'invoices',
        {'status': InvoiceStatus.envoyee.name, 'paid_amount': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> delete(int id) async {
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await Ledger.unpost(txn, kinds: [LedgerKind.facture], refId: id);
      await txn.delete('invoices', where: 'id = ?', whereArgs: [id]);
    });
  }
}

final invoiceRepositoryProvider =
    Provider<InvoiceRepository>((ref) => InvoiceRepository(ref.watch(appDatabaseProvider)));

final invoicesProvider = FutureProvider.autoDispose<List<Invoice>>((ref) async {
  return ref.watch(invoiceRepositoryProvider).list();
});

class CompanyProfileController extends StateNotifier<CompanyProfile> {
  CompanyProfileController() : super(const CompanyProfile()) {
    _load();
  }
  static const _k = 'company_';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = CompanyProfile(
        name: p.getString('${_k}name') ?? '',
        address: p.getString('${_k}address') ?? '',
        phone: p.getString('${_k}phone') ?? '',
        email: p.getString('${_k}email') ?? '',
        taxId: p.getString('${_k}taxid') ?? '',
        bank: p.getString('${_k}bank') ?? '',
        footer: p.getString('${_k}footer') ?? 'Merci pour votre confiance.',
      );
    } catch (_) {}
  }

  Future<void> save(CompanyProfile c) async {
    state = c;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('${_k}name', c.name);
      await p.setString('${_k}address', c.address);
      await p.setString('${_k}phone', c.phone);
      await p.setString('${_k}email', c.email);
      await p.setString('${_k}taxid', c.taxId);
      await p.setString('${_k}bank', c.bank);
      await p.setString('${_k}footer', c.footer);
    } catch (_) {}
  }
}

final companyProfileProvider =
    StateNotifierProvider<CompanyProfileController, CompanyProfile>((ref) => CompanyProfileController());
