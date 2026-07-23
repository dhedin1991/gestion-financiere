import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/onboarding_providers.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String description;
  const _Slide({required this.icon, required this.title, required this.description});
}

const _slides = [
  _Slide(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Tous tes comptes au même endroit',
    description: 'Comptes, transactions, dettes, crédits, épargne et patrimoine : une vue complète de tes finances.',
  ),
  _Slide(
    icon: Icons.insights_outlined,
    title: 'Budgets et bilans clairs',
    description: 'Suis tes dépenses par catégorie et visualise l\'évolution de ton patrimoine net dans le temps.',
  ),
  _Slide(
    icon: Icons.notifications_active_outlined,
    title: 'Des rappels utiles',
    description: 'Échéances de crédit, dettes à rembourser, dépassements de budget : l\'app te prévient.',
  ),
  _Slide(
    icon: Icons.lock_outline,
    title: 'Tes données restent chez toi',
    description: 'Verrouillage par code PIN, sauvegardes manuelles, synchronisation locale — sans aucun serveur externe.',
  ),
];

class OnboardingPage extends ConsumerStatefulWidget {
  final VoidCallback onDone;

  const OnboardingPage({super.key, required this.onDone});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider).markSeen();
    widget.onDone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Passer'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon, size: 56, color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLast
                      ? _finish
                      : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                  child: Text(isLast ? 'Commencer' : 'Suivant'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
