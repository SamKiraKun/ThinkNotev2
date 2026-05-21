import 'package:flutter_test/flutter_test.dart';
import 'package:thinknote/features/folders/data/models/folder_model.dart';
import 'package:thinknote/features/folders/data/models/tag_model.dart';
import 'package:thinknote/features/notes/data/models/app_preferences_model.dart';
import 'package:thinknote/features/notes/data/models/note_model.dart';
import 'package:thinknote/features/notes/presentation/controllers/notes_state.dart';

void main() {
  group('NotesState filtering', () {
    final folders = FolderModel.defaults();
    final now = DateTime(2026, 5, 21, 10);

    final state = NotesState(
      notes: <NoteModel>[
        NoteModel(
          id: '1',
          title: 'Dream Life Plan',
          content: 'Travel the world and build meaningful work.',
          folderId: 'personal',
          tags: const <String>['Goals', 'Travel'],
          isPinned: true,
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now.subtract(const Duration(hours: 2)),
        ),
        NoteModel(
          id: '2',
          title: 'Formula Sheet',
          content: 'Algebra shortcuts and geometry proofs.',
          folderId: 'study',
          tags: const <String>['Math'],
          createdAt: now.subtract(const Duration(days: 2)),
          updatedAt: now.subtract(const Duration(hours: 5)),
        ),
        NoteModel(
          id: '3',
          title: 'Launch Tasks',
          content: 'Finalize assets and ship the release.',
          folderId: 'work',
          isFavorite: true,
          createdAt: now.subtract(const Duration(days: 1)),
          updatedAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
      folders: folders,
      tags: TagModel.defaults(),
      recentSearches: const <String>[],
      preferences: const AppPreferencesModel(),
    );

    test('keeps pinned notes first when sorting', () {
      final notes = state.filterNotes();

      expect(notes.first.id, '1');
      expect(
          notes.map((note) => note.id), containsAllInOrder(<String>['1', '3']));
    });

    test('matches search text against title, content, and tags', () {
      expect(state.filterNotes(query: 'formula').single.id, '2');
      expect(state.filterNotes(query: 'travel').single.id, '1');
      expect(state.filterNotes(query: 'Goals').single.id, '1');
    });

    test('supports favorites-only and title sorting', () {
      final favorites = state.filterNotes(favoritesOnly: true);
      final alphabetical = state.filterNotes(sortOrder: NoteSortOrder.titleAsc);

      expect(favorites.single.id, '3');
      expect(alphabetical.first.id, '1');
      expect(alphabetical.last.id, '3');
    });
  });
}
