import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Une prédiction du modèle : l'étiquette brute (anglais, ex. "Apple Braeburn"),
// le nom français regroupé (ex. "Pomme") et la confiance (0..1).
class PredictionAliment {
  final String label;
  final String nom;
  final double confiance;
  const PredictionAliment(
      {required this.label, required this.nom, required this.confiance});
}

// Reconnaissance d'un aliment (fruit/légume) sur une photo, 100 % sur
// l'appareil via un modèle TensorFlow Lite (assets/aliments.tflite), entraîné
// séparément (voir ml/). Aucune donnée n'est envoyée sur un serveur.
class ReconnaissanceAlimentService {
  static const _tailleEntree = 224; // le modèle attend des images 224×224

  Interpreter? _interpreter;
  List<String>? _labels;

  Future<void> _charger() async {
    _interpreter ??= await Interpreter.fromAsset('assets/aliments.tflite');
    if (_labels == null) {
      final txt = await rootBundle.loadString('assets/aliments_labels.txt');
      _labels = txt
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }
  }

  // Classe une image (octets JPEG/PNG) et renvoie les [topK] meilleures
  // hypothèses, de la plus probable à la moins probable.
  Future<List<PredictionAliment>> classer(Uint8List bytes,
      {int topK = 3}) async {
    await _charger();
    final labels = _labels!;

    final decodee = img.decodeImage(bytes);
    if (decodee == null) return [];
    final image =
        img.copyResize(decodee, width: _tailleEntree, height: _tailleEntree);

    // Entrée [1, 224, 224, 3], pixels normalisés dans [-1, 1] — exactement le
    // prétraitement du notebook d'entraînement (Rescaling 1/127.5, offset -1).
    final entree = List.generate(
      1,
      (_) => List.generate(
        _tailleEntree,
        (y) => List.generate(_tailleEntree, (x) {
          final p = image.getPixel(x, y);
          return [p.r / 127.5 - 1, p.g / 127.5 - 1, p.b / 127.5 - 1];
        }),
      ),
    );

    final sortie = List.filled(labels.length, 0.0).reshape([1, labels.length]);
    _interpreter!.run(entree, sortie);
    final probas = (sortie[0] as List).cast<double>();

    final indices = List.generate(probas.length, (i) => i)
      ..sort((a, b) => probas[b].compareTo(probas[a]));
    return indices.take(topK).map((i) {
      return PredictionAliment(
        label: labels[i],
        nom: nomFrancais(labels[i]),
        confiance: probas[i],
      );
    }).toList();
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  // Regroupe les variétés (l'étiquette commence par le nom de base, ex.
  // "Apple Golden 1", "Apple Red 2"…) vers un nom français simple.
  static String nomFrancais(String label) {
    final base = label.split(' ').first;
    return _fr[base] ?? label;
  }

  static const Map<String, String> _fr = {
    'Apple': 'Pomme',
    'Apricot': 'Abricot',
    'Avocado': 'Avocat',
    'Banana': 'Banane',
    'Beetroot': 'Betterave',
    'Blueberry': 'Myrtille',
    'Cactus': 'Figue de Barbarie',
    'Cantaloupe': 'Melon',
    'Carambula': 'Carambole',
    'Cauliflower': 'Chou-fleur',
    'Cherry': 'Cerise',
    'Chestnut': 'Châtaigne',
    'Clementine': 'Clémentine',
    'Cocos': 'Noix de coco',
    'Corn': 'Maïs',
    'Cucumber': 'Concombre',
    'Dates': 'Dattes',
    'Eggplant': 'Aubergine',
    'Fig': 'Figue',
    'Ginger': 'Gingembre',
    'Granadilla': 'Grenadille',
    'Grape': 'Raisin',
    'Grapefruit': 'Pamplemousse',
    'Guava': 'Goyave',
    'Hazelnut': 'Noisette',
    'Huckleberry': 'Myrtille',
    'Kaki': 'Kaki',
    'Kiwi': 'Kiwi',
    'Kohlrabi': 'Chou-rave',
    'Kumquats': 'Kumquat',
    'Lemon': 'Citron',
    'Limes': 'Citron vert',
    'Lychee': 'Litchi',
    'Mandarine': 'Mandarine',
    'Mango': 'Mangue',
    'Mangostan': 'Mangoustan',
    'Maracuja': 'Fruit de la passion',
    'Melon': 'Melon',
    'Mulberry': 'Mûre',
    'Nectarine': 'Nectarine',
    'Nut': 'Noix',
    'Onion': 'Oignon',
    'Orange': 'Orange',
    'Papaya': 'Papaye',
    'Passion': 'Fruit de la passion',
    'Peach': 'Pêche',
    'Pear': 'Poire',
    'Pepino': 'Poire-melon',
    'Pepper': 'Poivron',
    'Physalis': 'Physalis',
    'Pineapple': 'Ananas',
    'Pitahaya': 'Pitaya',
    'Plum': 'Prune',
    'Pomegranate': 'Grenade',
    'Pomelo': 'Pomélo',
    'Potato': 'Pomme de terre',
    'Quince': 'Coing',
    'Rambutan': 'Ramboutan',
    'Raspberry': 'Framboise',
    'Redcurrant': 'Groseille',
    'Salak': 'Salak',
    'Strawberry': 'Fraise',
    'Tamarillo': 'Tamarillo',
    'Tangelo': 'Tangelo',
    'Tomato': 'Tomate',
    'Walnut': 'Noix',
    'Watermelon': 'Pastèque',
  };
}
