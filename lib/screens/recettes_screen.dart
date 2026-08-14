import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/vocal_service.dart';
import '../utils/erreur_utils.dart';
import '../utils/theme_utils.dart';
import 'frigo_screen.dart';
import 'recettes_en_ligne_screen.dart';

// ================================================================
// ÉCRAN RECETTES — une page à barre fixe avec 3 sous-onglets (Explorer /
// Mon frigo / Mes recettes). Le contenu glisse sous la barre (transition
// nette, trait qui suit le doigt) ; aux BORDS (glissement au-delà du 1er
// ou du dernier sous-onglet), on passe le relais au défilement principal
// via onDeborderGauche/onDeborderDroite pour continuer vers l'écran voisin.
// ================================================================
class RecettesScreen extends StatefulWidget {
  final VoidCallback? onDeborderGauche;
  final VoidCallback? onDeborderDroite;
  const RecettesScreen({
    super.key,
    this.onDeborderGauche,
    this.onDeborderDroite,
  });

  @override
  State<RecettesScreen> createState() => _RecettesScreenState();
}

class _RecettesScreenState extends State<RecettesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));
  // Évite de déclencher plusieurs fois le passage de relais pendant un même
  // geste (l'overscroll émet en continu tant que le doigt pousse le bord).
  bool _relaisDeclenche = false;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    // On ne relaie que l'overscroll HORIZONTAL (celui du TabBarView aux bords
    // gauche/droite). Sans ce filtre, arriver en bas d'une liste de recettes
    // émettait un overscroll VERTICAL qui, sur le dernier sous-onglet,
    // déclenchait à tort le passage à l'écran voisin (Budget) : défiler vers
    // le bas « sautait » de page.
    if (n is OverscrollNotification &&
        n.metrics.axis == Axis.horizontal &&
        !_relaisDeclenche) {
      if (n.overscroll < 0 && _tab.index == 0) {
        _relaisDeclenche = true;
        widget.onDeborderGauche?.call();
      } else if (n.overscroll > 0 && _tab.index == _tab.length - 1) {
        _relaisDeclenche = true;
        widget.onDeborderDroite?.call();
      }
    } else if (n is ScrollEndNotification) {
      _relaisDeclenche = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recettes'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Explorer'),
            Tab(text: 'Mon frigo'),
            Tab(text: 'Mes recettes'),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecetteFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle recette'),
            )
          : null,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: TabBarView(
          controller: _tab,
          children: const [
            ExplorerRecettesTab(),
            FrigoTab(),
            MesRecettesTab(),
          ],
        ),
      ),
    );
  }
}

// Onglet "Mes recettes" : les recettes perso enregistrées localement.
class MesRecettesTab extends ConsumerWidget {
  const MesRecettesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recettesAsync = ref.watch(recettesNotifierProvider);
    return recettesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(messageErreurLisible(e, 'Erreur'))),
      data: (recettes) {
        if (recettes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Aucune recette enregistrée'),
                  const SizedBox(height: 8),
                  Text(
                    'Crée-en une avec le bouton « Nouvelle recette », ou '
                    'depuis l\'onglet Explorer.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: recettes.length,
          itemBuilder: (_, i) {
            final r = recettes[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(r.nom),
                subtitle: Text(
                    '${r.ingredients.length} ingrédient(s) · ${r.portions} portions'),
                onTap: () => _ouvrirDetail(context, r),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'modifier':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecetteFormScreen(recette: r)),
                        );
                      case 'supprimer':
                        ref
                            .read(recettesNotifierProvider.notifier)
                            .supprimer(r.id);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                    PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _ouvrirDetail(BuildContext context, Recette r) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _RecetteDetailSheet(recette: r),
    );
  }
}

// ================================================================
// DÉTAIL D'UNE RECETTE + GÉNÉRER LA LISTE
// ================================================================
class _RecetteDetailSheet extends ConsumerWidget {
  final Recette recette;
  const _RecetteDetailSheet({required this.recette});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recette.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  recette.imageUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(recette.nom, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${recette.portions} portions',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Text('Ingrédients',
                style: Theme.of(context).textTheme.titleMedium),
            for (final ing in recette.ingredients)
              ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 8),
                title: Text(ing.nom),
                trailing: Text(ing.unite != null
                    ? '${ing.quantite} ${ing.unite}'
                    : '${ing.quantite}'),
              ),
            if (recette.etapes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Préparation',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (var i = 0; i < recette.etapes.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: texteContrastant(
                                    Theme.of(context).colorScheme.primary),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(recette.etapes[i],
                              style: const TextStyle(height: 1.35)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            _BoutonGenererListe(recette: recette),
          ],
        ),
      ),
    );
  }
}

