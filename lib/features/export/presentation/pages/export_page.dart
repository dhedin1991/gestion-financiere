import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../accounts/presentation/providers/account_providers.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../providers/export_providers.dart';

enum _Period { moisEnCours, trenteJours, tout, personnalise }

/// Écran permettant d'exporter les transactions en CSV ou PDF, sur une
/// période choisie (mois en cours, 30 derniers jours, tout, ou plage
/// personnalisée).
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  _Period _period = _Period.moisEnCours;
  DateTimeRange? _customRange;
  bool _exporting = false;

  (DateTime?, DateTime?) _resolveRange() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.moisEnCours:
        return (DateTime(now.year, now.month, 1), now);
      case _Period.trenteJours:
        return (now.subtract(const Duration(days: 30)), now);
      case _Period.tout:
        return (null, null);
      case _Period.personnalise:
        return (_customRange?.start, _customRange?.end);
    }
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
      locale: const Locale('fr', 'FR'),
    );
    if (range != null) {
      setState(() {
        _customRange = range;
        _period = _Period.personnalise;
      });
    }
  }

  Future<void> _export({required bool asPdf}) async {
    setState(() => _exporting = true);
    try {
      final (from, to) = _resolveRange();
      final repository = ref.read(transactionRepositoryProvider);
      final transactions = await repository.getTransactions(
        from: from,
        to: to,
        limit: 100000,
      );

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune transaction sur cette période.')),
          );
        }
        return;
      }

      final accounts = await ref.read(allAccountsIncludingArchivedProvider.future);
      final categories = await ref.read(allCategoriesProvider.future);
      final service = ref.read(statementExportServiceProvider);

      if (asPdf) {
        await service.exportPdf(
          transactions: transactions,
          accounts: accounts,
          categories: categories,
          periodFrom: from,
          periodTo: to,
        );
      } else {
        await service.exportCsv(
          transactions: transactions,
          accounts: accounts,
          categories: categories,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'export : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _periodLabel(_Period p) {
    switch (p) {
      case _Period.moisEnCours:
        return 'Mois en cours';
      case _Period.trenteJours:
        return '30 derniers jours';
      case _Period.tout:
        return 'Toutes les transactions';
      case _Period.personnalise:
        if (_customRange == null) return 'Période personnalisée';
        final fmt = DateFormat('dd/MM/yyyy');
        return '${fmt.format(_customRange!.start)} → ${fmt.format(_customRange!.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exporter mes données')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Période', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...[_Period.moisEnCours, _Period.trenteJours, _Period.tout].map(
            (p) => RadioListTile<_Period>(
              value: p,
              groupValue: _period,
              title: Text(_periodLabel(p)),
              onChanged: (v) => setState(() => _period = v!),
            ),
          ),
          RadioListTile<_Period>(
            value: _Period.personnalise,
            groupValue: _period,
            title: Text(_periodLabel(_Period.personnalise)),
            onChanged: (_) => _pickCustomRange(),
          ),
          const SizedBox(height: 24),
          Text('Format', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (_exporting)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else ...[
            FilledButton.icon(
              onPressed: () => _export(asPdf: true),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exporter en PDF (relevé imprimable)'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _export(asPdf: false),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('Exporter en CSV (pour tableur / comptable)'),
            ),
          ],
        ],
      ),
    );
  }
}
