import 'package:shared_preferences/shared_preferences.dart';

import '../../budgets/domain/repositories/budget_repository.dart';
import '../../credits/domain/entities/credit_installment.dart';
import '../../credits/domain/repositories/credit_repository.dart';
import '../../debts/domain/entities/debt.dart';
import '../../debts/domain/repositories/debt_repository.dart';
import 'notification_service.dart';

/// Recalcule tous les rappels planifiés à partir des données actuelles
/// (crédits, dettes, budgets), et les (re)programme.
///
/// Appelé une fois à chaque ouverture de l'app (voir
/// reminderBootstrapProvider). Comme les notifications planifiées
/// (zonedSchedule) sont prises en charge par le système d'exploitation,
/// elles se déclenchent même si l'app n'est pas ouverte au moment de
/// l'échéance — recalculer à chaque ouverture suffit à garder les
/// rappels à jour (nouvelle échéance, dette soldée entre-temps, etc.)
/// sans nécessiter de tâche de fond.
class ReminderSyncService {
  final NotificationService _notifications;
  final CreditRepository _creditRepository;
  final DebtRepository _debtRepository;
  final BudgetRepository _budgetRepository;

  ReminderSyncService({
    required NotificationService notifications,
    required CreditRepository creditRepository,
    required DebtRepository debtRepository,
    required BudgetRepository budgetRepository,
  })  : _notifications = notifications,
        _creditRepository = creditRepository,
        _debtRepository = debtRepository,
        _budgetRepository = budgetRepository;

  // Plages d'IDs de notification disjointes par catégorie, pour pouvoir
  // annuler proprement une catégorie sans toucher aux autres.
  // Échéances crédit : 1_000_000 + installmentId * 2 (+1 pour le rappel J-3)
  // Dettes           : 2_000_000 + debtId
  // Budgets          : 3_000_000 + budgetId
  int _creditDueId(int installmentId) => 1000000 + installmentId * 2;
  int _creditWarnId(int installmentId) => 1000000 + installmentId * 2 + 1;
  int _debtId(int debtId) => 2000000 + debtId;
  int _budgetId(int budgetId) => 3000000 + budgetId;

  Future<void> syncAll() async {
    await _notifications.init();
    await Future.wait([
      _syncCreditReminders(),
      _syncDebtReminders(),
      _checkBudgets(),
    ]);
  }

  Future<void> _syncCreditReminders() async {
    final credits = await _creditRepository.getAllCredits();
    for (final credit in credits) {
      if (credit.id == null) continue;
      final installments = await _creditRepository.getInstallmentsForCredit(credit.id!);
      for (final installment in installments) {
        if (installment.id == null) continue;
        final dueId = _creditDueId(installment.id!);
        final warnId = _creditWarnId(installment.id!);

        if (installment.status == InstallmentStatus.payee) {
          await _notifications.cancelRange([dueId, warnId]);
          continue;
        }

        await _notifications.scheduleAt(
          id: warnId,
          title: 'Échéance de crédit dans 3 jours',
          body: '${credit.name} — ${installment.amount.toStringAsFixed(0)} ${credit.currency} '
              'à régler le ${_fmt(installment.dueDate)}',
          when: installment.dueDate.subtract(const Duration(days: 3)),
        );
        await _notifications.scheduleAt(
          id: dueId,
          title: 'Échéance de crédit aujourd\'hui',
          body: '${credit.name} — ${installment.amount.toStringAsFixed(0)} ${credit.currency}',
          when: DateTime(installment.dueDate.year, installment.dueDate.month,
              installment.dueDate.day, 9),
        );
      }
    }
  }

  Future<void> _syncDebtReminders() async {
    final debts = await _debtRepository.getAllDebts();
    for (final debt in debts) {
      if (debt.id == null) continue;
      final id = _debtId(debt.id!);

      if (debt.isSettled || debt.dueDate == null) {
        await _notifications.cancel(id);
        continue;
      }

      final label = debt.type == DebtType.dette ? 'à rembourser à' : 'à récupérer auprès de';
      await _notifications.scheduleAt(
        id: id,
        title: 'Échéance de dette dans 3 jours',
        body: '${debt.remainingAmount.toStringAsFixed(0)} ${debt.currency} $label ${debt.personName}',
        when: debt.dueDate!.subtract(const Duration(days: 3)),
      );
    }
  }

  /// Vérifie les dépassements de budget et notifie immédiatement (pas de
  /// planification possible ici : ça dépend des dépenses réelles, pas
  /// d'une date connue à l'avance). Dédoublonné par jour via
  /// SharedPreferences pour ne pas spammer à chaque ouverture de l'app.
  Future<void> _checkBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    final budgets = await _budgetRepository.getAllBudgets();
    for (final budget in budgets) {
      if (budget.id == null) continue;
      final spent = await _budgetRepository.getSpentAmount(budget);
      if (spent < budget.amount) continue;

      final prefsKey = 'budget_alert_${budget.id}_$todayKey';
      if (prefs.getBool(prefsKey) == true) continue;

      await _notifications.showNow(
        id: _budgetId(budget.id!),
        title: 'Budget dépassé',
        body:
            '${budget.name ?? 'Budget'} : ${spent.toStringAsFixed(0)} / ${budget.amount.toStringAsFixed(0)} ${budget.currency}',
      );
      await prefs.setBool(prefsKey, true);
    }
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
