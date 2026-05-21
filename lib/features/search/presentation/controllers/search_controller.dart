import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/data/models/note_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';

class SearchState {
  const SearchState({
    this.query = '',
    this.folderId,
    this.tagLabel,
    this.mode = SearchMode.all,
    this.sortOrder,
  });

  final String query;
  final String? folderId;
  final String? tagLabel;
  final SearchMode mode;
  final NoteSortOrder? sortOrder;

  SearchState copyWith({
    String? query,
    Object? folderId = _searchSentinel,
    Object? tagLabel = _searchSentinel,
    SearchMode? mode,
    Object? sortOrder = _searchSentinel,
  }) {
    return SearchState(
      query: query ?? this.query,
      folderId: identical(folderId, _searchSentinel)
          ? this.folderId
          : folderId as String?,
      tagLabel: identical(tagLabel, _searchSentinel)
          ? this.tagLabel
          : tagLabel as String?,
      mode: mode ?? this.mode,
      sortOrder: identical(sortOrder, _searchSentinel)
          ? this.sortOrder
          : sortOrder as NoteSortOrder?,
    );
  }
}

enum SearchMode {
  all,
  notes,
  pinned,
  favorites,
}

class SearchController extends StateNotifier<SearchState> {
  SearchController() : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setMode(SearchMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setFolder(String? folderId) {
    state = state.copyWith(folderId: folderId);
  }

  void setTag(String? tagLabel) {
    state = state.copyWith(tagLabel: tagLabel);
  }

  void setSortOrder(NoteSortOrder? sortOrder) {
    state = state.copyWith(sortOrder: sortOrder);
  }

  void clearFilters() {
    state = const SearchState();
  }
}

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>((ref) {
  return SearchController();
});

final searchResultsProvider = Provider<List<NoteModel>>((ref) {
  final notesState = ref.watch(notesControllerProvider).valueOrNull;
  if (notesState == null) {
    return const <NoteModel>[];
  }

  final searchState = ref.watch(searchControllerProvider);
  return notesState.filterNotes(
    query: searchState.query,
    folderId: searchState.folderId,
    tagLabel: searchState.tagLabel,
    favoritesOnly: searchState.mode == SearchMode.favorites,
    pinnedOnly: searchState.mode == SearchMode.pinned,
    sortOrder: searchState.sortOrder,
  );
});

final searchTopPicksProvider = Provider<List<NoteModel>>((ref) {
  final notesState = ref.watch(notesControllerProvider).valueOrNull;
  return notesState?.topPicks() ?? const <NoteModel>[];
});

final hasSearchFiltersProvider = Provider<bool>((ref) {
  final state = ref.watch(searchControllerProvider);
  return state.folderId != null ||
      state.tagLabel != null ||
      state.mode != SearchMode.all ||
      state.sortOrder != null;
});

const Object _searchSentinel = Object();
