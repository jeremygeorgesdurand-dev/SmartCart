import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

// Une ligne d'article détectée sur un ticket de caisse : un nom de produit
// et son prix. `prix` en euros.
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
// Le format d'un ticket varie d'une enseigne à l'autre : on applique donc des
// heuristiques prudentes plutôt qu'un parsing rigide, et l'écran laisse
// toujours l'utilisateur vérifier/corriger chaque ligne avant d'enregistrer.
class TicketOcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  // Enseignes françaises courantes : on cherche l'une d'elles dans les
  // premières lignes (l'en-tête du ticket) pour pré-remplir le magasin.
  static const _enseignes = [
    'Carrefour', 'Leclerc', 'E.Leclerc', 'Lidl', 'Aldi', 'Auchan',
    'Intermarché', 'Intermarche', 'Super U', 'Hyper U', 'Système U',
    'Systeme U', 'Casino', 'Monoprix', 'Franprix', 'Netto', 'Cora',
    'Grand Frais', 'Biocoop', 'Lidl', 'Picard', 'Naturalia', 'Match',
  ];

  // Mots-clés qui identifient une ligne à IGNORER (totaux, paiement, TVA,
  // en-têtes) même si elle contient un montant.
  static final _reIgnorer = RegExp(
    r'\b(TOTAL|SOUS.?TOTAL|A PAYER|NET A PAYER|CB|CARTE|ESP[EÈ]CES?|'
    r'RENDU|MONNAIE|TVA|DONT TVA|H\.?T|TTC|REMISE|NB|NBRE|ARTICLES?|'
    r'CAISSE|TICKET|MERCI|SIRET|TEL|EUROS?|CHANGE|CHEQUE|CHÈQUE|'
    r'FIDELIT|CUMUL|SOLDE|POINTS?)\b',
    caseSensitive: false,
  );

  // Un prix en fin de ligne : "2,50", "12.99", éventuellement suivi d'un
  // symbole € et/ou d'une lettre de taux de TVA (A/B/C…) comme sur beaucoup
  // de tickets français.
  static final _rePrix =
      RegExp(r'(\d{1,3})[.,](\d{2})\s*€?\s*[A-Z]?\s*$');

  Future<ResultatTicket> analyser(String cheminImage) async {
    final input = InputImage.fromFilePath(cheminImage);
    final texte = await _recognizer.processImage(input);
    final lignesTexte = <String>[];
    for (final block in texte.blocks) {
      for (final line in block.lines) {
        lignesTexte.add(line.text);
      }
    }

    final enseigne = _detecterEnseigne(lignesTexte);
    final lignes = <LigneTicket>[];
    for (final brut in lignesTexte) {
      final ligne = _parserLigne(brut);
      if (ligne != null) lignes.add(ligne);
    }

    return ResultatTicket(
      enseigne: enseigne,
      lignes: lignes,
      texteBrut: texte.text,
    );
  }

  String? _detecterEnseigne(List<String> lignes) {
    final entete = lignes.take(12).join(' ').toLowerCase();
    for (final e in _enseignes) {
      if (entete.contains(e.toLowerCase())) return e;
    }
    return null;
  }

  LigneTicket? _parserLigne(String brut) {
    final ligne = brut.trim();
    if (ligne.isEmpty) return null;
    if (_reIgnorer.hasMatch(ligne)) return null;

    final m = _rePrix.firstMatch(ligne);
    if (m == null) return null;
    final prix = double.tryParse('${m.group(1)}.${m.group(2)}');
    if (prix == null || prix <= 0 || prix > 999) return null;

    // Le nom = ce qui précède le prix, débarrassé des marqueurs de quantité
    // ("2 x", "1,000 kg x"), des codes et des symboles résiduels.
    var nom = ligne.substring(0, m.start).trim();
    nom = nom.replaceAll(RegExp(r'\d+[.,]?\d*\s*(kg|g|l|cl|ml)?\s*[xX*]\s*'), '');
    nom = nom.replaceAll(RegExp(r'[€*]'), '');
    nom = nom.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Retirer un éventuel code article/EAN isolé en début de ligne.
    nom = nom.replaceFirst(RegExp(r'^\d{3,}\s+'), '').trim();

    // Trop court ou sans vraie lettre → probablement pas un produit.
    if (nom.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '').length < 2) return null;

    // Jolie casse : "PATES COMPLETES" → "Pates completes".
    final nomPropre = nom.length <= 1
        ? nom
        : nom[0].toUpperCase() + nom.substring(1).toLowerCase();

    return LigneTicket(nom: nomPropre, prix: prix);
  }

  Future<void> dispose() => _recognizer.close();
}
