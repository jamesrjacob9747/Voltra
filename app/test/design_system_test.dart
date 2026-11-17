import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltra_app/format.dart';
import 'package:voltra_app/models.dart';
import 'package:voltra_app/theme.dart';
import 'package:voltra_app/widgets/booking_status.dart';
import 'package:voltra_app/widgets/confidence_badge.dart';
import 'package:voltra_app/widgets/empty_state.dart';
import 'package:voltra_app/widgets/error_view.dart';
import 'package:voltra_app/widgets/motion.dart';
import 'package:voltra_app/widgets/pressable.dart';
import 'package:voltra_app/widgets/primary_bar.dart';
import 'package:voltra_app/widgets/skeleton.dart';
import 'package:voltra_app/widgets/stat_tile.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light, bool noMotion = false}) => MaterialApp(
  theme: buildTheme(brightness),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: noMotion),
    child: Scaffold(body: child),
  ),
);

Confidence _confidence(int score) =>
    Confidence.fromJson({'score': score, 'band': 'Highly reliable', 'breakdown': <String, dynamic>{}});

void main() {
  test('both themes carry the Voltra palette, and it differs between them', () {
    final light = buildTheme(Brightness.light).extension<VoltraPalette>()!;
    final dark = buildTheme(Brightness.dark).extension<VoltraPalette>()!;
    expect(light.card, isNot(dark.card));
    expect(buildTheme(Brightness.dark).colorScheme.brightness, Brightness.dark);
    expect(VoltraPalette.light.lerp(VoltraPalette.dark, 1).ink, VoltraPalette.dark.ink);
  });

  test('confidence colour: green from 85, amber from 60, grey below or offline', () {
    const p = VoltraPalette.dark;
    expect(confidenceColor(85, palette: p), p.success);
    expect(confidenceColor(60, palette: p), p.warning);
    expect(confidenceColor(59, palette: p), p.faint);
    expect(confidenceColor(99, online: false, palette: p), p.faint);
  });

  for (final brightness in Brightness.values) {
    testWidgets('shared components render in the ${brightness.name} theme', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _app(
          brightness: brightness,
          ListView(
            children: [
              const SectionHeader('Requests', count: 2),
              const StatTile(label: 'Earned', value: Text('₹120'), tone: StatTone.navy, icon: Icons.payments),
              const BookingStatusPill(status: 'PENDING'),
              ConfidenceBadge(confidence: _confidence(92), online: true),
              ConfidenceBadge(confidence: _confidence(92), online: false),
              SizedBox(
                height: 320,
                child: ErrorView(message: 'No connection', onRetry: () => retried = true),
              ),
              const SizedBox(
                height: 320,
                child: EmptyState(icon: Icons.receipt_long, title: 'No bookings yet', hint: 'Find a charger to start.'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('Waiting for host'), findsOneWidget);
      expect(find.text('92% · Highly reliable'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('No bookings yet'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retried, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('PrimaryBar shows the price, runs its action, and blocks taps while busy', (tester) async {
    var taps = 0;
    Widget bar({required bool busy}) => _app(
      Align(
        alignment: Alignment.bottomCenter,
        child: PrimaryBar(
          label: 'Book this charger',
          amount: pricePerKwh(1200),
          amountCaption: 'right now',
          busy: busy,
          onPressed: () => taps++,
        ),
      ),
    );
    await tester.pumpWidget(bar(busy: false));
    expect(find.text('₹12/kWh'), findsOneWidget);
    await tester.tap(find.text('Book this charger'));
    expect(taps, 1);

    await tester.pumpWidget(bar(busy: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Book this charger'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('Pressable taps through; a null onTap does nothing', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            Pressable(onTap: () => taps++, child: const Text('on')),
            const Pressable(onTap: null, child: Text('off')),
          ],
        ),
      ),
    );
    await tester.tap(find.text('on'));
    await tester.tap(find.text('off'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('CountUp rolls to the value, and lands on exactly the formatted figure', (tester) async {
    String money(double v) => rupees(v.round(), exact: true);
    await tester.pumpWidget(_app(CountUp(value: 2220, format: money)));
    expect(find.text('₹22.20'), findsNothing); // starts from zero
    await tester.pumpAndSettle();
    expect(find.text('₹22.20'), findsOneWidget);
  });

  testWidgets('with animations off: numbers and entrances appear at once, skeletons sit still', (tester) async {
    await tester.pumpWidget(
      _app(
        noMotion: true,
        Column(
          children: [
            CountUp(value: 2220, format: (v) => rupees(v.round(), exact: true)),
            const Entrance(index: 3, child: Text('row')),
            const Shimmer(child: ChargerCardSkeleton()),
            const AnimatedCheck(),
          ],
        ),
      ),
    );
    expect(find.text('₹22.20'), findsOneWidget);
    expect(find.text('row'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('skeleton list swaps to content without errors', (tester) async {
    Widget page({required bool loading}) => _app(
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: loading
            ? const SkeletonList(key: ValueKey('loading'), item: BookingRowSkeleton(), count: 3)
            : const Text('Loaded', key: ValueKey('loaded')),
      ),
    );
    await tester.pumpWidget(page(loading: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BookingRowSkeleton), findsNWidgets(3));
    await tester.pumpWidget(page(loading: false));
    await tester.pumpAndSettle();
    expect(find.text('Loaded'), findsOneWidget);
    expect(find.byType(BookingRowSkeleton), findsNothing);
  });
}
