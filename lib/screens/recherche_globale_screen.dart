import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import 'listes_screen.dart';

// ================================================================
// RECHERCHE GLOBALE — catalogue, listes, et articles dans les listes
// ================================================================
class RechercheGlobaleScreen extends ConsumerStatefulWidget {
  const RechercheGlobaleScreen({super.key});

  @override
  ConsumerState<RechercheGlobaleScreen> createState() =>
      _RechercheGlobaleScreenState();
}

class _RechercheGlobaleScreenState
    extends ConsumerState<RechercheGlobaleScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _resultatsListes = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _rechercher(String query) async {
    setState(() => _query = query);
    if (query.trim().isEmpty) {
      setState(() => _resultatsListes = []);
      return;
    }
    final resultats =
        await ref.read(dbServiceProvider).rechercherArticlesDansListes(query.trim());
    if (mounted && _ctrl.text == query) {
      setState(() => _resultatsListes = resultats);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final articles = ref.watch(articlesNotifierProvider).valueOrNull ?? [];
    final listes = ref.watch(listesNotifierProvider).valueOrNull ?? [];

    final articlesTrouves = q.isEmpty
        ? <dynamic>[]
        : articles.where((a) =>
            a.nom.toLowerCase().contains(q) ||
            (a.marque?.toLowerCase().contains(q) ?? false)).toList();

    final listesTrouvees = q.isEmpty
        ? <dynamic>[]
        : listes.where((l) => l.nom.toLowerCase().contains(q)).toList();

    final aucunResultat = q.isNotEmpty &&
        articlesTrouves.isEmpty &&
        listesTrouvees.isEmpty &&
        _resultatsListes.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Rechercher un article, une liste…',
            border: InputBorder.none,
          ),
          style: Theme.of(context).textTheme.titleMedium,
          onChanged: _rechercher,
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Effacer',
              onPressed: () {
                _ctrl.clear();
                _rechercher('');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Cherche un article ou une liste'),
              ),
            )
          : aucunResultat
              ? const Center(child: Text('Aucun résultat'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (listesTrouvees.isNotEmpty) ...[
                      Text('Listes',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final l in listesTrouvees)
                        ListTile(
                          leading: const Icon(Icons.shopping_cart_outlined),
                          title: Text(l.nom),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DetailListeScreen(liste: l)),
                          ),
                        ),
                      const Divider(),
                    ],
                    if (articlesTrouves.isNotEmpty) ...[
                      Text('Catalogue',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final a in articlesTrouves)
                        ListTile(
                          leading: const Icon(Icons.inventory_2_outlined),
                          title: Text(a.nom),
                          subtitle: a.marque != null ? Text(a.marque!) : null,
                        ),
                      const Divider(),
                    ],
                    if (_resultatsListes.isNotEmpty) ...[
                      Text('Dans vos listes',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final r in _resultatsListes)
                        ListTile(
                          leading: Icon(
                            (r['coche'] as int? ?? 0) == 1
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(r['articleNom'] as String),
                          subtitle: Text('dans « ${r['listeNom']} »'),
                        ),
                    ],
                  ],
                ),
    );
  }
}
