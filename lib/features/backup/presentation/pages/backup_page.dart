import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_message.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../providers/backup_providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).exportBackup();
      ref.invalidate(lastExportDateProvider);
    } catch (e) {
      if (mounted) {
        AppErrorMessage.showSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurer une sauvegarde ?'),
        content: const Text(
          'Toutes tes données actuelles seront remplacées par celles du fichier choisi. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final appDatabase = ref.read(appDatabaseProvider);
      await appDatabase.close();
      final restored = await ref.read(backupServiceProvider).restoreBackup();

      if (mounted && restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sauvegarde restaurée. Redémarre l\'app pour l\'appliquer.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppErrorMessage.showSnackBar(context, e);
      }
    } finally {
      // Que la restauration ait réussi, échoué ou été refusée (fichier
      // invalide), on force la reconnexion à la base sur disque : sans
      // ça, la base resterait fermée après un échec et l'app planterait
      // à la moindre lecture tant qu'elle n'est pas redémarrée.
      ref.invalidate(appDatabaseProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastExport = ref.watch(lastExportDateProvider).valueOrNull;
    final needsReminder =
        lastExport == null || DateTime.now().difference(lastExport) > const Duration(days: 30);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('Sauvegarde & restauration'),
        actions: const [AppMenuButton()],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (needsReminder)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.onErrorContainer),
                      title: Text(
                        lastExport == null
                            ? 'Aucun export effectué pour l\'instant'
                            : 'Dernier export il y a plus de 30 jours',
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                      subtitle: Text(
                        'Une copie de sécurité automatique existe dans le dossier de l\'app, '
                        'mais elle ne te protège pas d\'un téléphone perdu ou cassé. '
                        'Exporte régulièrement vers un endroit sûr (Drive, clé USB...).',
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ),
                if (needsReminder) const SizedBox(height: 8),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.upload_outlined),
                    title: const Text('Sauvegarder mes données'),
                    subtitle: const Text(
                      'Exporte une copie de tes données vers l\'endroit de ton choix (Drive, clé USB...)',
                    ),
                    onTap: _export,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: const Text('Restaurer une sauvegarde'),
                    subtitle: const Text(
                      'Remplace tes données actuelles par un fichier de sauvegarde précédemment exporté',
                    ),
                    onTap: _restore,
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Le fichier de sauvegarde n\'est pas chiffré : garde-le dans un endroit '
                    'que tu contrôles (pas de service de stockage partagé publiquement).',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }
}
