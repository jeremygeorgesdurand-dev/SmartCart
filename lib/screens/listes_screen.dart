import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/animated_list_item.dart';
import '../widgets/import_liste_dialog.dart';
import '../widgets/prix_article_badge.dart';
import '../widgets/vocal_button.dart';
import 'recherche_globale_screen.dart';
import 'recettes_screen.dart';

// Provider local pour le tri des listes
final _listeSortProvider = StateProvider<String>((_) => 'date');

// Message d'erreur affiché à l'utilisateur pour les actions qui échouent
// réellement (réseau requis, pas de secours local) : rejoindre, partager,
// quitter ou gérer une collaboration.
void _afficherErreur(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Une erreur est survenue : $e')),
  );
}

// ================================================================
// ÉCRAN MES LISTES
// ================================================================
class ListesScreen extends ConsumerWidget {
  const ListesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listesAsync = ref.watch(listesNotifierProvider);
    final sortMode = ref.watch(_listeSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes listes'),
        actions: [
          // Recherche globale (catalogue + listes)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Rechercher',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RechercheGlobaleScreen()),
            ),
          ),
          // Recettes → génération de liste de courses
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Recettes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecettesScreen()),
            ),
          ),
          // Rejoindre une liste collaborative via un code
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Rejoindre une liste',
            onPressed: () => _rejoindreListe(context, ref),
          ),
          // Importer une liste partagée (texte)
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importer une liste',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ImportListeDialog(),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Trier',
            onSelected: (v) => ref.read(_listeSortProvider.notifier).state = v,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'date', child: Text('Par date (récent en premier)')),
              PopupMenuItem(value: 'alpha', child: Text('Par ordre alphabétique')),
            ],
          ),
        ],
      ),
      body: listesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (listes) {
          if (listes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('Aucune liste',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Créez votre première liste de courses'),
                ],
              ),
            );
          }
          // Appliquer le tri
          final sorted = [...listes];
          switch (sortMode) {
            case 'alpha':
              sorted.sort((a, b) =>
                  a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
            case 'date':
            default:
              sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: sorted.length,
            itemBuilder: (_, i) => AnimatedListItem(
              index: i,
              child: _ListeCard(liste: sorted[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _creerListe(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle liste'),
      ),
    );
  }

  void _rejoindreListe(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rejoindre une liste'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Code à 6 caractères…',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final code = ctrl.text.trim();
              if (code.isEmpty) return;
              bool ok;
              try {
                ok = await ref
                    .read(listesNotifierProvider.notifier)
                    .rejoindre(code);
              } catch (e) {
                if (context.mounted) _afficherErreur(context, e);
                return;
              }
              if (!context.mounted) return;
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'Liste rejointe !'
                    : 'Code invalide ou liste introuvable'),
                backgroundColor: ok ? Colors.green : null,
              ));
            },
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }

  void _creerListe(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    int couleurChoisie = couleursListe[0];
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setState) => AlertDialog(
          scrollable: true,
          title: const Text('Nouvelle liste'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  hintText: 'Nom de la liste…',
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: couleursListe.map((c) {
                  final selectionnee = c == couleurChoisie;
                  return GestureDetector(
                    onTap: () => setState(() => couleurChoisie = c),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: selectionnee
                            ? Border.all(
                                color: Theme.of(dialogCtx).colorScheme.onSurface,
                                width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                if (ctrl.text.trim().isNotEmpty) {
                  ref.read(listesNotifierProvider.notifier).ajouter(
                        ListeCourses(
                          id: 'liste_${const Uuid().v4()}',
                          nom: ctrl.text.trim(),
                          couleur: couleurChoisie,
                        ),
                      );
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

// Palette de couleurs proposée à la création d'une liste.
const couleursListe = [
  0xFF1ABC9C, 0xFF1565C0, 0xFFE53935, 0xFFFF8F00,
  0xFF8E24AA, 0xFF00838F, 0xFF546E7A, 0xFFD81B60,
];

// ================================================================
// CARTE D'UNE LISTE
// ================================================================
class _ListeCard extends ConsumerWidget {
  final ListeCourses liste;
  const _ListeCard({required this.liste});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsync = ref.watch(articlesListeProvider(liste.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => DetailListeScreen(liste: liste),
            transitionsBuilder: (_, anim, __, child) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icône
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(liste.couleur).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_cart,
                  color: Color(liste.couleur),
                ),
              ),
              const SizedBox(width: 16),

              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(liste.nom,
                              style: Theme.of(context).textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (liste.partagee) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.people,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                        ],
                      ],
                    ),
                    if (liste.magasin != null) ...[
                      const SizedBox(height: 2),
                      Text(liste.magasin!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    articlesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
                      data: (items) {
                        final total = items.length;
                        final coches = items.where((a) => a.coche).length;
                        return Text(
                          total == 0
                              ? 'Liste vide'
                              : '$coches / $total articles cochés',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Total estimé (si des prix sont renseignés)
              Builder(builder: (context) {
                if (!ref.watch(afficherPrixProvider)) return const SizedBox.shrink();
                final total = ref.watch(totalListeProvider(liste.id));
                if (total <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${total.toStringAsFixed(2)} €',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                );
              }),

              // Menu contextuel
              PopupMenuButton(
                onSelected: (action) => _onAction(context, ref, action),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'courses', child: Text('Mode courses')),
                  const PopupMenuItem(value: 'partager', child: Text('Partager (texte)')),
                  PopupMenuItem(
                    value: 'collaborer',
                    child: Text(liste.partagee
                        ? 'Gérer la collaboration'
                        : 'Rendre collaborative'),
                  ),
                  const PopupMenuItem(value: 'importer', child: Text('Importer une liste')),
                  const PopupMenuItem(value: 'dupliquer', child: Text('Dupliquer')),
                  const PopupMenuItem(value: 'renommer', child: Text('Renommer')),
                  const PopupMenuItem(
                    value: 'vider',
                    child: Row(children: [
                      Icon(Icons.remove_shopping_cart,
                          size: 18, color: Color(0xFFFFC400)),
                      SizedBox(width: 10),
                      Text('Vider la liste',
                          style: TextStyle(
                              color: Color(0xFFB38600),
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'supprimer',
                    child: Row(children: [
                      Icon(Icons.delete_forever, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Supprimer',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'courses':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ModeCoursesScreen(liste: liste)),
        );
      case 'partager':
        _partagerListe(context, ref);
      case 'collaborer':
        _gererCollaboration(context, ref);
      case 'importer':
        showDialog(
          context: context,
          builder: (_) => ImportListeDialog(listeId: liste.id),
        );
      case 'vider':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Vider la liste ?'),
            content: Text('Supprimer tous les articles de "${liste.nom}" ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  final items = await ref
                      .read(dbServiceProvider)
                      .getArticlesListe(liste.id);
                  // En parallèle plutôt qu'un await par article : sur une
                  // liste avec beaucoup d'articles, la version séquentielle
                  // donnait l'impression qu'il fallait rappuyer plusieurs
                  // fois sur "Vider" (ça continuait de vider en arrière-plan
                  // pendant qu'on retentait).
                  await Future.wait(items.map((item) => ref
                      .read(articlesListeProvider(liste.id).notifier)
                      .supprimer(item.id)));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${items.length} article(s) supprimé(s) de "${liste.nom}"'),
                        action: SnackBarAction(
                          label: 'Annuler',
                          onPressed: () {
                            for (final item in items) {
                              ref
                                  .read(articlesListeProvider(liste.id)
                                      .notifier)
                                  .ajouter(item);
                            }
                          },
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                child: const Text('Vider'),
              ),
            ],
          ),
        );
      case 'dupliquer':
        final ctrl = TextEditingController(text: '${liste.nom} (copie)');
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Dupliquer la liste'),
            content: TextField(controller: ctrl, maxLength: 60),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler')),
              FilledButton(
                onPressed: () {
                  ref
                      .read(listesNotifierProvider.notifier)
                      .dupliquer(liste, ctrl.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('Dupliquer'),
              ),
            ],
          ),
        );
      case 'renommer':
        final ctrl = TextEditingController(text: liste.nom);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Renommer'),
            content: TextField(controller: ctrl, maxLength: 60),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler')),
              FilledButton(
                onPressed: () {
                  ref.read(listesNotifierProvider.notifier).modifier(
                        liste.copyWith(nom: ctrl.text.trim()),
                      );
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      case 'supprimer':
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Supprimer la liste ?'),
            content: Text('Supprimer "${liste.nom}" définitivement ?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () async {
                  // Les articles_liste sont supprimés en cascade (ON DELETE
                  // CASCADE) avec la liste : on les capture avant pour
                  // pouvoir les restaurer si l'utilisateur annule.
                  final items = await ref
                      .read(dbServiceProvider)
                      .getArticlesListe(liste.id);
                  ref.read(listesNotifierProvider.notifier).supprimer(liste.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Liste "${liste.nom}" supprimée'),
                        action: SnackBarAction(
                          label: 'Annuler',
                          onPressed: () {
                            ref
                                .read(listesNotifierProvider.notifier)
                                .ajouter(liste);
                            for (final item in items) {
                              ref
                                  .read(articlesListeProvider(liste.id)
                                      .notifier)
                                  .ajouter(item);
                            }
                          },
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
                child: const Text('Supprimer'),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _gererCollaboration(BuildContext context, WidgetRef ref) async {
    if (!liste.partagee) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Rendre collaborative ?'),
          content: Text(
            'Toute personne avec le code pourra voir et modifier '
            '"${liste.nom}" en temps réel. Continuer ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirme != true) return;

      String code;
      try {
        code = await ref.read(listesNotifierProvider.notifier).partager(liste);
      } catch (e) {
        if (context.mounted) _afficherErreur(context, e);
        return;
      }
      if (!context.mounted) return;
      _afficherCode(context, ref, code);
      return;
    }

    _afficherCode(context, ref, liste.code!);
  }

  void _afficherCode(BuildContext context, WidgetRef ref, String code) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Liste collaborative'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Partagez ce code pour inviter quelqu\'un :'),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogCtx).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    code,
                    style: Theme.of(dialogCtx).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Membres', style: Theme.of(dialogCtx).textTheme.titleSmall),
              const SizedBox(height: 4),
              _ListeMembres(listeId: liste.id),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (dialogCtx.mounted) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Code copié')),
                );
              }
            },
            child: const Text('Copier'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogCtx).colorScheme.error),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(listesNotifierProvider.notifier)
                    .quitterPartage(liste);
              } catch (e) {
                if (context.mounted) _afficherErreur(context, e);
              }
            },
            child: const Text('Quitter la collaboration'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _partagerListe(BuildContext context, WidgetRef ref) async {
    final items = await ref.read(dbServiceProvider).getArticlesListe(liste.id);
    // .future (pas .valueOrNull) : garantit le chargement même si aucun
    // autre écran n'a encore déclenché ces providers.
    final catalogue = await ref.read(articlesNotifierProvider.future);
    final rayons = await ref.read(rayonsNotifierProvider.future);
    final categories = await ref.read(categoriesNotifierProvider.future);
    final service = ref.read(partageServiceProvider);

    final texte = service.formaterListe(
      liste: liste,
      items: items,
      catalogue: catalogue,
      rayons: rayons,
      categories: categories,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => _PartageSheet(
        liste: liste,
        texte: texte,
        items: items,
        catalogue: catalogue,
        rayons: rayons,
      ),
    );
  }
}

// ================================================================
// LISTE DES MEMBRES D'UNE COLLABORATION
// ================================================================
class _ListeMembres extends ConsumerStatefulWidget {
  final String listeId;
  const _ListeMembres({required this.listeId});

  @override
  ConsumerState<_ListeMembres> createState() => _ListeMembresState();
}

class _ListeMembresState extends ConsumerState<_ListeMembres> {
  List<({String uid, String? displayName, String? photoURL, bool estProprietaire})>?
      _membres;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final membres =
          await ref.read(syncServiceProvider).getMembresListe(widget.listeId);
      if (mounted) setState(() => _membres = membres);
    } catch (e) {
      if (mounted) _afficherErreur(context, e);
    }
  }

  Future<void> _retirer(String uid) async {
    try {
      await ref.read(syncServiceProvider).retirerMembre(widget.listeId, uid);
      await _charger();
    } catch (e) {
      if (mounted) _afficherErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membres = _membres;
    if (membres == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final monUid = ref.read(authServiceProvider).currentUser?.uid;

    return Column(
      children: membres.map((m) {
        final nom = m.displayName ?? 'Utilisateur';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundImage:
                m.photoURL != null ? NetworkImage(m.photoURL!) : null,
            child: m.photoURL == null
                ? Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 13))
                : null,
          ),
          title: Text(m.uid == monUid ? '$nom (moi)' : nom),
          subtitle: m.estProprietaire ? const Text('Propriétaire') : null,
          trailing: m.uid == monUid
              ? null
              : IconButton(
                  icon: const Icon(Icons.person_remove_outlined, size: 20),
                  tooltip: 'Retirer',
                  onPressed: () => _retirer(m.uid),
                ),
        );
      }).toList(),
    );
  }
}

// ================================================================
// DÉTAIL D'UNE LISTE (édition)
// ================================================================
class DetailListeScreen extends ConsumerWidget {
  final ListeCourses liste;
  const DetailListeScreen({super.key, required this.liste});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesListeAsync = ref.watch(articlesListeProvider(liste.id));
    final articlesAsync = ref.watch(articlesNotifierProvider);
    final sortMode = ref.watch(articleListeSortProvider);
    final total = ref.watch(afficherPrixProvider)
        ? ref.watch(totalListeProvider(liste.id))
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(liste.nom),
        bottom: total > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '≈ ${total.toStringAsFixed(2)} €',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              )
            : null,
        actions: [
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            onSelected: (mode) =>
                ref.read(articleListeSortProvider.notifier).state = mode,
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortMode.alphabetique, child: Text('A → Z')),
              PopupMenuItem(value: SortMode.categorie, child: Text('Par catégorie maison')),
              PopupMenuItem(value: SortMode.rayon, child: Text('Par rayon magasin')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Partager la liste',
            onPressed: () => _partagerDepuisDetail(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag),
            tooltip: 'Mode courses',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ModeCoursesScreen(liste: liste)),
            ),
          ),
        ],
      ),
      body: articlesListeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_shopping_cart,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text('Liste vide'),
                  const SizedBox(height: 8),
                  const Text('Appuyez sur + pour ajouter des articles'),
                ],
              ),
            );
          }

          return articlesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (catalogue) {
              final catAsync = ref.watch(categoriesNotifierProvider);
              final rayAsync = ref.watch(rayonsNotifierProvider);

              return catAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => const SizedBox.shrink(),
                data: (categories) => rayAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const SizedBox.shrink(),
                  data: (rayons) {
                    // Enrichir les items
                    final itemsEnrichis = items
                        .map((item) {
                          final article = catalogue.where((a) => a.id == item.articleId).firstOrNull;
                          return article != null ? (item: item, article: article) : null;
                        })
                        .whereType<({ArticleListe item, Article article})>()
                        .toList();

                    // Trier selon sortMode
                    if (sortMode == SortMode.alphabetique) {
                      itemsEnrichis.sort((a, b) => a.article.nom.toLowerCase().compareTo(b.article.nom.toLowerCase()));
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: itemsEnrichis.length,
                        itemBuilder: (_, i) => _ArticleListeTile(
                          articleListe: itemsEnrichis[i].item,
                          article: itemsEnrichis[i].article,
                          listeId: liste.id,
                        ),
                      );
                    }

                    // Grouper par catégorie ou rayon
                    final Map<String, List<({ArticleListe item, Article article})>> groupes = {};
                    for (final e in itemsEnrichis) {
                      final cle = sortMode == SortMode.categorie
                          ? (e.article.categorieId ?? '__aucun__')
                          : (e.article.rayonId ?? '__aucun__');
                      groupes.putIfAbsent(cle, () => []).add(e);
                    }

                    // Trier les clés par ordre
                    final cles = groupes.keys.toList()
                      ..sort((a, b) {
                        if (a == '__aucun__') return 1;
                        if (b == '__aucun__') return -1;
                        if (sortMode == SortMode.categorie) {
                          final ca = categories.where((c) => c.id == a).firstOrNull;
                          final cb = categories.where((c) => c.id == b).firstOrNull;
                          return (ca?.ordre ?? 99).compareTo(cb?.ordre ?? 99);
                        } else {
                          final ra = rayons.where((r) => r.id == a).firstOrNull;
                          final rb = rayons.where((r) => r.id == b).firstOrNull;
                          return (ra?.ordre ?? 99).compareTo(rb?.ordre ?? 99);
                        }
                      });

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: cles.length,
                      itemBuilder: (_, i) {
                        final cle = cles[i];
                        final groupe = groupes[cle]!;
                        String label;
                        Color? couleur;
                        if (cle == '__aucun__') {
                          label = sortMode == SortMode.categorie ? 'Sans categorie' : 'Sans rayon';
                        } else if (sortMode == SortMode.categorie) {
                          final cat = categories.where((c) => c.id == cle).firstOrNull;
                          label = cat?.nom ?? cle;
                          couleur = cat != null ? Color(cat.couleur) : null;
                        } else {
                          label = rayons.where((r) => r.id == cle).firstOrNull?.nom ?? cle;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête du groupe
                            Container(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                              child: Row(
                                children: [
                                  if (couleur != null) ...[
                                    CircleAvatar(backgroundColor: couleur, radius: 6),
                                    const SizedBox(width: 8),
                                  ] else ...[
                                    Icon(
                                      sortMode == SortMode.rayon ? Icons.store_outlined : Icons.category_outlined,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    label,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: couleur ?? Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${groupe.length} article${groupe.length > 1 ? 's' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ...groupe.map((e) => _ArticleListeTile(
                              articleListe: e.item,
                              article: e.article,
                              listeId: liste.id,
                            )),
                          ],
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Bouton vocal : dicter directement dans la liste
          FloatingActionButton(
            heroTag: 'vocal_${liste.id}',
            onPressed: () => _ouvrirVocalPourListe(context, ref),
            tooltip: 'Ajouter par la voix',
            child: const Icon(Icons.mic),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add_${liste.id}',
            onPressed: () => _ajouterDepuisCatalogue(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter des articles'),
          ),
        ],
      ),
    );
  }

  void _ajouterDepuisCatalogue(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SelectionArticlesSheet(listeId: liste.id),
    );
  }

  void _ouvrirVocalPourListe(BuildContext context, WidgetRef ref) {
    ouvrirVocal(context, listeId: liste.id);
  }

  Future<void> _partagerDepuisDetail(BuildContext context, WidgetRef ref) async {
    final items = await ref.read(dbServiceProvider).getArticlesListe(liste.id);
    final catalogue = await ref.read(articlesNotifierProvider.future);
    final rayons = await ref.read(rayonsNotifierProvider.future);
    final categories = await ref.read(categoriesNotifierProvider.future);
    final service = ref.read(partageServiceProvider);

    final texte = service.formaterListe(
      liste: liste,
      items: items,
      catalogue: catalogue,
      rayons: rayons,
      categories: categories,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => _PartageSheet(
        liste: liste,
        texte: texte,
        items: items,
        catalogue: catalogue,
        rayons: rayons,
      ),
    );
  }
}

// ================================================================
// TILE ARTICLE DANS LA LISTE — appui simple = cocher, long = options
// ================================================================
class _ArticleListeTile extends ConsumerWidget {
  final ArticleListe articleListe;
  final Article article;
  final String listeId;

  const _ArticleListeTile({
    required this.articleListe,
    required this.article,
    required this.listeId,
  });

  void _afficherOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      // StatefulBuilder pour mettre à jour la quantité sans fermer
      builder: (sheetCtx) => Consumer(
        builder: (ctx, r, _) {
          // Re-lire l'articleListe à jour depuis le provider
          final items = r.watch(articlesListeProvider(listeId)).valueOrNull ?? [];
          final alActuel = items.where((i) => i.id == articleListe.id).firstOrNull ?? articleListe;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Poignée
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(article.nom,
                    style: Theme.of(ctx).textTheme.titleMedium),
                if (article.marque != null)
                  Text(article.marque!,
                      style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 20),

                // Quantité — sheet reste ouverte
                Row(
                  children: [
                    Text('Quantité :',
                        style: Theme.of(ctx).textTheme.bodyMedium),
                    const Spacer(),
                    IconButton(
                      onPressed: alActuel.quantite > 1
                          ? () => r
                              .read(articlesListeProvider(listeId).notifier)
                              .modifierQuantite(alActuel, alActuel.quantite - 1)
                          : null,
                      tooltip: 'Diminuer la quantité',
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: alActuel.quantite > 1
                            ? Theme.of(ctx).colorScheme.primary
                            : Theme.of(ctx).colorScheme.outline,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Text(
                        '${alActuel.quantite}',
                        key: ValueKey(alActuel.quantite),
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(ctx).colorScheme.primary,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => r
                          .read(articlesListeProvider(listeId).notifier)
                          .modifierQuantite(alActuel, alActuel.quantite + 1),
                      tooltip: 'Augmenter la quantité',
                      icon: Icon(Icons.add_circle_outline,
                          color: Theme.of(ctx).colorScheme.primary),
                    ),
                  ],
                ),
                const Divider(),

                // Fermer
                ListTile(
                  leading: Icon(Icons.check,
                      color: Theme.of(ctx).colorScheme.primary),
                  title: const Text('Fermer'),
                  onTap: () => Navigator.pop(sheetCtx),
                ),

                // Supprimer
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Retirer de la liste',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    final alSupprime = alActuel;
                    r.read(articlesListeProvider(listeId).notifier)
                        .supprimer(alSupprime.id);
                    Navigator.pop(sheetCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${article.nom}" retiré de la liste'),
                        action: SnackBarAction(
                          label: 'Annuler',
                          onPressed: () => ref
                              .read(articlesListeProvider(listeId).notifier)
                              .ajouter(alSupprime),
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      // Pas de leading (rond supprimé)
      title: Text(
        article.nom,
        style: articleListe.coche
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.outline,
              )
            : const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: article.marque != null ? Text(article.marque!) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrixArticleBadge(article: article),
          if (articleListe.quantite > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '×${articleListe.quantite}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () => ref
          .read(articlesListeProvider(listeId).notifier)
          .cocher(articleListe, !articleListe.coche),
      onLongPress: () => _afficherOptions(context, ref),
    );
  }
}

// ================================================================
// SÉLECTION D'ARTICLES DEPUIS LE CATALOGUE
// ================================================================
class _SelectionArticlesSheet extends ConsumerStatefulWidget {
  final String listeId;
  const _SelectionArticlesSheet({required this.listeId});

  @override
  ConsumerState<_SelectionArticlesSheet> createState() =>
      _SelectionArticlesSheetState();
}

class _SelectionArticlesSheetState
    extends ConsumerState<_SelectionArticlesSheet> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selectionIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(articlesNotifierProvider);
    final query = _searchCtrl.text.toLowerCase();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _selectionIds.isEmpty ? null : _valider,
                  child: Text('Ajouter (${_selectionIds.length})'),
                ),
              ],
            ),
          ),
          Flexible(
            child: articlesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (articles) {
                final filtres = articles
                    .where((a) =>
                        query.isEmpty ||
                        a.nom.toLowerCase().contains(query))
                    .toList();
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtres.length,
                  itemBuilder: (_, i) {
                    final a = filtres[i];
                    final selectionne = _selectionIds.contains(a.id);
                    return CheckboxListTile(
                      value: selectionne,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selectionIds.add(a.id);
                        } else {
                          _selectionIds.remove(a.id);
                        }
                      }),
                      title: Text(a.nom),
                      subtitle: a.marque != null ? Text(a.marque!) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _valider() {
    for (final id in _selectionIds) {
      ref.read(articlesListeProvider(widget.listeId).notifier).ajouter(
            ArticleListe(
              id: 'al_${const Uuid().v4()}',
              listeId: widget.listeId,
              articleId: id,
            ),
          );
    }
    Navigator.pop(context);
  }
}

// ================================================================
// MODE COURSES — cochés descendent automatiquement en bas
// ================================================================
class ModeCoursesScreen extends ConsumerWidget {
  final ListeCourses liste;
  const ModeCoursesScreen({super.key, required this.liste});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesListeAsync = ref.watch(articlesListeProvider(liste.id));
    final catalogueAsync = ref.watch(articlesNotifierProvider);
    final rayonsAsync = ref.watch(rayonsNotifierProvider);

    final total = ref.watch(afficherPrixProvider)
        ? ref.watch(totalListeProvider(liste.id))
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(liste.nom),
        bottom: total > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '≈ ${total.toStringAsFixed(2)} €',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              )
            : null,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_done),
            tooltip: 'Tout décocher',
            onPressed: () => ref
                .read(articlesListeProvider(liste.id).notifier)
                .cocherTous(false),
          ),
          PopupMenuButton(
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'tout_cocher', child: Text('Tout cocher')),
              PopupMenuItem(value: 'tout_decocher', child: Text('Tout décocher')),
            ],
            onSelected: (action) => ref
                .read(articlesListeProvider(liste.id).notifier)
                .cocherTous(action == 'tout_cocher'),
          ),
        ],
      ),
      body: articlesListeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (items) => catalogueAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur : $e')),
          data: (catalogue) => rayonsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (rayons) {
              // Séparer cochés / non cochés
              final nonCoches = <(ArticleListe, Article)>[];
              final coches = <(ArticleListe, Article)>[];

              for (final item in items) {
                final article =
                    catalogue.where((a) => a.id == item.articleId).firstOrNull;
                if (article == null) continue;
                if (item.coche) {
                  coches.add((item, article));
                } else {
                  nonCoches.add((item, article));
                }
              }

              // Grouper non-cochés par rayon (trié par ordre)
              final Map<String, List<(ArticleListe, Article)>> parRayon = {};
              for (final entry in nonCoches) {
                final key = entry.$2.rayonId ?? '__sans_rayon__';
                parRayon.putIfAbsent(key, () => []).add(entry);
              }
              // Tri alphabétique à l'intérieur de chaque rayon
              for (final key in parRayon.keys) {
                parRayon[key]!.sort((a, b) =>
                    a.$2.nom.toLowerCase().compareTo(b.$2.nom.toLowerCase()));
              }
              final clesRayon = parRayon.keys.toList()
                ..sort((a, b) {
                  if (a == '__sans_rayon__') return 1;
                  if (b == '__sans_rayon__') return -1;
                  final ra = rayons.where((r) => r.id == a).firstOrNull;
                  final rb = rayons.where((r) => r.id == b).firstOrNull;
                  return (ra?.ordre ?? 99).compareTo(rb?.ordre ?? 99);
                });

              final total = items.length;
              final nbCoches = coches.length;
              final progression = total == 0 ? 0.0 : nbCoches / total;

              final widgets = <Widget>[];

              // Barre de progression
              widgets.add(_BarreProgression(
                nbCoches: nbCoches,
                total: total,
                progression: progression,
              ));

              // Bannière "terminé" si tout est coché
              if (nonCoches.isEmpty && coches.isNotEmpty) {
                widgets.add(_BanniereTermine(
                  onDecocher: () => ref
                      .read(articlesListeProvider(liste.id).notifier)
                      .cocherTous(false),
                ));
              }

              // Non-cochés groupés par rayon
              for (final cle in clesRayon) {
                final rayon = cle == '__sans_rayon__'
                    ? null
                    : rayons.where((r) => r.id == cle).firstOrNull;
                final articlesRayon = parRayon[cle]!
                    .where((e) => !e.$1.coche)
                    .toList();
                if (articlesRayon.isEmpty) continue;

                widgets.add(_RayonHeader(
                  nom: rayon?.nom ?? 'Sans rayon',
                  nbRestants: articlesRayon.length,
                ));

                for (final entry in articlesRayon) {
                  widgets.add(_ModeCoursesItem(
                    key: ValueKey(entry.$1.id),
                    articleListe: entry.$1,
                    article: entry.$2,
                    listeId: liste.id,
                  ));
                }
              }

              // Cochés en bas
              if (coches.isNotEmpty) {
                widgets.add(const _SeparateurCoches());
                for (final entry in coches) {
                  widgets.add(_ModeCoursesItem(
                    key: ValueKey(entry.$1.id),
                    articleListe: entry.$1,
                    article: entry.$2,
                    listeId: liste.id,
                  ));
                }
              }

              widgets.add(const SizedBox(height: 32));
              return ListView(children: widgets);
            },
          ),
        ),
      ),
    );
  }
}

