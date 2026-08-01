import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatch/shared/answer/answer_input.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AnswerStopwatch', () {
    test('captures latency at the FIRST key only (engine law 3)', () {
      var t = DateTime(2026, 8, 7, 9, 0, 0);
      final fixed = Clock(() => t);
      withClock(fixed, () {
        final watch = AnswerStopwatch()..promptShown();
        t = t.add(const Duration(milliseconds: 1200));
        watch.keyPressed();
        t = t.add(const Duration(milliseconds: 5000));
        watch.keyPressed();
        expect(watch.firstKeyLatencyMs, 1200);
      });
    });

    test('latency is null before any key', () {
      final watch = AnswerStopwatch()..promptShown();
      expect(watch.firstKeyLatencyMs, isNull);
    });
  });

  group('HatchNumPad', () {
    testWidgets('types digits, backspaces, submits the entry', (tester) async {
      int? submitted;
      var firstKeys = 0;
      await tester.pumpWidget(
        host(
          HatchNumPad(
            onFirstKey: () => firstKeys++,
            onSubmit: (v) => submitted = v,
          ),
        ),
      );
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      await tester.tap(find.text('6'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.check_rounded));
      expect(submitted, 56);
      expect(firstKeys, 1, reason: 'only the first key marks latency');
    });

    testWidgets('submit is inert while the entry is empty', (tester) async {
      int? submitted;
      await tester.pumpWidget(
        host(HatchNumPad(onFirstKey: () {}, onSubmit: (v) => submitted = v)),
      );
      await tester.tap(find.byIcon(Icons.check_rounded));
      expect(submitted, isNull);
    });

    testWidgets('key targets meet the 64dp floor', (tester) async {
      await tester.pumpWidget(
        host(HatchNumPad(onFirstKey: () {}, onSubmit: (_) {})),
      );
      final size = tester.getSize(
        find.ancestor(of: find.text('5'), matching: find.byType(InkWell)).first,
      );
      expect(size.width, greaterThanOrEqualTo(64));
      expect(size.height, greaterThanOrEqualTo(64));
    });
  });

  group('ChoiceButtons', () {
    testWidgets('shows three options and reports the chosen one', (
      tester,
    ) async {
      int? chosen;
      var firstKeys = 0;
      await tester.pumpWidget(
        host(
          ChoiceButtons(
            options: const [12, 14, 16],
            onFirstKey: () => firstKeys++,
            onChoose: (v) => chosen = v,
          ),
        ),
      );
      expect(find.text('12'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('16'), findsOneWidget);
      await tester.tap(find.text('14'));
      expect(chosen, 14);
      expect(firstKeys, 1);
    });
  });
}
