import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum VocalEtat { idle, demandePermission, ecoute, erreur }

class VocalResult {
  final String texteOriginal;
  final String nomArticle;
  final int quantite;
  final String? unite;

  VocalResult({
    required this.texteOriginal,
    required this.nomArticle,
    this.quantite = 1,
    this.unite,
  });

  @override
  String toString() =>
      quantite > 1 ? '$quantite x $nomArticle' : nomArticle;
}

class VocalService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _ready = false;

  // ── Initialisation + permission ───────────────────────────────
  Future<String?> preparer() async {
    // 1. Permission
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return 'Permission microphone refusée. Activez-la dans les paramètres.';
    }
    if (!status.isGranted) {
      return 'Permission microphone refusée.';
    }

    // 2. Init STT
    if (!_ready) {
      _ready = await _stt.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    }
    if (!_ready) return 'Microphone non disponible sur cet appareil.';
    return null; // null = succès
  }

  bool get isListening => _stt.isListening;

  Future<void> arreter() async {
    if (_stt.isListening) await _stt.stop();
  }

  Future<void> annuler() async {
    if (_stt.isListening) await _stt.cancel();
  }

  // ── Écoute principale ─────────────────────────────────────────
  // Retourne le texte brut reconnu (partiel ou final, le meilleur disponible)
  // via le stream. Le caller décide quoi faire.
  StreamController<String>? _streamCtrl;

  Stream<String> ecouter() {
    _streamCtrl?.close();
    _streamCtrl = StreamController<String>.broadcast();

    _stt.listen(
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: false,
        listenMode: stt.ListenMode.dictation,
        localeId: 'fr_FR',
        pauseFor: const Duration(seconds: 2),
        listenFor: const Duration(seconds: 30),
      ),
      onResult: (result) {
        final texte = result.recognizedWords.trim();
        if (texte.isEmpty) return;
        // Émettre chaque nouveau texte dans le stream
        if (!(_streamCtrl?.isClosed ?? true)) {
          _streamCtrl!.add(texte);
        }
        // Fermer le stream proprement sur résultat final
        if (result.finalResult) {
          _streamCtrl?.close();
          _streamCtrl = null;
        }
      },
    );

    // Fermer le stream quand le micro s'arrête (silence)
    _stt.statusListener = (status) {
      if ((status == 'notListening' || status == 'done') &&
          !(_streamCtrl?.isClosed ?? true)) {
        // Donner 200ms supplémentaires pour recevoir le dernier résultat
        Future.delayed(const Duration(milliseconds: 200), () {
          _streamCtrl?.close();
          _streamCtrl = null;
        });
      }
    };

    return _streamCtrl!.stream;
  }

  // ── Découpage multi-articles ("pommes, lait et pain") ─────────
  // Sépare sur les virgules et les "et"/"puis" isolés, puis nettoie
  // chaque segment indépendamment. Un seul article dicté renvoie une
  // liste à un seul élément.
  static List<VocalResult> nettoyerMultiple(String texte) {
    final segments = texte
        .split(RegExp(r',|\bet\b|\bpuis\b', caseSensitive: false))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.isEmpty) return [];
    return segments.map(nettoyer).toList();
  }

  // ── Nettoyage du texte avant insertion ────────────────────────
  static VocalResult nettoyer(String texte) {
    String t = texte.trim().toLowerCase();

    // Supprimer mots parasites courants
    final parasites = [
      'euh ', 'euh,', 'heu ', 'heu,', 'ben ', 'bah ',
      'alors ', 'donc ', 'voilà ', 'voila ',
    ];
    for (final p in parasites) {
      t = t.replaceAll(p, '');
    }

    // Extraire quantité
    int quantite = 1;
    String? unite;
    String reste = t.trim();

    // Chiffres en début : "3 yaourts", "12 oeufs"
    final reChiffre = RegExp(r'^(\d+)\s+(.+)$');
    final mChiffre = reChiffre.firstMatch(reste);
    if (mChiffre != null) {
      quantite = int.tryParse(mChiffre.group(1)!) ?? 1;
      reste = mChiffre.group(2)!.trim();
    } else {
      // Nombres en lettres
      const nombres = {
        'un ': 1, 'une ': 1, 'deux ': 2, 'trois ': 3,
        'quatre ': 4, 'cinq ': 5, 'six ': 6, 'sept ': 7,
        'huit ': 8, 'neuf ': 9, 'dix ': 10, 'douze ': 12,
      };
      for (final e in nombres.entries) {
        if (reste.startsWith(e.key)) {
          quantite = e.value;
          reste = reste.substring(e.key.length).trim();
          break;
        }
      }
    }

    // Extraire unité si présente
    const unites = {
      'kg': 'kg', 'kilo ': 'kg', 'kilos ': 'kg',
      'g ': 'g', 'gramme ': 'g', 'grammes ': 'g',
      'l ': 'L', 'litre ': 'L', 'litres ': 'L',
      'cl ': 'cl', 'ml ': 'ml',
      'paquet ': 'paquet', 'paquets ': 'paquet',
      'boite ': 'boîte', 'boîte ': 'boîte',
      'bouteille ': 'bouteille', 'bouteilles ': 'bouteille',
    };
    for (final e in unites.entries) {
      if (reste.startsWith(e.key)) {
        unite = e.value;
        reste = reste.substring(e.key.length).trim();
        // Supprimer "de" ou "d'" après l'unité
        if (reste.startsWith('de ')) reste = reste.substring(3);
        if (reste.startsWith("d'")) reste = reste.substring(2);
        break;
      }
    }

    // Supprimer articles en début
    const articles = [
      'du ', 'de la ', "de l'", 'des ', 'le ', 'la ',
      'les ', 'un ', 'une ', 'de ', "d'",
    ];
    for (final a in articles) {
      if (reste.startsWith(a)) {
        reste = reste.substring(a.length);
        break;
      }
    }

    reste = reste.trim();

    // Capitaliser
    final nom = reste.isEmpty
        ? texte.trim()
        : reste[0].toUpperCase() + reste.substring(1);

    return VocalResult(
      texteOriginal: texte,
      nomArticle: nom,
      quantite: quantite,
      unite: unite,
    );
  }
}
