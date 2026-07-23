import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../providers/providers.dart';

// Avertit avant de créer un doublon plutôt que de laisser le "Doublons"
// détecter le problème après coup : si un article du même nom (insensible à
// la casse/aux espaces) existe déjà, on demande confirmation. Retourne true
// si la création doit continuer (aucun doublon, ou confirmé malgré tout).
Future<bool> _confirmerSiDoublon(
    BuildContext context, WidgetRef ref, String nom) async {
  final nomNormalise = nom.trim().toLowerCase();
  final existant = ref
      .read(articlesNotifierProvider)
      .valueOrNull
      ?.where((a) => a.nom.trim().toLowerCase() == nomNormalise)
      .firstOrNull;
  if (existant == null) return true;

  final continuer = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: const Text('Article déjà existant'),
      content: Text(
          '"${existant.nom}" est déjà dans le catalogue. Créer quand même '
          'un doublon ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogCtx, true),
          child: const Text('Créer quand même'),
        ),
      ],
    ),
  );
  return continuer ?? false;
}

class AjouterArticleDialog extends ConsumerStatefulWidget {
  final String? nomInitial;
  final Article? articleExistant;
  final String? barcodeInitial; // pour le scan code-barres
  const AjouterArticleDialog({
    super.key,
    this.nomInitial,
    this.articleExistant,
    this.barcodeInitial,
  });

  @override
  ConsumerState<AjouterArticleDialog> createState() =>
      _AjouterArticleDialogState();
}

