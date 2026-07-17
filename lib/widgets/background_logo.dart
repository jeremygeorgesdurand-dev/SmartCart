import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers pour le fond logo
final fondActiveProvider = StateProvider<bool>((ref) => true);
// Opacité par défaut à 10% — visible mais discret
final fondOpaciteProvider = StateProvider<double>((ref) => 0.10);
