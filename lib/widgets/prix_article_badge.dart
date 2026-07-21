import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

// Affiche le prix d'un article : le prix saisi/confirmé par l'utilisateur
// en priorité (le moins cher connu), sinon un prix indicatif récupéré en
// ligne (Open Prices), affiché en italique pour marquer la différence.
// Ne s'affiche pas tant qu'aucune information n'est disponible.
class PrixArticleBadge extends ConsumerWidget {
  final Article article;
  const PrixArticleBadge({super.key, required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(afficherPrixProvider)) return const SizedBox.shrink();

    final prixConfirmes = ref
            .watch(prixArticlesNotifierProvider)
            .valueOrNull
            ?.where((p) => p.articleId == article.id)
            .toList() ??
        [];

    if (prixConfirmes.isNotEmpty) {
      final moinsCher =
          prixConfirmes.reduce((a, b) => a.prix <= b.prix ? a : b);
      return Text(
        '${moinsCher.prix.toStringAsFixed(2)} €',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );
    }

    final indicatif = ref.watch(prixIndicatifProvider(article)).valueOrNull;
    if (indicatif == null) return const SizedBox.shrink();

    return Text(
      '~${indicatif.prix.toStringAsFixed(2)} €',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
    );
  }
}