class _AjouterArticleDialogState extends ConsumerState<AjouterArticleDialog> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _marqueCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _prixCtrl;
  String? _selectedCatId;
  String? _selectedRayonId;

  bool _loadingOFF = false;
  List<Article> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(
        text: widget.nomInitial ?? widget.articleExistant?.nom ?? '');
    _marqueCtrl =
        TextEditingController(text: widget.articleExistant?.marque ?? '');
    _barcodeCtrl = TextEditingController(
        text: widget.barcodeInitial ?? widget.articleExistant?.barcode ?? '');
    _selectedCatId = widget.articleExistant?.categorieId;
    _selectedRayonId = widget.articleExistant?.rayonId;

    // Prix générique existant (sans magasin précis), s'il y en a déjà un.
    final articleId = widget.articleExistant?.id;
    final prixExistant = articleId == null
        ? null
        : ref
            .read(prixArticlesNotifierProvider)
            .valueOrNull
            ?.where((p) => p.articleId == articleId && p.magasin.isEmpty)
            .firstOrNull;
    _prixCtrl = TextEditingController(
        text: prixExistant != null
            ? prixExistant.prix.toStringAsFixed(2)
            : '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _marqueCtrl.dispose();
    _barcodeCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  Future<void> _rechercherOFF() async {
    if (_nomCtrl.text.trim().isEmpty) return;
    setState(() => _loadingOFF = true);
    final results = await ref
        .read(offServiceProvider)
        .searchByName(_nomCtrl.text.trim());
    if (!mounted) return;
    setState(() {
      _suggestions = results.take(5).toList();
      _loadingOFF = false;
    });
  }

  void _appliquerSuggestion(Article suggestion) {
    _nomCtrl.text = suggestion.nom;
    _marqueCtrl.text = suggestion.marque ?? '';
    setState(() {
      if (suggestion.categorieId != null) {
        _selectedCatId = suggestion.categorieId;
      }
      _suggestions = [];
    });
  }

  Future<void> _enregistrer() async {
    if (_nomCtrl.text.trim().isEmpty) return;
    // Seulement à la création : modifier un article existant garde le même
    // nom la plupart du temps, ça ne doit pas déclencher un avertissement.
    if (widget.articleExistant == null) {
      final continuer =
          await _confirmerSiDoublon(context, ref, _nomCtrl.text);
      if (!continuer || !mounted) return;
    }
    final article = Article(
      id: widget.articleExistant?.id ??
          'article_${DateTime.now().millisecondsSinceEpoch}',
      nom: _nomCtrl.text.trim(),
      marque:
          _marqueCtrl.text.trim().isEmpty ? null : _marqueCtrl.text.trim(),
      barcode:
          _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      categorieId: _selectedCatId,
      rayonId: _selectedRayonId,
    );
    if (widget.articleExistant == null) {
      ref.read(articlesNotifierProvider.notifier).ajouter(article);
    } else {
      ref.read(articlesNotifierProvider.notifier).modifier(article);
    }

    final prixValeur =
        double.tryParse(_prixCtrl.text.trim().replaceAll(',', '.'));
    if (prixValeur != null && prixValeur >= 0) {
      ref
          .read(prixArticlesNotifierProvider.notifier)
          .definir(article.id, prixValeur, magasin: '');
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final catAsync = ref.watch(categoriesNotifierProvider);
    final rayAsync = ref.watch(rayonsNotifierProvider);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.articleExistant == null
                    ? 'Ajouter un article'
                    : 'Modifier l\'article',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),

              // Nom + recherche Open Food Facts
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nomCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l\'article *',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLength: 80,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _rechercherOFF,
                    icon: _loadingOFF
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    tooltip: 'Rechercher sur Open Food Facts',
                  ),
                ],
              ),

              // Suggestions OFF
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _suggestions
                        .map((s) => ListTile(
                              dense: true,
                              title: Text(s.nom),
                              subtitle:
                                  s.marque != null ? Text(s.marque!) : null,
                              onTap: () => _appliquerSuggestion(s),
                            ))
                        .toList(),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Marque
              TextField(
                controller: _marqueCtrl,
                decoration: const InputDecoration(
                    labelText: 'Marque (optionnel)'),
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
              ),

              const SizedBox(height: 12),

              // Code-barres (pré-rempli si venu du scanner)
              TextField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Code-barres (optionnel)',
                  prefixIcon: Icon(Icons.barcode_reader),
                ),
                keyboardType: TextInputType.number,
              ),

              const SizedBox(height: 12),

              // Prix estimé (optionnel)
              TextField(
                controller: _prixCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prix estimé (optionnel)',
                  prefixIcon: Icon(Icons.euro),
                  suffixText: '€',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),

              const SizedBox(height: 12),

              // Catégorie maison
              catAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (err, stack) => const SizedBox.shrink(),
                data: (cats) => DropdownButtonFormField<String?>(
                  initialValue: _selectedCatId,
                  decoration: const InputDecoration(
                      labelText: 'Catégorie maison'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Aucune')),
                    ...cats.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                  backgroundColor: Color(c.couleur),
                                  radius: 8),
                              const SizedBox(width: 8),
                              Text(c.nom),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedCatId = v),
                ),
              ),

              const SizedBox(height: 12),

              // Rayon magasin
              rayAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (err, stack) => const SizedBox.shrink(),
                data: (rayons) => DropdownButtonFormField<String?>(
                  initialValue: _selectedRayonId,
                  decoration:
                      const InputDecoration(labelText: 'Rayon magasin'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Aucun')),
                    ...rayons.map((r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(r.nom),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedRayonId = v),
                ),
              ),

              const SizedBox(height: 24),

              // Boutons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _enregistrer,
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ================================================================
// AJOUT RAPIDE - juste le nom, options plus tard
// ================================================================
class AjoutRapideDialog extends ConsumerStatefulWidget {
  final String? nomInitial;
  const AjoutRapideDialog({super.key, this.nomInitial});

  @override
  ConsumerState<AjoutRapideDialog> createState() => _AjoutRapideDialogState();
}

class _AjoutRapideDialogState extends ConsumerState<AjoutRapideDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.nomInitial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final nom = _ctrl.text.trim();
    if (nom.isEmpty) return;
    final continuer = await _confirmerSiDoublon(context, ref, nom);
    if (!continuer || !mounted) return;
    final article = Article(
      id: 'article_${DateTime.now().millisecondsSinceEpoch}',
      nom: nom,
    );
    ref.read(articlesNotifierProvider.notifier).ajouter(article);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$nom" ajouté au catalogue'),
        action: SnackBarAction(
          label: 'Compléter',
          onPressed: () => showDialog(
            context: context,
            builder: (_) => AjouterArticleDialog(articleExistant: article),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajout rapide'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: "Nom de l'article",
          prefixIcon: Icon(Icons.add_shopping_cart),
        ),
        onSubmitted: (_) => _enregistrer(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            final nom = _ctrl.text.trim();
            // Contrairement à "Ajouter" (qui enregistre tout de suite et a
            // donc besoin d'un nom), "Avec options" ouvre juste le
            // formulaire complet : un nom vide ne doit pas bloquer, on
            // pourra le renseigner là-bas.
            // On renvoie juste le nom au lieu d'enchaîner un nouveau
            // showDialog ici : appeler showDialog avec le BuildContext de
            // CE dialogue juste après l'avoir fermé (Navigator.pop) est
            // un piège classique Flutter — le contexte peut déjà être
            // désactivé, et le nouveau dialogue n'apparaît jamais. On
            // laisse l'écran appelant (dont le contexte reste stable)
            // ouvrir AjouterArticleDialog à la place.
            Navigator.pop(context, nom);
          },
          child: const Text('Avec options'),
        ),
        FilledButton(
          onPressed: _enregistrer,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
