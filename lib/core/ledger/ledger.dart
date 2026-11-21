import 'package:sqflite/sqflite.dart';

/// Grand livre : toute modification du solde d'un compte laisse une écriture
/// dans la table `transactions`, pour que
///   solde = solde initial + somme des écritures
/// reste vrai partout (historique, graphiques, fusion de synchronisation).
///
/// Les écritures « neutres » (virements, remboursements, crédit reçu, épargne,
/// dépôt, retrait…) ont `transfer_group` renseigné : elles n'entrent jamais
/// dans les totaux Revenus/Dépenses. Seules les vraies dépenses/revenus
/// (transfer_group NULL) sont comptées par les statistiques.
class LedgerKind {
  static const depot = 'depot';
  static const retrait = 'retrait';
  static const transfert = 'transfert';
  static const epargne = 'epargne'; // versement vers le compte d'épargne
  static const epargneObjectif = 'epargne_obj'; // module Épargne (enveloppe)
  static const creditRecu = 'credit_recu';
  static const detteRecue = 'dette_recue';
  static const creanceAccordee = 'creance_accordee';
  static const achatCredit = 'achat_credit'; // dépense réelle (comptée)
  static const achatCreditDette = 'achat_credit_dette'; // contrepartie neutre
  static const rembCredit = 'remb_credit';
  static const rembDette = 'remb_dette';
  static const encaissementCreance = 'encaissement_creance';
  static const facture = 'facture'; // facture encaissée (revenu compté)

  static const labels = <String, String>{
    depot: 'Dépôt',
    retrait: 'Retrait',
    transfert: 'Transfert entre comptes',
    epargne: 'Épargne',
    epargneObjectif: 'Épargne (objectif)',
    creditRecu: 'Crédit reçu',
    detteRecue: 'Dette contractée',
    creanceAccordee: 'Créance accordée',
    achatCredit: 'Achat à crédit',
    achatCreditDette: 'Dette fournisseur',
    rembCredit: 'Remboursement de crédit',
    rembDette: 'Remboursement de dette',
    encaissementCreance: 'Encaissement de créance',
    facture: 'Facture encaissée',
  };
}

class Ledger {
  /// Écrit une écriture et applique son effet sur le solde du compte.
  /// [signedCents] > 0 : l'argent entre ; < 0 : l'argent sort.
  /// [neutral] : exclue des statistiques (par défaut).
  /// À appeler dans une `db.transaction`.
  static Future<int> post(
    DatabaseExecutor txn, {
    required int accountId,
    required int signedCents,
    required String kind,
    int? refId,
    String? description,
    String currency = 'XOF',
    DateTime? date,
    int? categoryId,
    bool neutral = true,
    int? group,
  }) async {
    if (signedCents == 0) return 0;
    final now = DateTime.now().toIso8601String();
    final id = await txn.insert('transactions', {
      'account_id': accountId,
      'category_id': categoryId,
      'type': signedCents > 0 ? 'revenu' : 'depense',
      'amount': signedCents.abs(),
      'currency': currency,
      'description': description,
      'transaction_date': (date ?? DateTime.now()).toIso8601String(),
      'kind': kind,
      'ref_id': refId,
      'transfer_group': group,
      'created_at': now,
      'updated_at': now,
    });
    if (neutral && group == null) {
      await txn.update('transactions', {'transfer_group': id}, where: 'id = ?', whereArgs: [id]);
    }
    await txn.rawUpdate(
      'UPDATE accounts SET current_balance = current_balance + ?, updated_at = ? WHERE id = ?',
      [signedCents, now, accountId],
    );
    return id;
  }

  /// Supprime les écritures liées à (kinds, refId) et annule leur effet sur
  /// les comptes. Retourne le nombre d'écritures annulées (0 = donnée ancienne
  /// sans écriture : l'appelant applique alors l'ancienne logique).
  static Future<int> unpost(
    DatabaseExecutor txn, {
    required List<String> kinds,
    required int refId,
  }) async {
    final marks = List.filled(kinds.length, '?').join(',');
    final rows = await txn.query(
      'transactions',
      where: 'kind IN ($marks) AND ref_id = ?',
      whereArgs: [...kinds, refId],
    );
    final now = DateTime.now().toIso8601String();
    for (final r in rows) {
      final cents = (r['amount'] as num).toInt();
      final signed = r['type'] == 'revenu' ? cents : -cents;
      await txn.rawUpdate(
        'UPDATE accounts SET current_balance = current_balance - ?, updated_at = ? WHERE id = ?',
        [signed, now, r['account_id']],
      );
    }
    if (rows.isNotEmpty) {
      await txn.delete('transactions',
          where: 'kind IN ($marks) AND ref_id = ?', whereArgs: [...kinds, refId]);
    }
    return rows.length;
  }

  /// Cumul signé (en centimes) des écritures liées, sans les modifier.
  static Future<int> sumSigned(
    DatabaseExecutor txn, {
    required List<String> kinds,
    required int refId,
  }) async {
    final marks = List.filled(kinds.length, '?').join(',');
    final rows = await txn.rawQuery(
      "SELECT COALESCE(SUM(CASE WHEN type = 'revenu' THEN amount ELSE -amount END), 0) AS s "
      'FROM transactions WHERE kind IN ($marks) AND ref_id = ?',
      [...kinds, refId],
    );
    return (rows.first['s'] as num).toInt();
  }
}
