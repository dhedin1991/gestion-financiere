import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_error_message.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/navigation/app_back_button.dart';
import '../../../../core/navigation/app_menu_button.dart';
import '../../../../core/utils/file_encryption.dart';
import '../providers/backup_providers.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  bool _protectWithPassword = false;
  final _exportPasswordController = TextEditingController();

  @override
  void dispose() {
    _exportPasswordController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    if (_protectWithPassword && _exportPasswordController.text.trim().length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit faire au moins 4 caractères.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).exportBackup(
            password: _protectWithPassword ? _exportPasswordController.text.trim() : null,
          );
      ref.invalidate(lastExportDateProvider);
    } catch (e) {
      if (mounted) {
        AppErrorMessage.showSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decryptFile() async {
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Déchiffrer un fichier'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Déchiffrer'),
            ),
          ],
        );
      },
    );
    if (password == null || password.isEmpty) return;

    setState(() => _busy = true);
    try {
      final decrypted = await ref.read(backupServiceProvider).decryptPickedFile(password);
      if (decrypted == null) return; // annulé

      if (decrypted.path.endsWith('.db')) {
        // C'est une sauvegarde de base de données : propose de la restaurer
        // directement plutôt que de la partager telle quelle.
        if (!mounted) return;
        final restore = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Fichier déchiffré'),
            content: const Text(
              'Ce fichier est une sauvegarde de données. Veux-tu la restaurer maintenant '
              '(remplace tes données actuelles) ?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Non')),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Restaurer'),
              ),
            ],
          ),
        );
        if (restore == true) {
          // Réutilise le flux de restauration existant, qui valide, fait
          // une copie de sécurité, puis remplace — via le même sélecteur
          // de fichier, pointé cette fois sur le fichier déchiffré.
          await _restoreFromDecryptedFile(decrypted);
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fichier déchiffré : ${decrypted.path}')),
        );
      }
    } on FileEncryptionException catch (e) {
      if (mounted) AppErrorMessage.showSnackBar(context, e.message);
    } catch (e) {
      if (mounted) AppErrorMessage.showSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFromDecryptedFile(File decrypted) async {
    final appDatabase = ref.read(appDatabaseProvider);
    await appDatabase.close();
    try {
      final restored = await ref.read(backupServiceProvider).restoreDecryptedDbFile(decrypted);
      if (mounted && restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sauvegarde restaurée. Redémarre l\'app pour l\'appliquer.')),
        );
      }
    } catch (e) {
      if (mounted) AppErrorMessage.showSnackBar(context, e);
    } finally {
      ref.invalidate(appDatabaseProvider);
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
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.upload_outlined),
                        title: const Text('Sauvegarder mes données'),
                        subtitle: const Text(
                          'Exporte une copie de tes données vers l\'endroit de ton choix (Drive, clé USB...)',
                        ),
                        onTap: _export,
                      ),
                      CheckboxListTile(
                        value: _protectWithPassword,
                        dense: true,
                        title: const Text('Protéger par mot de passe', style: TextStyle(fontSize: 13)),
                        onChanged: (v) => setState(() => _protectWithPassword = v ?? false),
                      ),
                      if (_protectWithPassword)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextField(
                            controller: _exportPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(labelText: 'Mot de passe (au moins 4 caractères)'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.lock_open_outlined),
                    title: const Text('Déchiffrer un fichier'),
                    subtitle: const Text(
                      'Ouvre un export protégé par mot de passe (.enc) fait depuis cette app',
                    ),
                    onTap: _decryptFile,
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
