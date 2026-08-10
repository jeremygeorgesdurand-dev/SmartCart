import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/reconnaissance_aliment_service.dart';
import '../utils/erreur_utils.dart';
import '../utils/theme_utils.dart';

// Reconnaissance d'un fruit/légume par photo, via le modèle TFLite local
// (voir ml/). L'utilisateur prend UNE photo d'un aliment centré ; l'app
// propose son nom et permet de l'ajouter au catalogue.
class ScannerAlimentScreen extends ConsumerStatefulWidget {
  const ScannerAlimentScreen({super.key});

  @override
  ConsumerState<ScannerAlimentScreen> createState() =>
      _ScannerAlimentScreenState();
}

class _ScannerAlimentScreenState extends ConsumerState<ScannerAlimentScreen> {
  final _picker = ImagePicker();
  Uint8List? _image;
  List<PredictionAliment>? _resultats;
  bool _analyse = false;
  String? _erreur;

  // En dessous de ce score, on prévient que le résultat est incertain.
  static const _seuilConfiance = 0.50;

  Future<void> _prendre(ImageSource source) async {
    try {
      final fichier = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (fichier == null) return;
      final bytes = await fichier.readAsBytes();
      setState(() {
        _image = bytes;
        _resultats = null;
        _erreur = null;
        _analyse = true;
      });
      final resultats =
          await ref.read(reconnaissanceAlimentServiceProvider).classer(bytes);
      if (!mounted) return;
      setState(() {
        _resultats = resultats;
        _analyse = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyse = false;
        _erreur = messageErreurLisible(e, 'Analyse impossible');
      });
    }
  }

  Future<void> _ajouterAuCatalogue(PredictionAliment p) async {
    final articles = ref.read(articlesNotifierProvider).valueOrNull ?? [];
    final existe = articles.any(
        (a) => a.nom.toLowerCase().trim() == p.nom.toLowerCase().trim());
    if (existe) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${p.nom}" est déjà dans le catalogue')),
      );
      return;
    }
    await ref.read(articlesNotifierProvider.notifier).ajouter(
          Article(id: 'art_${const Uuid().v4()}', nom: p.nom),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${p.nom}" ajouté au catalogue'),
      backgroundColor: couleurSucces(context),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reconnaître un aliment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Prends une photo d\'UN fruit ou légume, bien centré et net. '
            'L\'analyse se fait sur ton téléphone, sans connexion.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          if (_image != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_image!,
                  height: 220, width: double.infinity, fit: BoxFit.cover),
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
          const SizedBox(height: 24),
          if (_analyse)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Analyse en cours…'),
                  ],
                ),
              ),
            ),
          if (_erreur != null)
            Text(_erreur!,
                style: TextStyle(color: couleurDanger(context))),
          if (_resultats != null) _buildResultats(context),
        ],
      ),
    );
  }

  Widget _buildResultats(BuildContext context) {
    final resultats = _resultats!;
    if (resultats.isEmpty) {
      return const Text('Aucun aliment reconnu. Réessaie avec une photo '
          'plus nette d\'un seul aliment.');
    }
    final meilleur = resultats.first;
    final incertain = meilleur.confiance < _seuilConfiance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (incertain)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.help_outline,
                    size: 18, color: couleurAvertissement(context)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pas sûr — vérifie la proposition ou reprends la photo.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Text('Résultat',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final p in resultats)
          Card(
            child: ListTile(
              title: Text(p.nom,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${(p.confiance * 100).toStringAsFixed(0)} % '
                  '· ${p.label}'),
              trailing: FilledButton(
                onPressed: () => _ajouterAuCatalogue(p),
                child: const Text('Ajouter'),
              ),
            ),
          ),
      ],
    );
  }
}
