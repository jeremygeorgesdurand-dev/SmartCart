import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/open_prices_service.dart';
import '../utils/erreur_utils.dart';
import '../utils/theme_utils.dart';
import 'historique_prix_screen.dart';
import 'scanner_ticket_screen.dart';
import 'stats_screen.dart';

// ================================================================
// ÉCRAN BUDGET — prix estimés des articles + suivi des dépenses
// réelles (uniquement les articles effectivement cochés/achetés)
// ================================================================
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articlesNotifierProvider);
    final listesAsync = ref.watch(listesNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Prix depuis un ticket de caisse',
            onPressed: () async {
              final msg = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const ScannerTicketScreen()),
              );
              if (msg != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(msg),
                  backgroundColor: couleurSucces(context),
                ));
              }
            },
          ),
        ],
      ),
      body: articlesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text(messageErreurLisible(e, 'Erreur'))),
        data: (articles) {
          if (articles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.euro_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Aucun article dans le catalogue',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Ajoute des articles pour suivre leur prix'),
                ],
              ),
            );
          }

          final prixAsync = ref.watch(prixArticlesNotifierProvider);
          final prix = prixAsync.valueOrNull ?? [];
          final prixParArticle = <String, List<PrixArticle>>{};
          for (final p in prix) {
            (prixParArticle[p.articleId] ??= []).add(p);
          }
          final tries = [...articles]
            ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              listesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (listes) {
                  // Seules les listes ayant au moins un article coché
                  // comptent ici : le budget doit refléter ce qui a
                  // vraiment été acheté, pas simplement ce qui est prévu
                  // sur une liste pas encore faite.
                  final avecAchats = listes.where((l) {
                    final items =
                        ref.watch(articlesListeProvider(l.id)).valueOrNull ??
                            [];
                    return items.any((i) => i.coche);
                  }).toList();
                  if (avecAchats.isEmpty) {
                    return Text('Aucun achat effectué pour l\'instant',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline));
                  }
                  // Le total apparaît maintenant AVANT le détail par liste :
                  // c'est le chiffre que l'utilisateur vient chercher en
                  // premier sur cet écran, pas un résultat à déduire en
                  // additionnant les cartes une par une plus bas.
                  final totalGlobal = avecAchats.fold<double>(0,
                      (sum, l) => sum + ref.watch(totalListeCochesProvider(l.id)));
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ResumeBudgetCard(
                          total: totalGlobal, nbListes: avecAchats.length),
                      const SizedBox(height: 20),
                      Text('Par liste',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...avecAchats.map((liste) => _ListeTotalTile(liste: liste)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              // Repliable : le catalogue peut compter des dizaines d'articles ;
              // on les regroupe sous un en-tête dépliable plutôt que de tout
              // dérouler (l'écran devenait interminable).
              Card(
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: const Icon(Icons.sell_outlined),
                  title: const Text('Prix des articles'),
                  subtitle: Text('${tries.length} article(s) — '
                      'appuie pour déplier'),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final a in tries)
                      _ArticlePrixTile(
                          article: a, prix: prixParArticle[a.id] ?? const []),
                  ],
                ),
              ),

              // ── Statistiques (fusionnées ici depuis l'ancien onglet Stats) ──
              const SizedBox(height: 28),
              Row(
                children: [
                  Icon(Icons.insights_outlined,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Statistiques',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 12),
              const StatsContenu(masquerBudget: true),
            ],
          );
        },
      ),
    );
  }
}

// Le chiffre qu'on vient chercher en premier sur cet écran : le total
// toutes listes actives confondues, mis en avant avant le détail
// liste par liste (qui reste plus bas pour qui veut le détail).
class _ResumeBudgetCard extends StatelessWidget {
  final double total;
  final int nbListes;
  const _ResumeBudgetCard({required this.total, required this.nbListes});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nbListes > 1
                ? 'Dépensé sur $nbListes listes'
                : 'Dépensé sur cette liste',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 6),
          Text(
            '${total.toStringAsFixed(2)} €',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer,
                ),
          ),
        ],
      ),
    );
  }
}

