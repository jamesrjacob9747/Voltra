import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltra_app/theme.dart';
import 'package:voltra_app/widgets/booking_status.dart';
import 'package:voltra_app/widgets/empty_state.dart';
import 'package:voltra_app/widgets/primary_bar.dart';
import 'package:voltra_app/widgets/stat_tile.dart';

/// Shared pieces must stay readable, without overflowing, on a small phone with the system
/// font size turned up (1.3x) in both themes.
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shared components fit a 360 px phone at 1.3x text, ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(brightness),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 780), textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SectionHeader('Requests', count: 3),
                  const Row(
                    children: [
                      Expanded(
                        child: StatTile(label: 'Energy sold today', value: Text('12.4 kWh'), icon: Icons.bolt),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: StatTile(label: 'Bookings today', value: Text('7'), icon: Icons.event),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BookingStatusPill(status: 'PENDING'),
                      BookingStatusPill(status: 'CONFIRMED'),
                      BookingStatusPill(status: 'COMPLETED'),
                    ],
                  ),
                  const SizedBox(
                    height: 380,
                    child: EmptyState(
                      icon: Icons.receipt_long,
                      title: 'No bookings yet',
                      hint: 'Tell us how much charge you need and we’ll match you with a charger nearby.',
                      actionLabel: 'Find me a charge',
                      onAction: _noop,
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: PrimaryBar(
                label: 'Book this charger',
                icon: Icons.event_available,
                amount: '₹12/kWh',
                amountCaption: 'evening peak',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // An overflow is reported as an exception during layout.
      expect(tester.takeException(), isNull);
      expect(find.text('Book this charger'), findsOneWidget);
    });
  }
}

void _noop() {}
