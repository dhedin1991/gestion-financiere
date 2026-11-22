import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';

import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../credits/domain/entities/credit.dart';
import '../../../credits/domain/entities/credit_installment.dart';
import '../../../credits/presentation/providers/credit_providers.dart';
import '../../../debts/domain/entities/debt.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../../invoicing/data/invoice_repository.dart';
import '../../../invoicing/domain/invoice.dart';
import '../../../savings/presentation/providers/savings_providers.dart';

/// Photographie financière affichée sur l'Accueil (devise principale seulement :
/// jamais de mélange de devises).
class FinancialPosition {
  final String currency;

  /// Argent immédiatement disponible (comptes hors épargne immédiate).
  final double treasury;

  /// Épargne immédiate (compte à rôle « épargne ») + enveloppes d'épargne.
  final double savings;

  /// Reste à rembourser sur les crédits actifs (échéances non payées).
  final double creditsOwed;

  /// Dettes restant à rembourser.
  final double debtsOwed;

  /// Créances restant à encaisser.
  final double receivables;

  /// Factures envoyées, non encore encaissées.
  final double invoicesPending;
  final int invoicesLate;

  const FinancialPosition({
    required this.currency,
    required this.treasury,
    required this.savings,
    required this.creditsOwed,
    required this.debtsOwed,
    required this.receivables,
    required this.invoicesPending,
    required this.invoicesLate,
  });

  /// Ce que je possède moins ce que je dois, plus ce qu'on me doit.
  double get net => treasury + savings + receivables + invoicesPending - creditsOwed - debtsOwed;
}

final financialPositionProvider = FutureProvider.autoDispose<FinancialPosition>((ref) async {
  final accounts = await ref.watch(accountsListProvider.future);
  final main = await ref.watch(mainCurrencyProvider.future);
  final inMain = accounts.where((a) => a.currency == main);

  final treasury = inMain.where((a) => a.role != 'epargne').fold<double>(0, (s, a) => s + a.currentBalance);
  var savings = inMain.where((a) => a.role == 'epargne').fold<double>(0, (s, a) => s + a.currentBalance);

  // Enveloppes d'épargne. Les versements faits via « Nouvelle opération »
  // (nature 'epargne') déplacent déjà l'argent vers un compte : ils sont comptés
  // dans les soldes des comptes, on les retire donc des enveloppes pour ne pas
  // les compter deux fois.
  final envelopes = await ref.watch(savingsListProvider.future);
  var envelopeTotal = envelopes.where((e) => e.currency == main).fold<double>(0, (s, e) => s + e.currentBalance);
  final db = await ref.watch(appDatabaseProvider).database;
  final dup = await db.rawQuery(
    "SELECT COALESCE(SUM(CASE WHEN st.type = 'versement' THEN st.amount ELSE -st.amount END), 0) AS s "
    'FROM savings_transactions st '
    "WHERE st.id IN (SELECT ref_id FROM transactions WHERE kind = 'epargne' AND ref_id IS NOT NULL)",
  );
  envelopeTotal -= ((dup.first['s'] as num?) ?? 0) / 100.0;
  if (envelopeTotal < 0) envelopeTotal = 0;
  savings += envelopeTotal;

  final creditRepo = ref.watch(creditRepositoryProvider);
  final credits = await ref.watch(creditsListProvider.future);
  var creditsOwed = 0.0;
  for (final Credit c in credits) {
    if (c.id == null || c.currency != main || c.status != CreditStatus.actif) continue;
    final inst = await creditRepo.getInstallmentsForCredit(c.id!);
    creditsOwed += inst.where((i) => i.status != InstallmentStatus.payee).fold<double>(0, (s, i) => s + i.amount);
  }

  final debts = await ref.watch(debtsListProvider.future);
  final open = debts.where((d) => d.currency == main && !d.isSettled);
  final debtsOwed = open.where((d) => d.type == DebtType.dette).fold<double>(0, (s, d) => s + d.remainingAmount);
  final receivables = open.where((d) => d.type == DebtType.creance).fold<double>(0, (s, d) => s + d.remainingAmount);

  final invoices = await ref.watch(invoicesProvider.future);
  final sent = invoices.where((i) => i.currency == main && i.status == InvoiceStatus.envoyee);
  final pending = sent.fold<double>(0, (s, i) => s + i.remaining);
  final late = sent.where((i) => i.isOverdue).length;

  return FinancialPosition(
    currency: main,
    treasury: treasury,
    savings: savings,
    creditsOwed: creditsOwed,
    debtsOwed: debtsOwed,
    receivables: receivables,
    invoicesPending: pending,
    invoicesLate: late,
  );
});
