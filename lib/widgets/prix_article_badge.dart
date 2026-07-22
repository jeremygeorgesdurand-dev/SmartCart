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

    final indicatifAsync = ref.watch(prixIndicatifProvider(article));
    final indicatif = indicatifAsync.valueOrNull;

    if (indicatif != null) {
      return Text(
        '~${indicatif.prix.toStringAsFixed(2)} €',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
      );
    }

    // Recherche en cours : un petit indicateur évite de confondre "en train
    // de chercher" avec "rien trouvé" (les deux étaient visuellement
    // identiques — un vide — ce qui donnait l'impression que rien ne se
    // passait pour beaucoup d'articles).
    if (indicatifAsync.isLoading) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
