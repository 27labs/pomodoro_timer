import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

const workDuration = Duration(minutes: 25);
const shortBreakDuration = Duration(minutes: 5);
const longBreakDuration = Duration(minutes: 15);
const sessionsBeforeLongBreak = 4;

const destijlRed = Color(0xFFFF0000);
const destijlBlue = Color(0xFF0000FF);
const destijlYellow = Color(0xFFFFFF00);
const destijlWhite = Color(0xFFFFFFFF);
const destijlBlack = Color(0xFF000000);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(520, 680),
      minimumSize: Size(340, 460),
      center: true,
      title: 'Pomodoro Timer',
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: destijlWhite,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    await localNotifier.setup(
      appName: 'Pomodoro Timer',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  runApp(const ProviderScope(child: PomodoroApp()));
}

enum PomodoroPhase {
  work('Work', workDuration),
  shortBreak('Short Break', shortBreakDuration),
  longBreak('Long Break', longBreakDuration);

  const PomodoroPhase(this.label, this.duration);

  final String label;
  final Duration duration;
}

@immutable
class PomodoroState {
  const PomodoroState({
    required this.phase,
    required this.remaining,
    required this.completedPomodoros,
    required this.isRunning,
  });

  factory PomodoroState.initial() => const PomodoroState(
    phase: PomodoroPhase.work,
    remaining: workDuration,
    completedPomodoros: 0,
    isRunning: false,
  );

  final PomodoroPhase phase;
  final Duration remaining;
  final int completedPomodoros;
  final bool isRunning;

  double get progress {
    final total = phase.duration.inSeconds;
    if (total == 0) {
      return 1;
    }
    return 1 - (remaining.inSeconds / total).clamp(0, 1);
  }

  PomodoroState copyWith({
    PomodoroPhase? phase,
    Duration? remaining,
    int? completedPomodoros,
    bool? isRunning,
  }) {
    return PomodoroState(
      phase: phase ?? this.phase,
      remaining: remaining ?? this.remaining,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

final pomodoroControllerProvider =
    NotifierProvider<PomodoroController, PomodoroState>(PomodoroController.new);

class PomodoroController extends Notifier<PomodoroState> {
  Timer? _timer;

  @override
  PomodoroState build() {
    ref.onDispose(() => _timer?.cancel());
    return PomodoroState.initial();
  }

  void start() {
    if (state.isRunning) {
      return;
    }

    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void reset() {
    _timer?.cancel();
    state = PomodoroState.initial();
  }

  void _tick() {
    if (state.remaining.inSeconds > 1) {
      state = state.copyWith(
        remaining: state.remaining - const Duration(seconds: 1),
      );
      return;
    }

    _completeCurrentPhase();
  }

  void _completeCurrentPhase() {
    final finishedPhase = state.phase;
    final completedPomodoros = finishedPhase == PomodoroPhase.work
        ? state.completedPomodoros + 1
        : state.completedPomodoros;
    final nextPhase = _nextPhase(finishedPhase, completedPomodoros);

    state = PomodoroState(
      phase: nextPhase,
      remaining: nextPhase.duration,
      completedPomodoros: completedPomodoros,
      isRunning: true,
    );

    _showNotification(finishedPhase, nextPhase);
  }

  PomodoroPhase _nextPhase(PomodoroPhase current, int completedPomodoros) {
    if (current != PomodoroPhase.work) {
      return PomodoroPhase.work;
    }

    return completedPomodoros % sessionsBeforeLongBreak == 0
        ? PomodoroPhase.longBreak
        : PomodoroPhase.shortBreak;
  }

  void _showNotification(PomodoroPhase finished, PomodoroPhase next) {
    if (kIsWeb || !Platform.isWindows) {
      return;
    }

    LocalNotification(
      title: '${finished.label} complete',
      body: 'Time for ${next.label.toLowerCase()}.',
    ).show();
  }
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pomodoro Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: destijlRed,
          secondary: destijlBlue,
          surface: destijlWhite,
          onSurface: destijlBlack,
        ),
        fontFamily: 'Segoe UI',
        textTheme: Typography.blackMountainView.apply(
          fontFamily: 'Segoe UI',
          bodyColor: destijlBlack,
          displayColor: destijlBlack,
        ),
      ),
      home: const PomodoroHome(),
    );
  }
}

