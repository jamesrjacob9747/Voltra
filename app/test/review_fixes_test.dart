import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltra_app/models.dart';
import 'package:voltra_app/theme.dart';
import 'package:voltra_app/widgets/confidence_badge.dart';
import 'package:voltra_app/widgets/pressable.dart';
import 'package:voltra_app/widgets/stat_tile.dart';

Widget _app(Widget child, {double width = 400, double textScale = 1}) => MaterialApp(
  theme: buildTheme(),
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(textScale)),
    child: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('Pressable can be focused and activated with Enter and Space', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            Focus(focusNode: focus, child: const SizedBox(height: 10)),
            Pressable(onTap: () => taps++, child: const Text('card')),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('a disabled Pressable is skipped by the keyboard', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            Focus(focusNode: focus, child: const SizedBox(height: 10)),
            const Pressable(onTap: null, child: Text('off')),
            Pressable(onTap: () => taps++, child: const Text('on')),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // lands on "on", not "off"
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });

  for (final (width, scale) in [(320.0, 1.0), (320.0, 1.3), (412.0, 1.3)]) {
    testWidgets('stat tile grid fits at $width px with ${scale}x text', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          width: width,
          textScale: scale,
          Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                GridView(
                  gridDelegate: statGridDelegate(context, icon: true),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    StatTile(
                      tone: StatTone.onNavy,
                      icon: Icons.eco_outlined,
                      label: 'drivers rescued by ChargeSure',
                      value: Text('12'),
                    ),
                    StatTile(
                      tone: StatTone.onNavy,
                      icon: Icons.ev_station_outlined,
                      label: 'chargers unlocked, zero built',
                      value: Text('8'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView(
                  gridDelegate: statGridDelegate(context, compact: true),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    StatTile(tone: StatTone.onNavy, compact: true, label: 'Duration', value: Text('00:42:18')),
                    StatTile(tone: StatTone.onNavy, compact: true, label: 'Voltage', value: Text('230 V')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // an overflow is reported as an exception
    });
  }

  testWidgets('a long reliability label is cut short instead of overflowing', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 120,
          child: Row(
            children: [
              Flexible(
                child: ConfidenceBadge(
                  confidence: Confidence.fromJson({
                    'score': 92,
                    'band': 'Highly reliable',
                    'breakdown': <String, dynamic>{},
                  }),
                  online: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
