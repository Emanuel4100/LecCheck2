#ifndef RUNNER_WINDOW_STATE_H_
#define RUNNER_WINDOW_STATE_H_

#include <windows.h>

// LecCheck's window size, position and maximized state between launches, kept
// in %LOCALAPPDATA%\com.leccheck\LecCheck\window.ini (the Linux runner keeps
// the same keys in $XDG_CONFIG_HOME/com.leccheck.app/window.ini).

// Puts |window|, created but not yet shown, where it was when LecCheck last
// closed. Without a saved place, or when it's on no monitor any more (a
// screen was unplugged), centres it on its monitor's work area, shrunk to fit.
// Returns true when the window should be shown maximized.
bool RestoreWindowPlacement(HWND window);

// Saves where |window| is now. Does nothing before the window was shown.
void SaveWindowPlacement(HWND window);

#endif  // RUNNER_WINDOW_STATE_H_
