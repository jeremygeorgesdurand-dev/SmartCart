import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Un fragment de texte OCR avec sa position à l'écran (repère pour reconstituer
// les lignes d'un ticket en colonnes).
class FragmentTicket {
  final String text;
  final double top;
  final double bottom;
  final double left;
  const FragmentTicket(
      {required this.text,
      required this.top,
      required this.bottom,
      required this.left});
}

// Une ligne d'article détectée sur un ticket de caisse : un nom de produit
// et son prix unitaire (€).
class LigneTicket {
  final String nom;
  final double prix;
  const LigneTicket({required this.nom, required this.prix});
}

class ResultatTicket {
  final String? enseigne; // magasin détecté (Carrefour, Lidl…), si trouvé
  final List<LigneTicket> lignes;
  final String texteBrut; // texte OCR complet, utile en cas de mise au point
  const ResultatTicket({
    required this.enseigne,
    required this.lignes,
    required this.texteBrut,
  });
}

// Lit un ticket de caisse depuis une photo, ENTIÈREMENT sur l'appareil et
// hors-ligne, via la reconnaissance de texte de ML Kit (gratuite, embarquée).
// Aucune image ni donnée n'est envoyée sur un serveur.
//
// Le parsing est calé sur le format des tickets d'hypermarché français
// (Carrefour, Leclerc, Intermarché… — structure très répandue) :
//
//   TVA%   NOM DU PRODUIT    QTE x P.U.   MONTANT
//   5.5%   6XOEUFS DJP SOL CR   1 x 1.54     1.54
//   5.5%   KIWI VERT PIECE     10 x 0.75     7.50
//
// On récupère le NOM et le PRIX UNITAIRE (P.U.), plus utile que le montant
// total de la ligne (ex. kiwi à 0,75 € l'unité plutôt que 7,50 € les dix).
// L'écran laisse toujours l'utilisateur vérifier/corriger avant d'enregistrer.
class TicketOcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static const _enseignes = [
    'Carrefour', 'Leclerc', 'E.Leclerc', 'Lidl', 'Aldi', 'Auchan',
    'Intermarché', 'Intermarche', 'Super U', 'Hyper U', 'Système U',
    'Systeme U', 'Casino', 'Monoprix', 'Franprix', 'Netto', 'Cora',
    'Grand Frais', 'Biocoop', 'Picard', 'Naturalia', 'Match',
  ];

  // Une fois ces mentions rencontrées, on ARRÊTE de lire des articles : ce qui
  // suit (totaux, moyen de paiement, détail des avantages fidélité) contient
  // des lignes « nom + prix » qui ne sont PAS des achats et fausseraient tout.
  static final _reFinArticles = RegExp(
    r'total\s+(à|a)\s+payer|avantages?\s+fid|détails?\s+de\s+vos|'
    r'total\s+avant|montant\s+d(û|u)',
    caseSensitive: false,
  );

  // Lignes à ignorer (remises, sous-totaux, en-têtes, TVA, détail au poids).
  static final _reIgnorer = RegExp(
    r'^\s*(remise|total|sous.?total|tva\b|dont\s+tva|net\s+|'
    r'pay(é|e)|carte|esp(è|e)ce|rendu|monnaie|nb\b|nbre|articles?\b|'
    r'\d+[.,]\d+\s*kg\s*[xX]|ticket|merci|siret|t(é|e)l\b|caisse)',
    caseSensitive: false,
  );

  // Format principal : … QTE x P.U. MONTANT (en fin de ligne).
  static final _reArticle = RegExp(
    r'^(?:\d{1,2}(?:[.,]\d)?\s*%\s+)?' // TVA optionnelle en tête (5.5%, 10%…)
    r'(.+?)\s+' // nom (non gourmand)
    r'(\d{1,3})\s*[xX]\s*' // quantité
    r'(\d{1,4}[.,]\d{2})\s+' // prix unitaire
    r'(\d{1,4}[.,]\d{2})\s*€?\s*$', // montant total
  );

  // Repli : … NOM … PRIX (un seul montant en fin de ligne), pour les tickets
  // qui n'affichent pas la décomposition « QTE x P.U. ».
  static final _reSimple = RegExp(
    r'^(?:\d{1,2}(?:[.,]\d)?\s*%\s+)?(.+?)\s+(\d{1,4}[.,]\d{2})\s*€?\s*[A-Z]?\s*$',
  );

  Future<ResultatTicket> analyser(String cheminImage) async {
    final input = InputImage.fromFilePath(cheminImage);
    final texte = await _recognizer.processImage(input);
    return parserLignes(_reconstruireLignes(texte));
  }

  // Sur un ticket, les colonnes (TVA · nom · qté×P.U. · montant) sont très
  // écartées horizontalement : ML Kit les rend souvent comme des fragments
  // SÉPARÉS et non comme une ligne complète. On les REGROUPE ici par bande
  // horizontale (même hauteur à l'écran), puis on les lit de gauche à droite
  // pour reconstituer la vraie ligne « 5.5% NOM 1 x 1.54 1.54 ».
  List<String> _reconstruireLignes(RecognizedText texte) {
    final frags = <FragmentTicket>[];
    for (final block in texte.blocks) {
      for (final line in block.lines) {
        final b = line.boundingBox;
        frags.add(FragmentTicket(
          text: line.text,
          top: b.top.toDouble(),
          bottom: b.bottom.toDouble(),
          left: b.left.toDouble(),
        ));
      }
    }
    return regrouperEnLignes(frags);
  }

  // Regroupe des fragments de texte (avec leur position) en lignes logiques,
  // par bande horizontale puis lecture de gauche à droite. Public pour être
  // testable indépendamment de ML Kit.
  List<String> regrouperEnLignes(List<FragmentTicket> frags) {
    if (frags.isEmpty) return const [];
    final tries = [...frags]..sort((a, b) => a.top.compareTo(b.top));
    final rangees = <List<FragmentTicket>>[];
    for (final f in tries) {
      final centre = (f.top + f.bottom) / 2;
      // Un fragment rejoint une rangée si son centre vertical tombe dans sa
      // bande (tolérance = 30 % de la hauteur de la rangée).
      List<FragmentTicket>? cible;
      for (final r in rangees) {
        var rTop = double.infinity, rBottom = double.negativeInfinity;
        for (final e in r) {
          if (e.top < rTop) rTop = e.top;
          if (e.bottom > rBottom) rBottom = e.bottom;
        }
        final tol = (rBottom - rTop) * 0.3;
        if (centre >= rTop - tol && centre <= rBottom + tol) {
          cible = r;
          break;
        }
      }
      (cible ?? (rangees..add(<FragmentTicket>[])).last).add(f);
    }
    return rangees.map((r) {
      r.sort((a, b) => a.left.compareTo(b.left));
      return r.map((e) => e.text).join(' ');
    }).toList();
  }

  // Parsing pur (sans OCR) : isolé pour être testable avec de vraies lignes de
  // ticket, indépendamment de ML Kit.
  ResultatTicket parserLignes(List<String> lignesTexte) {
    final enseigne = _detecterEnseigne(lignesTexte);
    final lignes = <LigneTicket>[];
    for (final brut in lignesTexte) {
      // Dès la zone des totaux / fidélité, on s'arrête : plus aucun achat.
      if (_reFinArticles.hasMatch(brut)) break;
      final ligne = _parserLigne(brut);
      if (ligne != null) lignes.add(ligne);
    }
    return ResultatTicket(
      enseigne: enseigne,
      lignes: lignes,
      texteBrut: lignesTexte.join('\n'),
    );
  }

  String? _detecterEnseigne(List<String> lignes) {
    final entete = lignes.take(15).join(' ').toLowerCase();
    for (final e in _enseignes) {
      if (entete.contains(e.toLowerCase())) return e;
    }
    return null;
  }

  LigneTicket? _parserLigne(String brut) {
    final ligne = brut.trim();
    if (ligne.isEmpty || _reIgnorer.hasMatch(ligne)) return null;

    // 1) Format « QTE x P.U. MONTANT » → on prend le prix UNITAIRE.
    final m = _reArticle.firstMatch(ligne);
    if (m != null) {
      final prix = double.tryParse(m.group(3)!.replaceAll(',', '.'));
      return _construire(m.group(1)!, prix);
    }

    // 2) Repli : un seul prix en fin de ligne.
    final s = _reSimple.firstMatch(ligne);
    if (s != null) {
      final prix = double.tryParse(s.group(2)!.replaceAll(',', '.'));
      return _construire(s.group(1)!, prix);
    }

    return null;
  }

  LigneTicket? _construire(String nomBrut, double? prix) {
    if (prix == null || prix <= 0 || prix > 9999) return null;
    var nom = nomBrut.replaceAll(RegExp(r'[€*]'), '').trim();
    // Retire les préfixes de conditionnement/poids collés en tête de nom, qui
    // empêchent de retrouver l'article au catalogue ("240G 6 BLANC POULE" →
    // "BLANC POULE", "6X120ML CONE VANI" → "CONE VANI", "6XOEUFS" → "OEUFS").
    // On applique jusqu'à ce qu'il n'y ait plus de préfixe numérique.
    for (var i = 0; i < 3; i++) {
      final avant = nom;
      nom = nom
          // "3X20CL", "4X1.25L", "6X120ML"
          .replaceFirst(
              RegExp(r'^\d+\s*[xX]\s*\d+([.,]\d+)?\s*(kg|g|ml|cl|l)?\b',
                  caseSensitive: false),
              '')
          // "240G", "1KG", "37CL", "1L"
          .replaceFirst(
              RegExp(r'^\d+([.,]\d+)?\s*(kg|g|ml|cl|l)\b', caseSensitive: false),
              '')
          // "6XOEUFS" (multipack collé à une lettre)
          .replaceFirst(RegExp(r'^\d+\s*[xX](?=[A-Za-zÀ-ÿ])'), '')
          // compte isolé en tête : "6 BLANC POULE" → "BLANC POULE"
          .replaceFirst(RegExp(r'^\d+\s+(?=[A-Za-zÀ-ÿ])'), '')
          .trim();
      if (nom == avant) break;
    }
    nom = nom.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Nom trop court ou sans vraie lettre → probablement pas un produit.
    if (nom.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length < 2) return null;
    // Jolie casse : "KIWI VERT PIECE" → "Kiwi vert piece".
    final nomPropre =
        nom.length <= 1 ? nom : nom[0].toUpperCase() + nom.substring(1).toLowerCase();
    return LigneTicket(nom: nomPropre, prix: prix);
  }

  Future<void> dispose() => _recognizer.close();
}
