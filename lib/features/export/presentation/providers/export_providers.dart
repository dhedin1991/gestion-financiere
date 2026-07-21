import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/statement_export_service.dart';

final statementExportServiceProvider = Provider<StatementExportService>((ref) {
  return StatementExportService();
});
