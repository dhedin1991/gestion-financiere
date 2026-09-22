import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_financiere/features/backup/data/auto_backup_service.dart';

void main() {
  group('AutoBackupService.isDue', () {
    final now = DateTime(2026, 9, 22, 10);

    test('jamais lancée -> due', () {
      expect(AutoBackupService.isDue(null, now), isTrue);
    });

    test('il y a moins de 7 jours -> pas due', () {
      expect(AutoBackupService.isDue(now.subtract(const Duration(days: 3)), now), isFalse);
    });

    test('il y a exactement 7 jours -> due', () {
      expect(AutoBackupService.isDue(now.subtract(const Duration(days: 7)), now), isTrue);
    });

    test('il y a plus de 7 jours -> due', () {
      expect(AutoBackupService.isDue(now.subtract(const Duration(days: 10)), now), isTrue);
    });
  });
}