class _BarreProgression extends StatelessWidget {
  final int nbCoches;
  final int total;
  final double progression;
  const _BarreProgression({
    required this.nbCoches,
    required this.total,
    required this.progression,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${total - nbCoches} restants',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '$nbCoches / $total',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progression,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                progression >= 1.0
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RayonHeader extends StatelessWidget {
  final String nom;
  final int nbRestants;
  const _RayonHeader({required this.nom, required this.nbRestants});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            nom,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$nbRestants',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeparateurCoches extends StatelessWidget {
  const _SeparateurCoches();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  'Déjà dans le panier',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _BanniereTermine extends StatelessWidget {
  final VoidCallback onDecocher;
  const _BanniereTermine({required this.onDecocher});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration, color: Colors.green, size: 36),
          const SizedBox(height: 8),
          Text(
            'Courses terminées !',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onDecocher,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Tout décocher'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
          ),
        ],
      ),
    );
  }
}

class _ModeCoursesItem extends ConsumerWidget {
  final ArticleListe articleListe;
  final Article article;
  final String listeId;

  const _ModeCoursesItem({
    super.key,
    required this.articleListe,
    required this.article,
    required this.listeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coche = articleListe.coche;
    return AnimatedOpacity(
      opacity: coche ? 0.45 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => ref
              .read(articlesListeProvider(listeId).notifier)
              .cocher(articleListe, !coche),
          child: AnimatedCheckIcon(
            checked: coche,
            color: coche
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        title: Text(
          article.nom,
          style: coche
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Theme.of(context).colorScheme.outline,
                )
              : const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: article.marque != null
            ? Text(article.marque!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!coche) ...[
              PrixArticleBadge(article: article),
              const SizedBox(width: 8),
            ],
            Text(
              '× ${articleListe.quantite}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: coche
                        ? Theme.of(context).colorScheme.outline
                        : null,
                  ),
            ),
          ],
        ),
        onTap: () => ref
            .read(articlesListeProvider(listeId).notifier)
            .cocher(articleListe, !coche),
      ),
    );
  }
}