class _ListeTotalTile extends ConsumerWidget {
  final ListeCourses liste;
  const _ListeTotalTile({required this.liste});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalListeCochesProvider(liste.id));
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.shopping_cart_outlined),
        title: Text(liste.nom),
        trailing: Text(
          '${total.toStringAsFixed(2)} €',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _ArticlePrixTile extends ConsumerWidget {
  final Article article;
  final List<PrixArticle> prix;
  const _ArticlePrixTile({required this.article, required this.prix});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tries = [...prix]..sort((a, b) => a.prix.compareTo(b.prix));
    final moinsCher = tries.firstOrNull;

    // Tant qu'aucun prix n'a été saisi/confirmé pour cet article, on va
    // chercher discrètement un prix indicatif en ligne (Open Prices) pour
    // donner un ordre de grandeur sans obliger à tout remplir à la main.
    final indicatifAsync =
        tries.isEmpty ? ref.watch(prixIndicatifProvider(article)) : null;
    final indicatif = indicatifAsync?.valueOrNull;

    return ExpansionTile(
      title: Text(article.nom),
      subtitle: tries.length > 1 ? Text('${tries.length} magasins comparés') : null,
      trailing: tries.isEmpty && indicatif != null
          ? Text(
              '~${indicatif.prix.toStringAsFixed(2)} €',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic),
            )
          : null,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        if (tries.isEmpty && indicatif != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.travel_explore,
                    size: 18, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prix indicatif : ${indicatif.prix.toStringAsFixed(2)} €',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => _editerPrix(context, ref,
                      prixSuggere: indicatif.prix),
                  child: const Text('Utiliser'),
                ),
              ],
            ),
          ),
        for (final p in tries)
          ListTile(
            dense: true,
            leading: Semantics(
              label: p == moinsCher && tries.length > 1 ? 'Moins cher' : null,
              child: Icon(
                p == moinsCher && tries.length > 1
                    ? Icons.star
                    : Icons.storefront_outlined,
                size: 18,
                color: p == moinsCher && tries.length > 1
                    ? couleurAvertissement(context)
                    : null,
              ),
            ),
            title: Text(p.magasin.isEmpty ? 'Prix générique' : p.magasin),
            trailing: TextButton(
              onPressed: () => _editerPrix(context, ref, magasin: p.magasin, prixActuel: p.prix),
              child: Text('${p.prix.toStringAsFixed(2)} €'),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _editerPrix(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un prix (magasin)'),
              ),
              if (tries.isNotEmpty)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoriquePrixScreen(article: article),
                    ),
                  ),
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Voir l\'évolution'),
                ),
              TextButton.icon(
                onPressed: () => _chercherEnLigne(context, ref),
                icon: const Icon(Icons.travel_explore, size: 18),
                label: const Text('Chercher en ligne'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _chercherEnLigne(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // La plupart des articles ajoutés à la main (ajout rapide, dictée
    // vocale) n'ont pas de code-barres : on tente de retrouver le produit
    // par son nom via Open Food Facts pour en récupérer un avant de
    // chercher ses prix.
    // 1) Prix par magasin pour CE produit précis (si un code-barres est
    //    connu ou retrouvable par nom) — c'est le plus précis quand ça existe.
    var barcode = article.barcode;
    if (barcode == null) {
      final suggestions =
          await ref.read(offServiceProvider).searchByName(article.nom);
      barcode = suggestions.where((a) => a.barcode != null).firstOrNull?.barcode;
    }
    final resultats = barcode == null
        ? <PrixTrouve>[]
        : await ref
            .read(openPricesServiceProvider)
            .chercherParBarcode(barcode);

    // 2) Repli robuste : aucune donnée pour ce produit précis → on estime à
    //    partir de la MOYENNE de plusieurs produits similaires (même logique
    //    que le prix indicatif automatique). Bien plus fiable qu'un seul
    //    code-barres, ce qui évitait d'avoir à réappuyer plusieurs fois.
    if (resultats.isEmpty) {
      // refresh (et non read) : on force une nouvelle recherche à chaque
      // appui plutôt que de renvoyer un éventuel résultat en cache.
      final estime = await ref.refresh(prixParNomProvider(article.nom).future);
      if (!context.mounted) return;
      Navigator.pop(context); // ferme le loader
      if (estime != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Prix estimé : ${estime.prix.toStringAsFixed(2)} € '
              '(${estime.magasin})'),
          action: SnackBarAction(
            label: 'Utiliser',
            onPressed: () => _editerPrix(context, ref, prixSuggere: estime.prix),
          ),
          duration: const Duration(seconds: 6),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aucun prix trouvé en ligne pour ce produit '
              '(base communautaire Open Prices)'),
        ));
      }
      return;
    }

    if (!context.mounted) return;
    Navigator.pop(context); // ferme le loader

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prix trouvés pour ${article.nom}',
                  style: Theme.of(sheetCtx).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Source : Open Prices (communautaire, Open Food Facts)',
                  style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetCtx).colorScheme.outline)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in resultats)
                      ListTile(
                        title: Text(r.magasin),
                        subtitle: r.date != null
                            ? Text('Relevé le '
                                '${r.date!.day.toString().padLeft(2, '0')}/'
                                '${r.date!.month.toString().padLeft(2, '0')}/'
                                '${r.date!.year}')
                            : null,
                        trailing: Text('${r.prix.toStringAsFixed(2)} ${r.devise}'),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _editerPrix(context, ref,
                              magasin: r.magasin, prixSuggere: r.prix);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editerPrix(
    BuildContext context,
    WidgetRef ref, {
    String magasin = '',
    double? prixActuel,
    double? prixSuggere,
  }) {
    final ctrlPrix = TextEditingController(
      text: prixActuel != null
          ? prixActuel.toStringAsFixed(2)
          : (prixSuggere != null ? prixSuggere.toStringAsFixed(2) : ''),
    );
    final ctrlMagasin = TextEditingController(text: magasin);
    final estNouveau = prixActuel == null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        scrollable: true,
        title: Text('Prix de ${article.nom}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrlMagasin,
              enabled: estNouveau,
              decoration: const InputDecoration(
                  labelText: 'Magasin (optionnel)', hintText: 'Ex: Carrefour'),
              maxLength: 40,
            ),
            TextField(
              controller: ctrlPrix,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: '€'),
            ),
          ],
        ),
        actions: [
          if (!estNouveau)
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: couleurDanger(context)),
              onPressed: () {
                ref
                    .read(prixArticlesNotifierProvider.notifier)
                    .supprimer(article.id, magasin: magasin);
                Navigator.pop(context);
              },
              child: const Text('Supprimer'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final valeur = double.tryParse(ctrlPrix.text.replaceAll(',', '.'));
              if (valeur != null && valeur >= 0) {
                ref.read(prixArticlesNotifierProvider.notifier).definir(
                      article.id,
                      valeur,
                      magasin: ctrlMagasin.text.trim(),
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
