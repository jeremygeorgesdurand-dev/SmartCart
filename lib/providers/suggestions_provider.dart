import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import '../services/suggestions_service.dart';

final suggestionsServiceProvider = Provider<SuggestionsService>(
    (ref) => SuggestionsService(ref.read(dbServiceProvider)));

final suggestionsProvider = FutureProvider<List<SuggestionReassort>>((ref) {
  ref.watch(listesNotifierProvider);
  ref.watch(articlesNotifierProvider);
  return ref.read(suggestionsServiceProvider).calculer();
});
