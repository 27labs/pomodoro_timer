# Pomodoro Timer Implementation Plan

## Overview
A Windows 11 desktop application built with Flutter, functioning as a pure standalone Pomodoro timer. The visual design rigidly enforces the **De Stijl** art movement aesthetic, featuring stark geometric shapes, thick black dividing lines, and a strictly enforced palette restricted to primary colors (red, blue, yellow) alongside white and black. The application will be a standard, frameless, resizable window that seamlessly adapts its layout to look great at any size.

## Core Features
1.  **Timer Functionality**:
    *   Work interval (default 25 minutes).
    *   Short Break interval (default 5 minutes).
    *   Long Break interval (default 15 minutes).
    *   Start, Pause, and Reset controls.
2.  **Session Tracking**:
    *   Track the number of completed Pomodoros for the current session.
    *   Automatically trigger a Long Break after a set number of work sessions (e.g., 4).
    *   No long-term statistics or historical tracking.
3.  **Notifications**:
    *   Standard native Windows toast notifications when a session or break ends.
    *   No custom audio (relies on the OS default notification behavior).

## Desktop Integration (Windows 11)
*   **Window Management**: 
    *   Frameless window (removing the default Windows title bar).
    *   Fully resizable, with a responsive layout that maintains the De Stijl composition whether small or large.
    *   Standard desktop behavior (no always-on-top management, no system tray).

## De Stijl Design Language
*   **Layout**: Grid-based, asymmetric composition that scales responsively. The UI will emulate a Piet Mondrian painting, dynamically adjusting its rectangular blocks based on window size.
*   **Colors**: Strictly enforced palette: Pure Red (`#FF0000`), Pure Blue (`#0000FF`), Pure Yellow (`#FFFF00`), stark White (`#FFFFFF`), and solid Black (`#000000`). No custom color themes.
*   **Borders**: Thick, solid black borders separating all UI elements.
*   **Typography**: Clean, geometric sans-serif fonts with high contrast.
*   **Controls**: Buttons and interactive elements will be solid color blocks. State changes (like playing vs. paused) can be represented by color shifts among the primary palette.

## Technical Stack
*   **Framework**: Flutter (Desktop target: Windows).
*   **State Management**: `flutter_riverpod` to cleanly manage the timer ticks and current session state.
*   **Packages**:
    *   `window_manager`: For creating the frameless window and handling custom drag/resize areas.
    *   `local_notifier`: For triggering native Windows toast notifications.
