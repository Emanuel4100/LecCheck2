#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Held while LecCheck runs. LecCheck's setup waits for it to go before it
// replaces the files (windows/installer/leccheck.iss uses the same name).
constexpr const wchar_t kInstanceMutex[] = L"LecCheck.com.leccheck.app";

// The same id as the setup's Start menu shortcut, so a pinned LecCheck and
// the running one are one taskbar button (and later, notifications).
constexpr const wchar_t kAppUserModelId[] = L"com.leccheck.app";

// Brings the LecCheck that is already running to the front.
void ShowRunningInstance() {
  HWND running = ::FindWindowW(Win32Window::kClassName, nullptr);
  if (running == nullptr) return;
  if (::IsIconic(running)) {
    ::ShowWindow(running, SW_RESTORE);
  }
  ::SetForegroundWindow(running);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // One LecCheck at a time, as on Linux: a second start shows the first. Two
  // would share one database. The handle stays open until the process ends.
  HANDLE instance_mutex = ::CreateMutexW(nullptr, FALSE, kInstanceMutex);
  if (instance_mutex != nullptr && ::GetLastError() == ERROR_ALREADY_EXISTS) {
    ShowRunningInstance();
    return EXIT_SUCCESS;
  }
  ::SetCurrentProcessExplicitAppUserModelID(kAppUserModelId);

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // Centred, or where it was last time (window_state.cpp).
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 820);
  if (!window.Create(L"LecCheck", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
