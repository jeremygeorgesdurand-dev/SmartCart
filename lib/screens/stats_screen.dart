import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/suggestions_provider.dart';
import '../services/stats_service.dart';
import '../services/suggestions_service.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final suggestionsAsync = ref.watch(suggestionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(statsProvider);
              ref.invalidate(suggestionsProvider);
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Erreur : $e'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(statsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.refresh(statsProvider.future).then((_) {
            ref.invalidate(suggestionsProvider);
          }),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── À racheter bientôt ────────────────────────
              if (suggestionsAsync.valueOrNull?.isNotEmpty ?? false) ...[
                _TitreSection(
                  titre: 'À racheter bientôt',
                  icone: Icons.autorenew,
                  badge: '${suggestionsAsync.value!.length}',
                  badgeColor: Colors.deepOrange,
                ),
                const SizedBox(height: 8),
                _CarteSuggestions(suggestions: suggestionsAsync.value!),
                const SizedBox(height: 20),
              ],

              // ── Vue d'ensemble ──────────────────────────
              const _TitreSection(titre: 'Vue d\'ensemble', icone: Icons.dashboard),
              const SizedBox(height: 8),
              _CardsVueEnsemble(stats: stats),
              const SizedBox(height: 20),

              // ── Budget ────────────────────────────────────
              const _TitreSection(titre: 'Budget', icone: Icons.euro),
              const SizedBox(height: 8),
              const _CarteBudget(),
              const SizedBox(height: 20),

              // ── Activité courses ─────────────────────────
              const _TitreSection(titre: 'Activité des courses', icone: Icons.shopping_cart),
              const SizedBox(height: 8),
              _CarteActivite(stats: stats),
              const SizedBox(height: 20),

              // ── Top articles ─────────────────────────────
              if (stats.topArticles.isNotEmpty) ...[
                _TitreSection(
                  titre: 'Articles les plus achetés',
                  icone: Icons.star,
                  badge: 'Top ${stats.topArticles.length}',
                ),
                const SizedBox(height: 8),
                _CarteTopArticles(items: stats.topArticles),
                const SizedBox(height: 20),
              ],

              // ── Catégories ────────────────────────────────
              if (stats.topCategories.isNotEmpty) ...[
                const _TitreSection(titre: 'Par catégorie maison', icone: Icons.home),
                const SizedBox(height: 8),
                _CarteBarres(
                  items: stats.topCategories
                      .map((e) => _BarItem(
                            label: e.categorie.nom,
                            value: e.count.toDouble(),
                            color: Color(e.categorie.couleur),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // ── Rayons ────────────────────────────────────
              if (stats.topRayons.isNotEmpty) ...[
                const _TitreSection(titre: 'Par rayon magasin', icone: Icons.store),
                const SizedBox(height: 8),
                _CarteBarres(
                  items: stats.topRayons
                      .map((e) => _BarItem(
                            label: e.rayon.nom,
                            value: e.count.toDouble(),
                            color: Color(e.rayon.couleur),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
              ],

              // ── Articles jamais utilisés ──────────────────
              if (stats.articlesSansListe.isNotEmpty) ...[
                _TitreSection(
                  titre: 'Jamais ajoutés à une liste',
                  icone: Icons.inventory_2_outlined,
                  badge: '${stats.articlesSansListe.length}',
                  badgeColor: Colors.orange,
                ),
                const SizedBox(height: 8),
                _CarteArticlesInutilises(articles: stats.articlesSansListe),
                const SizedBox(height: 20),
              ],

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Titre de section ──────────────────────────────────────────────
class _TitreSection extends StatelessWidget {
  final String titre;
  final IconData icone;
  final String? badge;
  final Color? badgeColor;

  const _TitreSection({
    required this.titre,
    required this.icone,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(titre,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (badgeColor ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: badgeColor ?? Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── 4 chiffres clés ───────────────────────────────────────────────
class _CardsVueEnsemble extends StatelessWidget {
  final StatsData stats;
  const _CardsVueEnsemble({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _MiniCard(
          icone: Icons.inventory_2,
          valeur: '${stats.totalArticles}',
          label: 'Articles\ncatalogue',
          color: Theme.of(context).colorScheme.primary,
        ),
        _MiniCard(
          icone: Icons.shopping_cart,
          valeur: '${stats.totalListes}',
          label: 'Listes\nactives',
          color: Colors.green,
        ),
        _MiniCard(
          icone: Icons.calendar_today,
          valeur: '${stats.articlesAchetesCeMois}',
          label: 'Articles\nce mois',
          color: Colors.orange,
        ),
        _MiniCard(
          icone: Icons.archive_outlined,
          valeur: '${stats.totalListesArchivees}',
          label: 'Listes\narchivées',
          color: Colors.blueGrey,
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icone;
  final String valeur;
  final String label;
  final Color color;

  const _MiniCard({
    required this.icone,
    required this.valeur,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(valeur,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: color,
                          )),
                  Text(label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                            height: 1.2,
                          )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Budget : total estimé des listes actives + couverture des prix ──
class _CarteBudget extends ConsumerWidget {
  const _CarteBudget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listes =
        ref.watch(listesNotifierProvider).valueOrNull?.where((l) => !l.archivee).toList() ??
            [];
    final articles = ref.watch(articlesNotifierProvider).valueOrNull ?? [];
    final prix = ref.watch(prixArticlesNotifierProvider).valueOrNull ?? [];

    final totalGeneral = listes.fold<double>(
        0, (s, l) => s + ref.watch(totalListeProvider(l.id)));
    final articlesAvecPrix =
        articles.map((a) => a.id).toSet().intersection(
            prix.map((p) => p.articleId).toSet());
    final couverture = articles.isEmpty
        ? 0.0
        : articlesAvecPrix.length / articles.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.euro, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Total estimé (listes actives)',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                Text(
                  '${totalGeneral.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: couverture,
                      minHeight: 6,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(couverture * 100).round()}% des articles ont un prix',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte activité + taux de complétion ──────────────────────────
class _CarteActivite extends StatelessWidget {
  final StatsData stats;
  const _CarteActivite({required this.stats});

  @override
  Widget build(BuildContext context) {
    final taux = stats.tauxCompletionMoyen;
    final color = taux >= 80
        ? Colors.green
        : taux >= 50
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Taux de complétion moyen',
                    style: Theme.of(context).textTheme.bodyMedium),
                const Spacer(),
                Text(
                  '${taux.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: taux / 100,
                minHeight: 10,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _messageCompletion(taux),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _messageCompletion(double taux) {
    if (taux == 0) return 'Aucune liste complétée pour l\'instant';
    if (taux >= 90) return 'Excellent ! Vous finissez presque toutes vos courses.';
    if (taux >= 70) return 'Très bien, quelques articles restent parfois non cochés.';
    if (taux >= 50) return 'La moitié des articles sont cochés en moyenne.';
    return 'Beaucoup d\'articles restent non cochés — pensez à nettoyer vos listes.';
  }
}

// ── Top articles avec podium ──────────────────────────────────────
class _CarteTopArticles extends StatelessWidget {
  final List<({dynamic article, int count})> items;
  const _CarteTopArticles({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxCount = items.first.count;

    return Card(
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final ratio = maxCount > 0 ? item.count / maxCount : 0.0;

          Color rangColor;
          IconData? rangIcon;
          if (i == 0) { rangColor = Colors.amber; rangIcon = Icons.emoji_events; }
          else if (i == 1) { rangColor = Colors.grey; rangIcon = Icons.emoji_events; }
          else if (i == 2) { rangColor = Colors.brown.shade300; rangIcon = Icons.emoji_events; }
          else { rangColor = Theme.of(context).colorScheme.outline; rangIcon = null; }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: rangIcon != null
                      ? Icon(rangIcon, color: rangColor, size: 18)
                      : Text('${i + 1}',
                          style: TextStyle(
                              color: rangColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.article.nom,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 4,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '×${item.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Barres horizontales ───────────────────────────────────────────
class _BarItem {
  final String label;
  final double value;
  final Color color;
  const _BarItem({required this.label, required this.value, required this.color});
}

class _CarteBarres extends StatelessWidget {
  final List<_BarItem> items;
  const _CarteBarres({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxVal = items.isEmpty
        ? 1.0
        : items.map((i) => i.value).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: items.map((item) {
            final ratio = item.value / maxVal;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(item.label,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 16,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(item.color.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${item.value.toInt()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Articles jamais utilisés ──────────────────────────────────────
class _CarteArticlesInutilises extends StatelessWidget {
  final List<dynamic> articles;
  const _CarteArticlesInutilises({required this.articles});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ...articles.take(5).map((a) => ListTile(
                dense: true,
                leading: Icon(Icons.circle_outlined,
                    color: Theme.of(context).colorScheme.outline, size: 16),
                title: Text(a.nom),
                subtitle: a.marque != null ? Text(a.marque!) : null,
              )),
          if (articles.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '+ ${articles.length - 5} autres',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

// ── À racheter bientôt ─────────────────────────────────────────────
class _CarteSuggestions extends ConsumerWidget {
  final List<SuggestionReassort> suggestions;
  const _CarteSuggestions({required this.suggestions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Column(
        children: suggestions.map((s) {
          return ListTile(
            leading: Icon(Icons.shopping_cart_checkout,
                color: Theme.of(context).colorScheme.primary),
            title: Text(s.article.nom),
            subtitle: Text(
              'En retard de ${s.joursRetard} jour${s.joursRetard > 1 ? 's' : ''}'
              ' · habituellement tous les ${s.intervalleMoyenJours.round()} jours',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Ajouter à une liste',
              onPressed: () => _ajouterSuggestion(context, ref, s.article),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _ajouterSuggestion(
      BuildContext context, WidgetRef ref, Article article) async {
    final listesActives = (ref.read(listesNotifierProvider).valueOrNull ?? [])
        .where((l) => !l.archivee)
        .toList();

    if (listesActives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Créez d\'abord une liste de courses'),
      ));
      return;
    }

    ListeCourses? cible = listesActives.length == 1
        ? listesActives.first
        : await showModalBottomSheet<ListeCourses>(
            context: context,
            builder: (ctx) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: listesActives
                    .map((l) => ListTile(
                          leading: const Icon(Icons.shopping_cart),
                          title: Text(l.nom),
                          onTap: () => Navigator.of(ctx).pop(l),
                        ))
                    .toList(),
              ),
            ),
          );

    if (cible == null || !context.mounted) return;

    final itemsExistants =
        await ref.read(dbServiceProvider).getArticlesListe(cible.id);
    if (itemsExistants.any((i) => i.articleId == article.id)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${article.nom}" est déjà dans "${cible.nom}"'),
        ));
      }
      return;
    }

    await ref.read(articlesListeProvider(cible.id).notifier).ajouter(
          ArticleListe(
            id: 'al_${const Uuid().v4()}',
            listeId: cible.id,
            articleId: article.id,
          ),
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${article.nom}" ajouté à "${cible.nom}"'),
        backgroundColor: Colors.green,
      ));
    }
  }
}