class _BoutonGenererListe extends ConsumerStatefulWidget {
  final Recette recette;
  const _BoutonGenererListe({required this.recette});

  @override
  ConsumerState<_BoutonGenererListe> createState() =>
      _BoutonGenererListeState();
}

class _BoutonGenererListeState extends ConsumerState<_BoutonGenererListe> {
  bool generation = false;

  @override
  Widget build(BuildContext context) {
    final recette = widget.recette;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: generation
            ? null
            : () async {
                setState(() => generation = true);
                (int, int) resultat;
                try {
                  resultat = await ref
                      .read(recettesNotifierProvider.notifier)
                      .genererListe(recette);
                } catch (e) {
                  if (context.mounted) {
                    setState(() => generation = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              messageErreurLisible(e, 'Une erreur est survenue'))),
                    );
                  }
                  return;
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  final (reussis, total) = resultat;
                  final incomplet = reussis < total;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(incomplet
                        ? 'Liste "${recette.nom}" créée, mais seulement $reussis/$total ingrédient(s) ajoutés — vérifie la liste'
                        : 'Liste "${recette.nom}" créée avec $total ingrédient(s)'),
                    backgroundColor: incomplet
                        ? couleurAvertissement(context)
                        : couleurSucces(context),
                  ));
                }
              },
        icon: generation
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary))
            : const Icon(Icons.shopping_cart_outlined),
        label: Text(generation
            ? 'Génération en cours…'
            : 'Générer une liste de courses'),
      ),
    );
  }
}

// ================================================================
// FORMULAIRE CRÉATION / ÉDITION D'UNE RECETTE
// ================================================================
class RecetteFormScreen extends ConsumerStatefulWidget {
  final Recette? recette;
  const RecetteFormScreen({super.key, this.recette});

  @override
  ConsumerState<RecetteFormScreen> createState() => _RecetteFormScreenState();
}

