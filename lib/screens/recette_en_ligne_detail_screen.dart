import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../providers/recettes_en_ligne_provider.dart';
import '../services/spoonacular_service.dart';
import '../utils/erreur_utils.dart';
import '../utils/theme_utils.dart';
import 'listes_screen.dart';

// ================================================================
// DÉTAIL D'UNE RECETTE EN LIGNE — étapes, ingrédients, nutrition,
// et génération d'une liste de courses avec prix estimé.
// ================================================================
class RecetteEnLigneDetailScreen extends ConsumerWidget {
  final int id;
  const RecetteEnLigneDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(detailRecetteProvider(id));

    return Scaffold(
      body: detail.when(
        loading: () => const _CharementDetail(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(messageErreurLisible(e, 'Erreur'),
                  textAlign: TextAlign.center),
            ),
          ),
        ),
        data: (recette) => _Contenu(recette: recette),
      ),
    );
  }
}

class _CharementDetail extends StatelessWidget {
  const _CharementDetail();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
}

class _Contenu extends ConsumerWidget {
  final RecetteEnLigne recette;
  const _Contenu({required this.recette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: recette.image != null ? 220 : 0,
          pinned: true,
          flexibleSpace: recette.image == null
              ? null
              : FlexibleSpaceBar(
                  background: Image.network(
                    recette.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recette.titre,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                _Infos(recette: recette),
                const SizedBox(height: 20),

                _BoutonCreerListe(recette: recette),
                const SizedBox(height: 24),

                Text('Ingrédients',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${recette.portions} portions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 8),
                for (final ing in recette.ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: Icon(Icons.circle,
                              size: 7,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        Expanded(child: Text(_libelleIngredient(ing))),
                      ],
                    ),
                  ),

                if (recette.etapes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Préparation',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (var i = 0; i < recette.etapes.length; i++)
                    _Etape(numero: i + 1, texte: recette.etapes[i]),
                ],

                const SizedBox(height: 24),
                Text(
                  'Recette fournie par Spoonacular, traduite automatiquement. '
                  'La traduction et les quantités peuvent comporter des '
                  'approximations.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _libelleIngredient(IngredientEnLigne ing) {
    final q = ing.quantite;
    final qTexte = q == q.roundToDouble()
        ? q.round().toString()
        : q.toStringAsFixed(1);
    final unite = ing.unite != null ? ' ${ing.unite}' : '';
    return '$qTexte$unite ${ing.nom}'.trim();
  }
}

class _Infos extends StatelessWidget {
  final RecetteEnLigne recette;
  const _Infos({required this.recette});

  @override
  Widget build(BuildContext context) {
    final puces = <Widget>[
      if (recette.tempsMinutes != null)
        _Puce(icone: Icons.schedule, texte: '${recette.tempsMinutes} min'),
      if (recette.calories != null)
        _Puce(
            icone: Icons.local_fire_department,
            texte: '${recette.calories} kcal/pers.'),
      if (recette.proteines != null)
        _Puce(
            icone: Icons.fitness_center,
            texte: '${recette.proteines} g protéines'),
      if (recette.vegetarien == true)
        const _Puce(icone: Icons.eco, texte: 'Végétarien'),
      if (recette.sansGluten == true)
        const _Puce(icone: Icons.spa, texte: 'Sans gluten'),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: puces);
  }
}

class _Puce extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _Puce({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone,
              size: 15,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 5),
          Text(texte,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  final int numero;
  final String texte;
  const _Etape({required this.numero, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Text('$numero',
                style: TextStyle(
                    color: texteContrastant(
                        Theme.of(context).colorScheme.primary),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(texte, style: const TextStyle(height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonCreerListe extends ConsumerStatefulWidget {
  final RecetteEnLigne recette;
  const _BoutonCreerListe({required this.recette});

  @override
  ConsumerState<_BoutonCreerListe> createState() => _BoutonCreerListeState();
}

class _BoutonCreerListeState extends ConsumerState<_BoutonCreerListe> {
  bool _generation = false;

  Future<void> _creer() async {
    setState(() => _generation = true);
    final recetteEnLigne = widget.recette;

    // Convertit la recette en ligne en Recette locale pour réutiliser la
    // génération de liste existante (matching catalogue + prix estimés).
    final recetteLocale = Recette(
      id: 'recette_en_ligne_${recetteEnLigne.id}',
      nom: recetteEnLigne.titre,
      portions: recetteEnLigne.portions,
      ingredients: recetteEnLigne.ingredients
          .map((i) => IngredientRecette(
                nom: i.nom,
                quantite: i.quantite < 1 ? 1 : i.quantite.round(),
                unite: i.unite,
              ))
          .toList(),
    );

    // On crée la liste nous-mêmes pour connaître son id et pouvoir y
    // naviguer (genererListe ne renvoie que des compteurs).
    final liste = ListeCourses(
      id: 'liste_${DateTime.now().millisecondsSinceEpoch}',
      nom: recetteLocale.nom,
    );
    try {
      await ref.read(listesNotifierProvider.notifier).ajouter(liste);
      final (reussis, total) = await ref
          .read(recettesNotifierProvider.notifier)
          .genererListe(recetteLocale, listeIdExistante: liste.id);
      if (!mounted) return;
      final incomplet = reussis < total;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(incomplet
            ? 'Liste créée, $reussis/$total ingrédient(s) ajoutés'
            : 'Liste créée avec $total ingrédient(s)'),
        backgroundColor:
            incomplet ? couleurAvertissement(context) : couleurSucces(context),
      ));
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailListeScreen(liste: liste)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(messageErreurLisible(e, 'Une erreur est survenue'))));
      }
    } finally {
      if (mounted) setState(() => _generation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _generation ? null : _creer,
        icon: _generation
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary))
            : const Icon(Icons.add_shopping_cart),
        label: Text(_generation
            ? 'Création en cours…'
            : 'Créer une liste de courses (prix estimé)'),
      ),
    );
  }
}
