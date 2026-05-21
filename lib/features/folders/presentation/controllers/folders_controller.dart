import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FolderViewSegment {
  folders,
  tags,
  collections,
}

final foldersSegmentProvider =
    StateProvider.autoDispose<FolderViewSegment>((ref) {
  return FolderViewSegment.folders;
});
