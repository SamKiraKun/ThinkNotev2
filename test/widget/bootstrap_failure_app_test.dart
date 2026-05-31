import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinknote/bootstrap/app_bootstrap.dart';

void main() {
  testWidgets('bootstrap failure screen shows a retry action', (
    tester,
  ) async {
    var retryCalls = 0;

    await tester.pumpWidget(
      buildBootstrapFailureApp(
        message: 'Startup failed',
        onRetry: () async {
          retryCalls += 1;
        },
      ),
    );

    expect(
      find.text('Something went wrong while starting ThinkNote.'),
      findsOneWidget,
    );
    expect(find.text('Startup failed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry launch'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry launch'));
    await tester.pump();

    expect(retryCalls, 1);
  });
}