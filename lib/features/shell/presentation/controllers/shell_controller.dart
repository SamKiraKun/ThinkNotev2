import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ShellTab {
  home,
  search,
  folders,
  profile,
}

final shellTabProvider = StateProvider<ShellTab>((ref) {
  return ShellTab.home;
});

final homeSelectedFolderProvider = StateProvider<String?>((ref) {
  return null;
});
