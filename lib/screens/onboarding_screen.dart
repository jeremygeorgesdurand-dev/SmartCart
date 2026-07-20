import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onTermine;
  const OnboardingScreen({super.key, required this.onTermine});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.shopping_cart_outlined,
      titre: 'Bienvenue sur SmartCart',
      texte: "Organise tes courses par catégories et par rayon de magasin, "
          "pour ne plus jamais revenir sur tes pas dans les allées.",
    ),
    (
      icon: Icons.mic_none_outlined,
      titre: 'Ajoute vite, ajoute bien',
      texte: 'Saisis un article à la voix ou scanne son code-barres : '
          'SmartCart retrouve son nom et sa marque automatiquement.',
    ),
    (
      icon: Icons.group_outlined,
      titre: 'Fais tes courses à plusieurs',
      texte: 'Rends une liste collaborative et partage un code à 6 '
          'caractères : chacun voit les ajouts des autres en temps réel.',
    ),
    (
      icon: Icons.widgets_outlined,
      titre: 'Toujours sous la main',
      texte: "Ajoute le widget SmartCart à l'écran d'accueil de ton "
          'téléphone pour cocher tes articles sans ouvrir l\'app.',
    ),
  ];

  Future<void> _terminer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_vu', true);
    widget.onTermine();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dernierePage = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: _terminer,
                  child: const Text('Passer'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(slide.icon,
                              size: 56,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.titre,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.texte,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: dernierePage
                      ? _terminer
                      : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                  child: Text(dernierePage ? 'Commencer' : 'Suivant'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
