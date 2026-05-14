import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pomodoro_timer/main.dart';

void main() {
  test('controller starts, pauses, and resets the timer', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(pomodoroControllerProvider.notifier);

    expect(container.read(pomodoroControllerProvider).remaining, workDuration);
    expect(container.read(pomodoroControllerProvider).isRunning, isFalse);

    controller.start();
    expect(container.read(pomodoroControllerProvider).isRunning, isTrue);

    controller.pause();
    expect(container.read(pomodoroControllerProvider).isRunning, isFalse);

    controller.reset();
    final state = container.read(pomodoroControllerProvider);
    expect(state.phase, PomodoroPhase.work);
    expect(state.remaining, workDuration);
    expect(state.completedPomodoros, 0);
  });

  testWidgets('renders the Pomodoro controls and status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PomodoroApp()));

    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);
    expect(find.text('RESET'), findsOneWidget);
    expect(find.text('POMODOROS'), findsOneWidget);
    expect(find.text('0 complete'), findsOneWidget);

    await tester.tap(find.text('START'));
    await tester.pump();

    expect(find.text('PAUSE'), findsOneWidget);
  });

  testWidgets('keeps the layout usable at a compact size', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const ProviderScope(child: PomodoroApp()));

    expect(find.byType(TimerPanel), findsOneWidget);
    expect(find.byType(PhasePanel), findsOneWidget);
    expect(find.byType(SessionPanel), findsOneWidget);
  });
}
