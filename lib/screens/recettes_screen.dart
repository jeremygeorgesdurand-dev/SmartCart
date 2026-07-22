import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/vocal_service.dart';

// ================================================================
// ÉCRAN RECETTES — liste, création, et génération de liste de courses
// ================================================================
class RecettesScreen extends ConsumerWidget {
  const RecettesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recettesAsync = ref.watch(recettesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recettes')),
      body: recettesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (recettes) {
          if (recettes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Aucune recette'),
                  const SizedBox(height: 8),
                  const Text('Crée une recette pour générer sa liste de courses'),
                ],
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
                  onTap: () => _ouvrirDetail(context, ref, r),
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
                          ref.read(recettesNotifierProvider.notifier).supprimer(r.id);
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecetteFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle recette'),
      ),
    );
  }

  void _ouvrirDetail(BuildContext context, WidgetRef ref, Recette r) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      // Sans ça, le contenu (nom + portions + ingrédients + bouton) est
      // limité à une hauteur fixe et non scrollable : pour une recette
      // avec beaucoup d'ingrédients (import depuis une URL), le bouton
      // "Générer une liste de courses" finissait poussé hors de l'écran
      // visible, avec l'air de ne plus exister.
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
            Text(recette.nom, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${recette.portions} portions',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            for (final ing in recette.ingredients)
              ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 8),
                title: Text(ing.nom),
                trailing: Text(ing.unite != null
                    ? '${ing.quantite} ${ing.unite}'
                    : '${ing.quantite}'),
              ),
            const SizedBox(height: 20),
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
                      SnackBar(content: Text('Une erreur est survenue : $e')),
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
                    backgroundColor: incomplet ? Colors.orange : Colors.green,
                  ));
                }
              },
        icon: generation
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
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

  @override
  void initState() {
    super.initState();
    final r = widget.recette;
    _nomCtrl = TextEditingController(text: r?.nom ?? '');
    _portions = r?.portions ?? 4;
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '"${recette.nom}" importée — vérifie les quantités avant d\'enregistrer'),
      backgroundColor: Colors.green,
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
                onPressed: _portions > 1
                    ? () => setState(() => _portions--)
                    : null,
              ),
              Text('$_portions', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _portions++),
              ),
            ],
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
