import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_providers.dart';
import '../../data/datasources/credit_dao.dart';
import '../../data/repositories/credit_repository_impl.dart';
import '../../domain/entities/credit.dart';
import '../../domain/entities/credit_installment.dart';
import '../../domain/repositories/credit_repository.dart';

final creditDaoProvider = Provider<CreditDao>((ref) {
  final appDatabase = ref.watch(appDatabaseProvider);
  return CreditDao(appDatabase);
});

final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  final dao = ref.watch(creditDaoProvider);
  return CreditRepositoryImpl(dao);
});

/// Liste de tous les crédits, rafraîchie automatiquement après toute
/// création/modification/suppression via 'ref.invalidate'.
final creditsListProvider = FutureProvider.autoDispose<List<Credit>>((ref) async {
  final repository = ref.watch(creditRepositoryProvider);
  return repository.getAllCredits();
});

/// Échéancier complet d'un crédit précis (paramétré par son id).
final creditInstallmentsProvider =
    FutureProvider.autoDispose.family<List<CreditInstallment>, int>((ref, creditId) async {
  final repository = ref.watch(creditRepositoryProvider);
  return repository.getInstallmentsForCredit(creditId);
});

/// Nombre d'échéances payées pour un crédit précis.
final creditPaidCountProvider =
    FutureProvider.autoDispose.family<int, int>((ref, creditId) async {
  final repository = ref.watch(creditRepositoryProvider);
  return repository.countPaidInstallments(creditId);
});

/// Contrôleur exposant les actions (créer/modifier/supprimer un crédit,
/// marquer une échéance comme payée).
final creditActionsProvider = Provider<CreditActions>((ref) {
  final repository = ref.watch(creditRepositoryProvider);
  return CreditActions(ref, repository);
});

class CreditActions {
  final Ref _ref;
  final CreditRepository _repository;

  CreditActions(this._ref, this._repository);

  Future<void> create(Credit credit) async {
    await _repository.createCredit(credit);
    _refresh();
  }

  Future<void> update(Credit credit) async {
    await _repository.updateCredit(credit);
    _refresh();
  }

  Future<void> delete(int id) async {
    await _repository.deleteCredit(id);
    _refresh();
  }

  Future<void> markInstallmentPaid(CreditInstallment installment) async {
    final updated = installment.copyWith(
      status: InstallmentStatus.payee,
      paymentDate: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repository.updateInstallment(updated);
    _ref.invalidate(creditInstallmentsProvider(installment.creditId));
    _ref.invalidate(creditPaidCountProvider(installment.creditId));
  }

  Future<void> markInstallmentUnpaid(CreditInstallment installment) async {
    final updated = installment.copyWith(
      status: InstallmentStatus.enAttente,
      paymentDate: null,
      updatedAt: DateTime.now(),
    );
    await _repository.updateInstallment(updated);
    _ref.invalidate(creditInstallmentsProvider(installment.creditId));
    _ref.invalidate(creditPaidCountProvider(installment.creditId));
  }

  void _refresh() {
    _ref.invalidate(creditsListProvider);
  }
}