// ================================================================
// BOTTOM SHEET DE PARTAGE
// ================================================================
class _PartageSheet extends ConsumerStatefulWidget {
  final ListeCourses liste;
  final String texte;
  final List<ArticleListe> items;
  final List<Article> catalogue;
  final List<Rayon> rayons;
  const _PartageSheet({
    required this.liste,
    required this.texte,
    required this.items,
    required this.catalogue,
    required this.rayons,
  });

  @override
  ConsumerState<_PartageSheet> createState() => _PartageSheetState();
}

class _PartageSheetState extends ConsumerState<_PartageSheet> {
  bool _generationPdfEnCours = false;

  Future<void> _exporterPdf() async {
    setState(() => _generationPdfEnCours = true);
    final service = ref.read(partageServiceProvider);
    try {
      final bytes = await service.genererPdf(
        liste: widget.liste,
        items: widget.items,
        catalogue: widget.catalogue,
        rayons: widget.rayons,
      );
      await service.partagerPdf(liste: widget.liste, bytes: bytes);
    } catch (e) {
      if (mounted) _afficherErreur(context, e);
    } finally {
      if (mounted) setState(() => _generationPdfEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = widget.liste;
    final texte = widget.texte;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Partager « ${liste.nom} »',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Aperçu du texte
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                texte,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Boutons d'action
          Row(
            children: [
              // Copier dans le presse-papier
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(partageServiceProvider)
                        .copierPressePapier(texte);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Liste copiée dans le presse-papier'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier'),
                ),
              ),
              const SizedBox(width: 12),

              // Partager via menu natif (SMS, WhatsApp, etc.)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref
                        .read(partageServiceProvider)
                        .partagerListe(liste: liste, texte: texte);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Envoyer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Export PDF (mise en page par rayon, cases à cocher)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _generationPdfEnCours ? null : _exporterPdf,
              icon: _generationPdfEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Exporter en PDF'),
            ),
          ),
        ],
      ),
    );
  }
}
