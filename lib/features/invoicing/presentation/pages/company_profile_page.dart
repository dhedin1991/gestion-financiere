import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/invoice_repository.dart';
import '../../domain/invoice.dart';

/// Profil de l'entreprise émettrice : imprimé en en-tête de chaque facture.
class CompanyProfilePage extends ConsumerStatefulWidget {
  const CompanyProfilePage({super.key});

  @override
  ConsumerState<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends ConsumerState<CompanyProfilePage> {
  late final Map<String, TextEditingController> _c;

  @override
  void initState() {
    super.initState();
    final p = ref.read(companyProfileProvider);
    _c = {
      'name': TextEditingController(text: p.name),
      'address': TextEditingController(text: p.address),
      'phone': TextEditingController(text: p.phone),
      'email': TextEditingController(text: p.email),
      'taxId': TextEditingController(text: p.taxId),
      'bank': TextEditingController(text: p.bank),
      'footer': TextEditingController(text: p.footer),
    };
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(companyProfileProvider.notifier).save(CompanyProfile(
          name: _c['name']!.text.trim(),
          address: _c['address']!.text.trim(),
          phone: _c['phone']!.text.trim(),
          email: _c['email']!.text.trim(),
          taxId: _c['taxId']!.text.trim(),
          bank: _c['bank']!.text.trim(),
          footer: _c['footer']!.text.trim(),
        ));
    if (mounted) Navigator.of(context).pop(true);
  }

  Widget _field(String key, String label, {int lines = 1, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _c[key],
          minLines: lines,
          maxLines: lines,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil de l’entreprise')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Ces informations apparaissent en en-tête et en pied de chaque facture.'),
          const SizedBox(height: 16),
          _field('name', 'Nom de l’entreprise'),
          _field('address', 'Adresse', lines: 2),
          _field('phone', 'Téléphone', type: TextInputType.phone),
          _field('email', 'E-mail', type: TextInputType.emailAddress),
          _field('taxId', 'IFU / NIF / RCCM'),
          _field('bank', 'Modalités de règlement (banque, Mobile Money…)', lines: 3),
          _field('footer', 'Message de bas de page'),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
