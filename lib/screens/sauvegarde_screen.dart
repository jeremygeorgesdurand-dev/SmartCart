import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../providers/recettes_en_ligne_provider.dart';
import '../utils/erreur_utils.dart';
import '../utils/theme_utils.dart';

// ================================================================
// ÉCRAN SAUVEGARDE / RESTAURATION MANUELLE (fichier .json local)
// ================================================================
class SauvegardeScreen extends ConsumerStatefulWidget {
  const SauvegardeScreen({super.key});

  @override
  ConsumerState<SauvegardeScreen> createState() => _SauvegardeScreenState();
}

class _SauvegardeScreenState extends ConsumerState<SauvegardeScreen> {
  bool _enCours = false;
  bool _majRecettes = false;

  Future<void> _exporter() async {
    setState(() => _enCours = true);
    try {
      await ref.read(backupServiceProvider).exporter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la sauvegarde : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _restaurer() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
            'Les catégories, rayons, articles, listes et prix du fichier '
            'seront ajoutés/mis à jour dans SmartCart. Rien ne sera '
            'supprimé de ce qui existe déjà.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _enCours = true);
    try {
      final contenu = String.fromCharCodes(bytes);
      final res = await ref.read(backupServiceProvider).restaurer(contenu);

      ref.invalidate(categoriesNotifierProvider);
      ref.invalidate(rayonsNotifierProvider);
      ref.invalidate(articlesNotifierProvider);
      ref.invalidate(listesNotifierProvider);
      ref.invalidate(prixArticlesNotifierProvider);
      ref.invalidate(recettesNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sauvegarde restaurée : ${res.total} éléments')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de la restauration : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _partagerCatalogue() async {
    setState(() => _enCours = true);
    try {
      await ref.read(backupServiceProvider).partagerCatalogue();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec du partage : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  // Partage temps réel : obtient/affiche mon code de catalogue.
  Future<void> _partagerCatalogueDirect() async {
    setState(() => _enCours = true);
    try {
      final code = await ref.read(syncServiceProvider).partagerMonCatalogue();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Ton code de catalogue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Donne ce code aux personnes qui veulent suivre ton '
                  'catalogue. Elles le recevront et le garderont à jour '
                  'automatiquement.'),
              const SizedBox(height: 16),
              SelectableText(code,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  // Suivre le catalogue d'un autre compte via son code.
  Future<void> _suivreCatalogue() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suivre un catalogue'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Code à 6 caractères',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Suivre'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;

    setState(() => _enCours = true);
    try {
      final ok = await ref.read(syncServiceProvider).suivreCatalogue(code);
      if (!mounted) return;
      if (ok) {
        ref.invalidate(categoriesNotifierProvider);
        ref.invalidate(rayonsNotifierProvider);
        ref.invalidate(articlesNotifierProvider);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Catalogue suivi : il se mettra à jour en direct'
            : 'Code invalide'),
        backgroundColor: ok ? couleurSucces(context) : null,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _importerCatalogue() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null || !mounted) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Importer ce catalogue ?'),
        content: const Text(
            'Les articles, catégories et rayons du fichier seront ajoutés/mis '
            'à jour dans ton catalogue. Rien ne sera supprimé de ce qui existe '
            'déjà.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _enCours = true);
    try {
      final contenu = String.fromCharCodes(bytes);
      // Import CATALOGUE : fusionne catégories/rayons/articles PAR NOM (jamais
      // de doublon, articles rattachés à la bonne catégorie locale) et n'ajoute
      // aucune liste ni prix, même si le fichier est une sauvegarde complète.
      final res =
          await ref.read(backupServiceProvider).importerCatalogue(contenu);

      ref.invalidate(categoriesNotifierProvider);
      ref.invalidate(rayonsNotifierProvider);
      ref.invalidate(articlesNotifierProvider);

      // Persiste le catalogue fusionné sur le compte cloud (et donc sur les
      // autres appareils), best-effort : sans connexion, l'import local reste
      // acquis et repartira à la prochaine synchro.
      try {
        await ref.read(syncServiceProvider).uploadTout();
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Catalogue importé : ${res.articles} article(s), '
              '${res.categories} catégorie(s), ${res.rayons} rayon(s)'),
          backgroundColor: couleurSucces(context),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'import : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde')),
      body: ListView(
        children: [
          const _EnteteSection(titre: 'Partager mon catalogue'),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Partager le catalogue'),
            subtitle:
                const Text('Articles + catégories (sans les listes ni prix)'),
            trailing: _enCours
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _enCours ? null : _partagerCatalogue,
          ),
          ListTile(
            leading: const Icon(Icons.library_add_outlined),
            title: const Text('Importer un catalogue'),
            subtitle:
                const Text('Fusionne un catalogue reçu dans le tien'),
            onTap: _enCours ? null : _importerCatalogue,
          ),
          const Divider(height: 32),
          const _EnteteSection(titre: 'Catalogue partagé en temps réel'),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: const Text('Partager mon catalogue en direct'),
            subtitle: const Text(
                'Les personnes qui suivent reçoivent tes articles/catégories '
                'automatiquement'),
            onTap: _enCours ? null : _partagerCatalogueDirect,
          ),
          ListTile(
            leading: const Icon(Icons.rss_feed_outlined),
            title: const Text('Suivre un catalogue'),
            subtitle: const Text('Reçois en direct le catalogue d\'un proche'),
            onTap: _enCours ? null : _suivreCatalogue,
          ),
          const Divider(height: 32),
          const _EnteteSection(titre: 'Sauvegarde complète'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Exporter une sauvegarde'),
            subtitle: const Text('Catégories, rayons, articles, listes, prix'),
            trailing: _enCours
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _enCours ? null : _exporter,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restaurer une sauvegarde'),
            subtitle: const Text('Depuis un fichier .json exporté'),
            onTap: _enCours ? null : _restaurer,
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.restaurant_menu_outlined),
            title: const Text('Mettre à jour les recettes'),
            subtitle: const Text(
                'Télécharge la dernière version du catalogue de recettes'),
            trailing: _majRecettes
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: _majRecettes ? null : _mettreAJourRecettes,
          ),
        ],
      ),
    );
  }

  Future<void> _mettreAJourRecettes() async {
    setState(() => _majRecettes = true);
    try {
      final n = await ref.read(recettesDatasetServiceProvider).mettreAJour();
      // Recharge les recettes affichées avec la nouvelle version.
      ref.invalidate(toutesRecettesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Recettes à jour ($n recettes)'),
        backgroundColor: couleurSucces(context),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(messageErreurLisible(e, 'Mise à jour impossible')),
      ));
    } finally {
      if (mounted) setState(() => _majRecettes = false);
    }
  }
}

// Petit en-tête de section (libellé discret au-dessus d'un groupe de réglages).
class _EnteteSection extends StatelessWidget {
  final String titre;
  const _EnteteSection({required this.titre});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        titre.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
