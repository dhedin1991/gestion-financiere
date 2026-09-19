import '../../transactions/domain/entities/transaction.dart';
import '../../transactions/domain/repositories/transaction_repository.dart';
import '../domain/repositories/recurring_transaction_repository.dart';

/// Génère les vraies transactions correspondant aux récurrences actives
/// dont l'échéance est passée, puis avance leur prochaine échéance.
///
/// Rattrape les occurrences manquées si l'app n'a pas été ouverte
/// pendant un moment (ex: 3 échéances hebdomadaires manquées ->
/// 3 transactions créées, une par échéance), plutôt que de les perdre.
/// Une limite de sécurité évite un rattrapage infini en cas de données
/// corrompues (fréquence qui n'avancerait jamais, par exemple).
class RecurringTransactionGenerator {
  final RecurringTransactionRepository _recurringRepository;
  final TransactionRepository _transactionRepository;

  static const _maxOccurrencesPerRun = 60;

  RecurringTransactionGenerator({
    required RecurringTransactionRepository recurringRepository,
    required TransactionRepository transactionRepository,
  })  : _recurringRepository = recurringRepository,
        _transactionRepository = transactionRepository;

  static Future<int>? _running;

  /// Retourne le nombre de transactions générées.
  ///
  /// Une seule génération à la fois : des appels simultanés (démarrage +
  /// retour au premier plan) créeraient sinon chaque transaction en double.
  Future<int> generateDueTransactions() {
    final running = _running;
    if (running != null) return running;
    final future = _generate().whenComplete(() => _running = null);
    _running = future;
    return future;
  }

  Future<int> _generate() async {
    final due = await _recurringRepository.getDue();
    var generatedCount = 0;

    for (final recurring in due) {
      var current = recurring;
      final now = DateTime.now();
      var occurrences = 0;

      while (!current.nextDueDate.isAfter(now) && occurrences < _maxOccurrencesPerRun) {
        await _transactionRepository.createTransaction(
          FinancialTransaction(
            accountId: current.accountId,
            categoryId: current.categoryId,
            type: current.type,
            amount: current.amount,
            currency: current.currency,
            description: current.description,
            transactionDate: current.nextDueDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
        generatedCount++;
        occurrences++;

        current = current.copyWith(nextDueDate: current.computeNextDueDate(), updatedAt: now);
        // Avance l'échéance TOUT DE SUITE après chaque transaction créée :
        // un arrêt en plein milieu ne peut plus produire qu'un doublon au
        // pire, jamais tout un lot.
        await _recurringRepository.update(current);
      }
    }

    return generatedCount;
  }
}
