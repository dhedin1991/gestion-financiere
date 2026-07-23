import 'package:flutter/material.dart';

class _HelpSection {
  final IconData icon;
  final String title;
  final String body;
  const _HelpSection({required this.icon, required this.title, required this.body});
}

const _sections = [
  _HelpSection(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Comptes',
    body: 'Chaque compte (espèces, banque, mobile money...) a son propre solde. '
        'Toutes tes transactions sont rattachées à un compte, ce qui garde chaque '
        'solde à jour automatiquement.',
  ),
  _HelpSection(
    icon: Icons.swap_vert,
    title: 'Revenus & Dépenses',
    body: 'Enregistre chaque entrée/sortie d\'argent. Utilise la barre de recherche '
        'et les filtres (compte, catégorie, type) pour retrouver une transaction '
        'précise dans l\'historique.',
  ),
  _HelpSection(
    icon: Icons.autorenew,
    title: 'Transactions récurrentes',
    body: 'Pour un loyer, un salaire ou un abonnement qui revient chaque semaine, '
        'mois ou année : configure-le une fois, l\'app génère automatiquement la '
        'transaction à chaque échéance quand tu ouvres l\'app.',
  ),
  _HelpSection(
    icon: Icons.pie_chart_outline,
    title: 'Budgets',
    body: 'Fixe une limite de dépense par catégorie (ou globale) sur une période. '
        'Une notification t\'alerte automatiquement en cas de dépassement.',
  ),
  _HelpSection(
    icon: Icons.handshake_outlined,
    title: 'Dettes & Créances',
    body: 'Suis l\'argent que tu dois ("dette") ou qu\'on te doit ("créance"). '
        'Chaque paiement enregistré met à jour le solde du compte lié '
        'automatiquement. Un rappel est envoyé 3 jours avant l\'échéance.',
  ),
  _HelpSection(
    icon: Icons.credit_card_outlined,
    title: 'Crédits',
    body: 'Renseigne le capital, le taux et la durée : la mensualité est calculée '
        'automatiquement. Suis chaque échéance (payée ou à venir), avec des '
        'rappels 3 jours avant et le jour J.',
  ),
  _HelpSection(
    icon: Icons.savings_outlined,
    title: 'Épargne',
    body: 'Définis un objectif chiffré (facultatif) et suis ta progression à '
        'chaque versement ou retrait, avec l\'historique complet des mouvements.',
  ),
  _HelpSection(
    icon: Icons.landscape_outlined,
    title: 'Patrimoine & Bilans',
    body: 'Patrimoine : ajoute tes biens (immobilier, véhicule...) pour une vue '
        'globale de ta valeur nette. Bilans : visualise l\'évolution de ton '
        'patrimoine net et le rapport revenus/dépenses dans le temps.',
  ),
  _HelpSection(
    icon: Icons.lock_outline,
    title: 'Sécurité',
    body: 'Active un code PIN à 4 chiffres pour verrouiller l\'accès à l\'app. '
        'Sans biométrie obligatoire — le code marche même si le capteur '
        'd\'empreinte de ton téléphone est indisponible.',
  ),
  _HelpSection(
    icon: Icons.wifi_tethering,
    title: 'Synchronisation Wi-Fi',
    body: 'Transfère toutes tes données vers un autre appareil sur le même '
        'réseau Wi-Fi. Un code PIN généré à l\'écran protège le transfert : '
        'sans lui, personne d\'autre sur le réseau ne peut récupérer tes données.',
  ),
  _HelpSection(
    icon: Icons.ios_share_outlined,
    title: 'Export PDF / CSV',
    body: 'Génère un relevé de tes transactions sur la période de ton choix, à '
        'imprimer, archiver ou transmettre à un comptable.',
  ),
  _HelpSection(
    icon: Icons.backup_outlined,
    title: 'Sauvegarde & restauration',
    body: 'Exporte une copie de tes données vers l\'endroit de ton choix (Drive, '
        'clé USB...) comme filet de sécurité. Attention : ce fichier n\'est pas '
        'chiffré, garde-le dans un endroit que tu contrôles.',
  ),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mode d\'emploi')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final s = _sections[index];
          return ExpansionTile(
            leading: Icon(s.icon, color: Theme.of(context).colorScheme.primary),
            title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.body, style: const TextStyle(height: 1.4)),
            ],
          );
        },
      ),
    );
  }
}
