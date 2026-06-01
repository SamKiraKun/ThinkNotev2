import 'package:flutter_test/flutter_test.dart';
import 'package:thinknote/features/notes/data/models/note_model.dart';

void main() {
  group('NoteModel Tests', () {
    test('fromJson creates a valid NoteModel', () {
      final json = {
        'id': 'test-123',
        'title': 'Test Note',
        'content': 'This is a test note content',
        'excerpt': 'This is a test',
        'category': 'Study',
        'created_at': '2023-01-01T12:00:00.000Z',
        'updated_at': '2023-01-01T12:00:00.000Z',
      };

      final model = NoteModel.fromJson(json);

      expect(model.id, 'test-123');
      expect(model.title, 'Test Note');
      expect(model.content, 'This is a test note content');
      expect(model.folderId, 'study');
      expect(model.tags, isEmpty);
      expect(model.isPinned, false);
    });
  });
}
