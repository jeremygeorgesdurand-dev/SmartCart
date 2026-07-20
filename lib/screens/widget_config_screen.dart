import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/widget_service.dart';

class WidgetConfigScreen extends ConsumerStatefulWidget {
  const WidgetConfigScreen({super.key});

  @override
  ConsumerState<WidgetConfigScreen> createState() => _WidgetConfigScreenState();
}

class _WidgetConfigScreenState extends ConsumerState<WidgetConfigScreen> {
  String? _listeWidgetId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _chargerConfig();
  }

  Future<void> _chargerConfig() async {
    final id = await WidgetService.getListeWidgetId();
    if (mounted) setState(() => _listeWidgetId = id);
  }

  Future<void> _choisirListe(String listeId, String listeNom) async {
    setState(() => _saving = true);

    final items = await ref.read(dbServiceProvider).getArticlesListe(listeId);
    final catalogue = await ref.read(articlesNotifierProvider.future);
    final listes = await ref.read(listesNotifierProvider.future);
    final liste = listes.where((l) => l.id == listeId).firstOrNull;

    if (liste == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    await WidgetService.mettreAJourWidget(
      liste: liste,
      items: items,
      catalogue: catalogue,
    );

    if (!mounted) return;

    setState(() {
      _listeWidgetId = listeId;
      _saving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"$listeNom" configurée pour le widget'),
        backgroundColor: Colors.green,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final listesAsync = ref.watch(listesNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Widget écran d\'accueil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Aperçu du widget
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF006B5E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🛒 ', style: TextStyle(fontSize: 18)),
                    Expanded(
                      child: Text(
                        _listeWidgetId != null
                            ? (listesAsync.valueOrNull
                                    ?.where((l) => l.id == _listeWidgetId)
                                    .firstOrNull
                                    ?.nom ??
                                'Ma liste')
                            : 'Sélectionnez une liste',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Text('0/5',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const LinearProgressIndicator(
                    value: 0,
                    minHeight: 5,
                    backgroundColor: Color(0x44FFFFFF),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                ...[
                  '○  Pain',
                  '○  Lait',
                  '○  Yaourts',
                ].map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(t,
                          style: const TextStyle(
                              color: Color(0xEEFFFFFF), fontSize: 12)),
                    )),
                const SizedBox(height: 4),
                const Text('+ 2 articles',
                    style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aperçu du widget (la vraie liste s\'affichera sur votre écran d\'accueil)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Titre section
          Text('Choisir la liste à afficher',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  )),
          const SizedBox(height: 12),

          // Liste des listes
          listesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erreur: $e'),
            data: (listes) {
              if (listes.isEmpty) {
                return const Text('Aucune liste disponible');
              }
              return Column(
                children: listes.map((liste) {
                  final isSelected = _listeWidgetId == liste.id;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.shopping_cart,
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(liste.nom,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: liste.magasin != null
                          ? Text(liste.magasin!)
                          : null,
                      trailing: isSelected
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary)
                          : const Icon(Icons.radio_button_unchecked),
                      onTap: _saving
                          ? null
                          : () => _choisirListe(liste.id, liste.nom),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Instructions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comment ajouter le widget',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  ...[
                    ('1.', 'Appui long sur l\'écran d\'accueil Android'),
                    ('2.', 'Sélectionner "Widgets"'),
                    ('3.', 'Chercher "SmartCart"'),
                    ('4.', 'Maintenir et déposer sur l\'écran'),
                  ].map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(step.$1,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    )),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(step.$2)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
