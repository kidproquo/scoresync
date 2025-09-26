// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:scoresync/main.dart';

void main() {
  testWidgets('Symph app shows split screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ScoreSyncApp());

    // Verify that the app title is shown
    expect(find.text('Symph'), findsOneWidget);

    // Verify that both placeholders are shown
    expect(find.text('Score Viewer'), findsOneWidget);
    expect(find.text('YouTube Player'), findsOneWidget);

    // Verify that mode toggle is present
    expect(find.text('Design Mode'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });
}