class _RecetteFormScreenState extends ConsumerState<RecetteFormScreen> {
  late final TextEditingController _nomCtrl;
  late int _portions;
  late List<_LigneIngredient> _lignes;
  // Étapes et image conservées telles quelles (renseignées à l'import ou sur
  // une recette existante) : pas encore éditables champ par champ, mais
  // affichées et sauvegardées avec la recette.
  List<String> _etapes = [];
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    final r = widget.recette;
    _nomCtrl = TextEditingController(text: r?.nom ?? '');
    _portions = r?.portions ?? 4;
    _etapes = r?.etapes ?? [];
    _imageUrl = r?.imageUrl;
    _lignes = r != null && r.ingredients.isNotEmpty
        ? r.ingredients
            .map((i) => _LigneIngredient(
                nom: TextEditingController(text: i.nom),
                quantite: TextEditingController(text: '${i.quantite}'),
                unite: TextEditingController(text: i.unite ?? '')))
            .toList()
        : [_LigneIngredient.vide()];
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    for (final l in _lignes) {
      l.nom.dispose();
      l.quantite.dispose();
      l.unite.dispose();
    }
    super.dispose();
  }

  void _enregistrer() {
    final nom = _nomCtrl.text.trim();
    if (nom.isEmpty) return;

    final ingredients = _lignes
        .map((l) => (
              nom: l.nom.text.trim(),
              quantite: int.tryParse(l.quantite.text.trim()) ?? 1,
              unite: l.unite.text.trim(),
            ))
        .where((i) => i.nom.isNotEmpty)
        .map((i) => IngredientRecette(
            nom: i.nom, quantite: i.quantite, unite: i.unite.isEmpty ? null : i.unite))
        .toList();

    final recette = Recette(
      id: widget.recette?.id ?? 'recette_${DateTime.now().millisecondsSinceEpoch}',
      nom: nom,
      portions: _portions,
      ingredients: ingredients,
      etapes: _etapes,
      imageUrl: _imageUrl,
    );

    final notifier = ref.read(recettesNotifierProvider.notifier);
    if (widget.recette == null) {
      notifier.ajouter(recette);
    } else {
      notifier.modifier(recette);
    }
    Navigator.pop(context);
  }

  bool _import = false;

  Future<void> _importerDepuisUrl() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Importer depuis une URL'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://www.marmiton.org/recettes/...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;

    setState(() => _import = true);
    final recette =
        await ref.read(recipeImportServiceProvider).importerDepuisUrl(url);
    if (!mounted) return;
    setState(() => _import = false);

    if (recette == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            "Impossible de récupérer cette recette (site non compatible ou page invalide)"),
      ));
      return;
    }

    setState(() {
      _nomCtrl.text = recette.nom;
      _portions = recette.portions;
      _etapes = recette.etapes;
      _imageUrl = recette.imageUrl;
      for (final l in _lignes) {
        l.nom.dispose();
        l.quantite.dispose();
        l.unite.dispose();
      }
      _lignes = recette.ingredientsBruts.isNotEmpty
          ? recette.ingredientsBruts.map((brut) {
              final parsed = VocalService.nettoyer(brut);
              return _LigneIngredient(
                nom: TextEditingController(text: parsed.nomArticle),
                quantite:
                    TextEditingController(text: '${parsed.quantite}'),
                unite: TextEditingController(text: parsed.unite ?? ''),
              );
            }).toList()
          : [_LigneIngredient.vide()];
    });
    final nbEtapes = recette.etapes.length;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '"${recette.nom}" importée : ${recette.ingredientsBruts.length} '
          'ingrédient(s)${nbEtapes > 0 ? ", $nbEtapes étape(s)" : ""}'
          '${recette.imageUrl != null ? ", photo" : ""} — vérifie avant '
          'd\'enregistrer'),
      backgroundColor: couleurSucces(context),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recette == null ? 'Nouvelle recette' : 'Modifier la recette'),
        actions: [
          if (widget.recette == null)
            IconButton(
              icon: _import
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link),
              tooltip: 'Importer depuis une URL',
              onPressed: _import ? null : _importerDepuisUrl,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Enregistrer',
            onPressed: _enregistrer,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nomCtrl,
            decoration: const InputDecoration(labelText: 'Nom de la recette'),
            textCapitalization: TextCapitalization.sentences,
            maxLength: 60,
            maxLines: 2,
            minLines: 1,
          ),
          Row(
            children: [
              const Text('Portions : '),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Diminuer les portions',
                onPressed: _portions > 1
                    ? () => setState(() => _portions--)
                    : null,
              ),
              Text('$_portions', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Augmenter les portions',
                onPressed: () => setState(() => _portions++),
              ),
            ],
          ),
          // Étapes/photo importées : signalées ici (conservées à
          // l'enregistrement même si non éditables champ par champ).
          if (_etapes.isNotEmpty || _imageUrl != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${[
                          if (_imageUrl != null) 'Photo',
                          if (_etapes.isNotEmpty)
                            '${_etapes.length} étape(s) de préparation',
                        ].join(' + ')} importée(s), conservée(s).',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          Text('Ingrédients', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _lignes.length; i++) _buildLigne(i),
          TextButton.icon(
            onPressed: () => setState(() => _lignes.add(_LigneIngredient.vide())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un ingrédient'),
          ),
        ],
      ),
    );
  }

  Widget _buildLigne(int i) {
    final ligne = _lignes[i];
    // Le nom sur sa propre ligne (les titres de recettes/ingrédients
    // peuvent être longs), quantité + unité en dessous : trois champs
    // serrés sur une seule ligne étaient illisibles sur mobile.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ligne.nom,
                    decoration: const InputDecoration(
                        labelText: 'Ingrédient', isDense: true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Supprimer cet ingrédient',
                  onPressed: _lignes.length > 1
                      ? () => setState(() => _lignes.removeAt(i))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: ligne.quantite,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Qté', helperText: 'ex: 200', isDense: true),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: ligne.unite,
                    decoration: const InputDecoration(
                        labelText: 'Unité', helperText: 'ex: g, ml', isDense: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneIngredient {
  final TextEditingController nom;
  final TextEditingController quantite;
  final TextEditingController unite;

  _LigneIngredient({required this.nom, required this.quantite, required this.unite});

  factory _LigneIngredient.vide() => _LigneIngredient(
        nom: TextEditingController(),
        quantite: TextEditingController(text: '1'),
        unite: TextEditingController(),
      );
}
