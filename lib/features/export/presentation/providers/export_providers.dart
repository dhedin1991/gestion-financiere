import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/statement_export_service.dart';
import '../../data/statement_import_service.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';

final statementExportServiceProvider = Provider<StatementExportService>((ref) {
  return StatementExportService();
});

final statementImportServiceProvider = Provider<StatementImportService>((ref) {
  return StatementImportService(ref.watch(transactionRepositoryProvider));
});
