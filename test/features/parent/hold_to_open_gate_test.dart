import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/features/parent/presentation/hold_to_open_gate.dart';

void main() {
  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HoldToOpenGate(child: Text('the grown-up things')),
        ),
      ),
    );
  }

  final ring = find.byKey(const Key('hold-gate-ring'));

  testWidgets('shows the gate, not the content, at rest', (tester) async {
    await pumpGate(tester);
    expect(find.text('For grown-ups'), findsOneWidget);
    expect(find.text('the grown-up things'), findsNothing);
  });

  // NOTE on pump pattern: in the test binding the hold's ticker measures
  // time from its FIRST frame, so every hold needs one priming pump before
  // the duration pump (real devices stream frames continuously — the ring
  // starts filling on the next frame after the press).

  testWidgets('releasing early cancels and rewinds', (tester) async {
    await pumpGate(tester);
    final gesture = await tester.startGesture(tester.getCenter(ring));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('the grown-up things'), findsNothing);
  });

  testWidgets('two half-holds do not add up to one open', (tester) async {
    await pumpGate(tester);
    final first = await tester.startGesture(tester.getCenter(ring));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await first.up();
    await tester.pumpAndSettle(); // rewind completes

    final second = await tester.startGesture(tester.getCenter(ring));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await second.up();
    await tester.pumpAndSettle();
    expect(
      find.text('the grown-up things'),
      findsNothing,
      reason: 'progress must rewind on release, not accumulate',
    );
  });

  testWidgets('a full two-second hold opens', (tester) async {
    await pumpGate(tester);
    final gesture = await tester.startGesture(tester.getCenter(ring));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    await tester.pump();
    expect(find.text('the grown-up things'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('the grown-up things'), findsOneWidget);
  });
}
