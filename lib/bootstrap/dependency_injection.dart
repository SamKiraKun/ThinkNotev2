import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notes/data/datasources/notes_local_datasource.dart';
import '../features/notes/data/repositories/notes_repository_impl.dart';
import '../features/notes/domain/repositories/notes_repository.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final localDataSource = ref.watch(notesLocalDataSourceProvider);
  return NotesRepositoryImpl(localDataSource);
});
