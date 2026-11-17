import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltra_app/theme.dart';
import 'package:voltra_app/widgets/tab_shell.dart';

void main() {
  final built = <String>[];

  ShellTab tab(String name, IconData icon) => ShellTab(
    label: name,
    icon: icon,
    selectedIcon: icon,
    builder: (_, visit) {
      built.add('$name#$visit');
      return Center(child: Text('$name page, visit $visit'));
    },
  );

  Widget shell() => MaterialApp(
    theme: buildTheme(),
    home: TabShell(tabs: [tab('Home', Icons.map), tab('Bookings', Icons.receipt_long), tab('Profile', Icons.person)]),
  );

  setUp(built.clear);

  testWidgets('opens on the first tab and builds the others only when opened', (tester) async {
    await tester.pumpWidget(shell());
    expect(find.text('Home page, visit 0'), findsOneWidget);
    expect(built, ['Home#0']);

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Bookings page, visit 1'), findsOneWidget);
    expect(built.any((b) => b.startsWith('Profile')), isFalse);
  });

  testWidgets('reopening a tab bumps its visit count so the screen can reload', (tester) async {
    await tester.pumpWidget(shell());
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Home page, visit 1'), findsOneWidget);
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Bookings page, visit 2'), findsOneWidget);

    // Tapping the tab you are already on changes nothing.
    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Bookings page, visit 2'), findsOneWidget);
  });

  testWidgets('system back returns to the first tab before leaving the app', (tester) async {
    await tester.pumpWidget(shell());
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile page, visit 1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(TabShell.of(tester.element(find.text('Home page, visit 1')))!.index, 0);
  });
}