class PomodoroHome extends ConsumerWidget {
  const PomodoroHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pomodoroControllerProvider);
    final controller = ref.read(pomodoroControllerProvider.notifier);

    return Scaffold(
      backgroundColor: destijlWhite,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                return Padding(
                  padding: const EdgeInsets.all(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: destijlBlack,
                      border: Border.all(color: destijlBlack, width: 8),
                    ),
                    child: GridBlock(
                      child: compact
                          ? _CompactComposition(
                              state: state,
                              onStartPause: state.isRunning
                                  ? controller.pause
                                  : controller.start,
                              onReset: controller.reset,
                            )
                          : _WideComposition(
                              state: state,
                              onStartPause: state.isRunning
                                  ? controller.pause
                                  : controller.start,
                              onReset: controller.reset,
                            ),
                    ),
                  ),
                );
              },
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 18,
              child: DragToMoveArea(child: SizedBox.expand()),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideComposition extends StatelessWidget {
  const _WideComposition({
    required this.state,
    required this.onStartPause,
    required this.onReset,
  });

  final PomodoroState state;
  final VoidCallback onStartPause;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 7,
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    Expanded(flex: 5, child: TimerPanel(state: state)),
                    const GridGap(),
                    Expanded(
                      flex: 2,
                      child: SessionPanel(completed: state.completedPomodoros),
                    ),
                  ],
                ),
              ),
              const GridGap(),
              Expanded(flex: 3, child: PhasePanel(state: state)),
            ],
          ),
        ),
        const GridGap(),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: ActionTile(
                  label: state.isRunning ? 'PAUSE' : 'START',
                  color: state.isRunning ? destijlYellow : destijlBlue,
                  onPressed: onStartPause,
                ),
              ),
              const GridGap(),
              Expanded(
                flex: 3,
                child: ActionTile(
                  label: 'RESET',
                  color: destijlRed,
                  onPressed: onReset,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactComposition extends StatelessWidget {
  const _CompactComposition({
    required this.state,
    required this.onStartPause,
    required this.onReset,
  });

  final PomodoroState state;
  final VoidCallback onStartPause;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 5, child: TimerPanel(state: state)),
        const GridGap(),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(child: PhasePanel(state: state)),
              const GridGap(),
              Expanded(
                child: SessionPanel(completed: state.completedPomodoros),
              ),
            ],
          ),
        ),
        const GridGap(),
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                child: ActionTile(
                  label: state.isRunning ? 'PAUSE' : 'START',
                  color: state.isRunning ? destijlYellow : destijlBlue,
                  onPressed: onStartPause,
                ),
              ),
              const GridGap(),
              Expanded(
                child: ActionTile(
                  label: 'RESET',
                  color: destijlRed,
                  onPressed: onReset,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TimerPanel extends StatelessWidget {
  const TimerPanel({required this.state, super.key});

  final PomodoroState state;

  @override
  Widget build(BuildContext context) {
    return MondrianTile(
      color: destijlWhite,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FractionallySizedBox(
            alignment: Alignment.bottomCenter,
            heightFactor: state.progress,
            child: Container(color: destijlYellow),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: FittedBox(
              fit: BoxFit.contain,
              child: Text(
                _formatDuration(state.remaining),
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PhasePanel extends StatelessWidget {
  const PhasePanel({required this.state, super.key});

  final PomodoroState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state.phase) {
      PomodoroPhase.work => destijlRed,
      PomodoroPhase.shortBreak => destijlBlue,
      PomodoroPhase.longBreak => destijlYellow,
    };

    return MondrianTile(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              state.phase.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SessionPanel extends StatelessWidget {
  const SessionPanel({required this.completed, super.key});

  final int completed;

  @override
  Widget build(BuildContext context) {
    return MondrianTile(
      color: destijlWhite,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'POMODOROS',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 26),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(sessionsBeforeLongBreak, (index) {
                    final filled = index < completed % sessionsBeforeLongBreak;
                    return Expanded(
                      child: Container(
                        height: 26,
                        margin: EdgeInsets.only(
                          right: index == sessionsBeforeLongBreak - 1 ? 0 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: filled ? destijlRed : destijlWhite,
                          border: Border.all(color: destijlBlack, width: 4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completed complete',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    required this.label,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MondrianTile(
      color: color,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GridBlock extends StatelessWidget {
  const GridBlock({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: destijlBlack, child: child);
  }
}

class GridGap extends StatelessWidget {
  const GridGap({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 8, height: 8);
  }
}

class MondrianTile extends StatelessWidget {
  const MondrianTile({required this.color, required this.child, super.key});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color, child: child);
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
