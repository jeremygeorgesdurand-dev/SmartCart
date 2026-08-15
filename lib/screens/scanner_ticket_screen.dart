import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/erreur_utils.dart';
import '../utils/theme_utils.dart';

// Une ligne éditable proposée à partir du ticket : nom + prix + magasin
// hérité de l'enseigne, avec des contrôleurs de saisie pour que l'utilisateur
// corrige avant d'enregistrer.
class _LigneEditable {
  final TextEditingController nom;
  final TextEditingController prix;
  bool inclure;
  _LigneEditable({required String nom, required double prix})
      : nom = TextEditingController(text: nom),
        prix = TextEditingController(text: prix.toStringAsFixed(2)),
        inclure = true;

  void dispose() {
    nom.dispose();
    prix.dispose();
  }
}

// Lit un ticket de caisse en photo (OCR 100 % local, hors-ligne) et enregistre
// les prix trouvés pour les articles, avec l'enseigne. L'utilisateur vérifie
// et corrige chaque ligne avant d'enregistrer : l'OCR d'un ticket n'est jamais
// parfait (photo, format variable), on ne fait donc que pré-remplir.
class ScannerTicketScreen extends ConsumerStatefulWidget {
  const ScannerTicketScreen({super.key});

  @override
  ConsumerState<ScannerTicketScreen> createState() =>
      _ScannerTicketScreenState();
}

class _ScannerTicketScreenState extends ConsumerState<ScannerTicketScreen> {
  final _picker = ImagePicker();
  final _enseigneCtrl = TextEditingController();
  File? _image;
  List<_LigneEditable> _lignes = [];
  bool _analyse = false;
  bool _analyseFaite = false;
  String? _erreur;

  @override
  void dispose() {
    _enseigneCtrl.dispose();
    for (final l in _lignes) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _prendre(ImageSource source) async {
    try {
      final fichier = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (fichier == null) return;
      for (final l in _lignes) {
        l.dispose();
      }
      setState(() {
        _image = File(fichier.path);
        _lignes = [];
        _erreur = null;
        _analyse = true;
        _analyseFaite = false;
      });
      final resultat =
          await ref.read(ticketOcrServiceProvider).analyser(fichier.path);
      if (!mounted) return;
      setState(() {
        if (resultat.enseigne != null) _enseigneCtrl.text = resultat.enseigne!;
        _lignes = resultat.lignes
            .map((l) => _LigneEditable(nom: l.nom, prix: l.prix))
            .toList();
        _analyse = false;
        _analyseFaite = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyse = false;
        _erreur = messageErreurLisible(e, 'Lecture du ticket impossible');
      });
    }
  }

  Future<void> _enregistrer() async {
    final articlesNotifier = ref.read(articlesNotifierProvider.notifier);
    final prixNotifier = ref.read(prixArticlesNotifierProvider.notifier);
    final catalogue = ref.read(articlesNotifierProvider).valueOrNull ?? [];
    final magasin = _enseigneCtrl.text.trim();

    var enregistres = 0;
    for (final ligne in _lignes) {
      if (!ligne.inclure) continue;
      final nom = ligne.nom.text.trim();
      final prix = double.tryParse(ligne.prix.text.replaceAll(',', '.'));
      if (nom.isEmpty || prix == null || prix <= 0) continue;

      // On rattache le prix à un article existant si le nom correspond (aux
      // accents/casse près), sinon on crée un nouvel article au catalogue.
      final cle = cleTriAlpha(nom);
      var article =
          catalogue.where((a) => cleTriAlpha(a.nom) == cle).firstOrNull;
      article ??= Article(id: 'art_${const Uuid().v4()}', nom: nom);
      if (!catalogue.any((a) => a.id == article!.id)) {
        await articlesNotifier.ajouter(article);
      }
      await prixNotifier.definir(article.id, prix, magasin: magasin);
      enregistres++;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(enregistres == 0
          ? 'Aucun prix enregistré'
          : '$enregistres prix enregistré(s)'
              '${magasin.isNotEmpty ? " ($magasin)" : ""}'),
      backgroundColor: enregistres == 0 ? null : couleurSucces(context),
    ));
    if (enregistres > 0) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final aDesLignes = _lignes.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Prix depuis un ticket')),
      floatingActionButton: aDesLignes
          ? FloatingActionButton.extended(
              onPressed: _enregistrer,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer les prix'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Prends en photo ton ticket de caisse, bien à plat et net. '
            'La lecture se fait sur ton téléphone, sans connexion. '
            'Vérifie ensuite chaque ligne avant d\'enregistrer.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_image!,
                  height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _analyse ? null : () => _prendre(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _analyse ? null : () => _prendre(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galerie'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_analyse)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Lecture du ticket…'),
                ]),
              ),
            ),
          if (_erreur != null)
            Text(_erreur!, style: TextStyle(color: couleurDanger(context))),
          if (_analyseFaite && !aDesLignes && _erreur == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Aucun prix détecté. Reprends la photo bien à plat, '
                  'sans reflet, en cadrant les lignes d\'articles.'),
            ),
          if (aDesLignes) ...[
            TextField(
              controller: _enseigneCtrl,
              decoration: const InputDecoration(
                labelText: 'Magasin',
                hintText: 'Ex : Carrefour',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${_lignes.where((l) => l.inclure).length} '
                    'ligne(s) sélectionnée(s)',
                    style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(
                      () => _lignes.add(_LigneEditable(nom: '', prix: 0))),
                  child: const Text('Ajouter une ligne'),
                ),
              ],
            ),
            for (final ligne in _lignes) _buildLigne(ligne),
          ],
        ],
      ),
    );
  }

  Widget _buildLigne(_LigneEditable ligne) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        child: Row(
          children: [
            Checkbox(
              value: ligne.inclure,
              onChanged: (v) => setState(() => ligne.inclure = v ?? true),
            ),
            Expanded(
              flex: 3,
              child: TextField(
                controller: ligne.nom,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Article',
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: TextField(
                controller: ligne.prix,
                textAlign: TextAlign.right,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  suffixText: '€',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
