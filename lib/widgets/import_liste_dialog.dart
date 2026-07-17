import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/export_service.dart';
import '../services/liste_partage_service.dart';

class ImportListeDialog extends ConsumerStatefulWidget {
  final String? listeId;
  const ImportListeDialog({super.key, this.listeId});

  @override
  ConsumerState<ImportListeDialog> createState() => _ImportListeDialogState();
}

class _ImportListeDialogState extends ConsumerState<ImportListeDialog> {
  final _ctrl = TextEditingController();
  ListeImportResult? _apercu;
  bool _importing = false;
  String? _erreur;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _parse(String texte) {
    if (texte.trim().isEmpty) {
      setState(() { _apercu = null; _erreur = null; });
      return;
    }

    final result = ListePartageService.parserTexte(texte);
    if (result != null) {
      setState(() { _apercu = result; _erreur = null; });
      return;
    }

    final lignes = texte.split('\n')
        .map((l) => ExportService.parseLigne(l))
        .whereType<LigneImport>()
        .where((l) => l.nom.isNotEmpty)
        .toList();

    if (lignes.isNotEmpty) {
      setState(() {
        _apercu = ListeImportResult(
          nomListe: widget.listeId != null ? 'articles' : 'Liste importée',
          magasin: null,
          articles: lignes.map((l) => ArticleImport(
            nom: l.nom,
            categorieNom: l.categorieNom,
            rayonNom: l.rayonNom,
            quantite: 1,
          )).toList(),
        );
        _erreur = null;
      });
    } else {
      setState(() { _apercu = null; _erreur = 'Format non reconnu'; });
    }
  }

  Future<void> _importer() async {
    if (_apercu == null) return;
    setState(() => _importing = true);

    final db = ref.read(dbServiceProvider);
    final categories = ref.read(categoriesNotifierProvider).valueOrNull ?? [];
    final rayons = ref.read(rayonsNotifierProvider).valueOrNull ?? [];

    // Créer ou récupérer la liste cible
    final String listeId;
    if (widget.listeId != null) {
      listeId = widget.listeId!;
    } else {
      final newId = 'liste_${const Uuid().v4()}';
      await ref.read(listesNotifierProvider.notifier).ajouter(ListeCourses(
        id: newId,
        nom: _apercu!.nomListe,
        magasin: _apercu!.magasin,
      ));
      listeId = newId;
    }

    // Catalogue mutable mis à jour pendant la boucle
    final catalogueMutable = List<Article>.from(
      ref.read(articlesNotifierProvider).valueOrNull ?? [],
    );

    // IDs déjà dans la liste
    final itemsListe = await db.getArticlesListe(listeId);
    final idsDejaInListe = itemsListe.map((i) => i.articleId).toSet();

    int nbImportes = 0;
    int nbExistants = 0;

    for (int i = 0; i < _apercu!.articles.length; i++) {
      final ai = _apercu!.articles[i];

      String? catId = ai.categorieNom.isNotEmpty
          ? categories
              .where((c) => c.nom.toLowerCase() == ai.categorieNom.toLowerCase())
              .firstOrNull?.id
          : null;

      String? rayonId = ai.rayonNom.isNotEmpty
          ? rayons
              .where((r) => r.nom.toLowerCase() == ai.rayonNom.toLowerCase())
              .firstOrNull?.id
          : null;

      // ── Étape 1 : Catalogue ──────────────────────────────────
      Article article;
      final existant = catalogueMutable
          .where((a) => a.nom.toLowerCase() == ai.nom.toLowerCase())
          .firstOrNull;

      if (existant == null) {
        // Créer dans le catalogue
        article = Article(
          id: 'article_${DateTime.now().millisecondsSinceEpoch}_$i',
          nom: ai.nom[0].toUpperCase() + ai.nom.substring(1),
          categorieId: catId,
          rayonId: rayonId,
        );
        await ref.read(articlesNotifierProvider.notifier).ajouter(article);
        catalogueMutable.add(article);
        nbImportes++;
        await Future.delayed(const Duration(milliseconds: 10));
      } else {
        article = existant;
        // Mettre à jour si catégories manquantes
        if ((catId != null && article.categorieId == null) ||
            (rayonId != null && article.rayonId == null)) {
          final updated = article.copyWith(
            categorieId: catId ?? article.categorieId,
            rayonId: rayonId ?? article.rayonId,
          );
          await ref.read(articlesNotifierProvider.notifier).modifier(updated);
          final idx = catalogueMutable.indexWhere((a) => a.id == updated.id);
          if (idx >= 0) catalogueMutable[idx] = updated;
          article = updated;
        }
        nbExistants++;
      }

      // ── Étape 2 : Ajouter à la liste ────────────────────────
      if (!idsDejaInListe.contains(article.id)) {
        await db.insertArticleListe(ArticleListe(
          id: 'al_${const Uuid().v4()}',
          listeId: listeId,
          articleId: article.id,
          quantite: ai.quantite,
          unite: ai.unite,
        ));
        idsDejaInListe.add(article.id);
      }
    }

    ref.invalidate(articlesNotifierProvider);
    ref.invalidate(listesNotifierProvider);
    ref.invalidate(articlesListeProvider(listeId));

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        widget.listeId != null
            ? '${_apercu!.articles.length} article(s) importé(s) dans la liste'
            : '"${_apercu!.nomListe}" créée avec ${_apercu!.articles.length} article(s)'
                '${nbImportes > 0 ? " ($nbImportes nouveaux)" : ""}',
      ),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.listeId != null ? 'Importer des articles' : 'Importer une liste',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Collez le texte d\'une liste SmartCart partagée\nou un format simple (nom;catégorie;rayon)',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: 'Collez ici...',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _parse,
            ),
            const SizedBox(height: 10),
            if (_erreur != null)
              Text(_erreur!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12))
            else if (_apercu != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_apercu!.nomListe != 'articles')
                      Text('Liste : ${_apercu!.nomListe}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_apercu!.articles.length} article(s) détecté(s)'),
                    if (_apercu!.articles.any(
                        (a) => a.categorieNom.isNotEmpty || a.rayonNom.isNotEmpty))
                      const Text('✓ Catégories incluses',
                          style: TextStyle(color: Colors.green, fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _apercu == null || _importing ? null : _importer,
                  icon: _importing
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload),
                  label: Text(_importing ? 'Import...' : 'Importer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DIALOG EXPORT CATALOGUE
// ================================================================
class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  String _texte = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _generer();
  }

  Future<void> _generer() async {
    final texte = await ref.read(exportServiceProvider).exporterCatalogue();
    setState(() { _texte = texte; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download),
                const SizedBox(width: 8),
                Text('Exporter le catalogue',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text('Format : nom;categorie_maison;rayon_magasin',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _texte.isEmpty ? '(Catalogue vide)' : _texte,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading || _texte.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: _texte));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Copié dans le presse-papier')));
                              Navigator.pop(context);
                            }
                          },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copier'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Fermer'),
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
