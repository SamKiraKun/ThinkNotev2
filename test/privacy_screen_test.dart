import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thinknote/core/theme/app_theme.dart';
import 'package:thinknote/features/profile/presentation/screens/privacy_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('privacy screen documents local-only production behavior',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PrivacyScreen(),
        ),
      ),
    );

    expect(find.text('Privacy and storage'), findsOneWidget);
    expect(find.text('Local-only workspace'), findsOneWidget);
    expect(find.textContaining('does not create accounts'), findsOneWidget);
    expect(find.text('Device storage'), findsOneWidget);
    expect(find.textContaining('encrypted before they are stored'), findsOneWidget);
    expect(find.text('Backup behavior'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Diagnostics and analytics'), findsOneWidget);
    expect(find.textContaining('client Firebase SDK'), findsOneWidget);
    expect(find.text('Deleting local data'), findsOneWidget);
    expect(find.textContaining('Uninstalling the app'), findsOneWidget);
  });
}
