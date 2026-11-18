#include "window_state.h"

#include <shlobj.h>

#include <algorithm>
#include <cwchar>
#include <string>

namespace {

constexpr const wchar_t kSection[] = L"window";

// Smaller saved sizes are ignored (a damaged file, say): the window opens at
// its default size instead.
constexpr LONG kMinSaved = 200;

// %APPDATA%\LecCheck\window.ini, with the data: path_provider's folder
// (Runner.rc's ProductName). Empty when Windows doesn't say where the folder
// is. With |create|, the folder is made.
std::wstring StateFile(bool create) {
  PWSTR roaming = nullptr;
  const HRESULT found = SHGetKnownFolderPath(FOLDERID_RoamingAppData,
                                             KF_FLAG_DEFAULT, nullptr, &roaming);
  std::wstring folder = SUCCEEDED(found)
                            ? std::wstring(roaming) + L"\\LecCheck"
                            : std::wstring();
  // Freed whether it succeeded or not.
  CoTaskMemFree(roaming);
  if (folder.empty()) return folder;
  if (create) {
    // ERROR_ALREADY_EXISTS is fine; any other failure shows when writing.
    SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr);
  }
  return folder + L"\\window.ini";
}

// GetPrivateProfileInt can't read negative numbers, and a window on a screen
// left of or above the main one has negative coordinates.
bool ReadInt(const std::wstring& file, const wchar_t* key, LONG* value) {
  wchar_t text[32] = {};
  GetPrivateProfileStringW(kSection, key, L"", text, 32, file.c_str());
  if (text[0] == L'\0') return false;
  wchar_t* end = nullptr;
  long read = std::wcstol(text, &end, 10);
  if (end == text || *end != L'\0') return false;
  *value = static_cast<LONG>(read);
  return true;
}

void WriteInt(const std::wstring& file, const wchar_t* key, LONG value) {
  WritePrivateProfileStringW(kSection, key, std::to_wstring(value).c_str(),
                             file.c_str());
}

void CenterOnMonitor(HWND window) {
  MONITORINFO monitor = {};
  monitor.cbSize = sizeof(monitor);
  if (!GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTOPRIMARY),
                       &monitor)) {
    return;
  }
  const RECT& work = monitor.rcWork;
  RECT rect;
  if (!GetWindowRect(window, &rect)) return;
  const LONG work_width = work.right - work.left;
  const LONG work_height = work.bottom - work.top;
  // A small laptop screen gets most of it rather than a window cut off.
  const LONG width = std::min(rect.right - rect.left, work_width * 9 / 10);
  const LONG height = std::min(rect.bottom - rect.top, work_height * 9 / 10);
  SetWindowPos(window, nullptr, work.left + (work_width - width) / 2,
               work.top + (work_height - height) / 2, width, height,
               SWP_NOZORDER | SWP_NOACTIVATE);
}

}  // namespace

bool RestoreWindowPlacement(HWND window) {
  const std::wstring file = StateFile(false);
  LONG x = 0, y = 0, width = 0, height = 0, maximized = 0;
  if (!file.empty() && ReadInt(file, L"x", &x) && ReadInt(file, L"y", &y) &&
      ReadInt(file, L"width", &width) && ReadInt(file, L"height", &height) &&
      width >= kMinSaved && height >= kMinSaved) {
    ReadInt(file, L"maximized", &maximized);
    RECT rect = {x, y, x + width, y + height};
    if (MonitorFromRect(&rect, MONITOR_DEFAULTTONULL) != nullptr) {
      // The same kind of coordinates GetWindowPlacement saved (workspace
      // coordinates), and the window stays hidden until the first frame.
      WINDOWPLACEMENT placement = {};
      placement.length = sizeof(placement);
      placement.showCmd = SW_HIDE;
      placement.ptMinPosition = {-1, -1};
      placement.ptMaxPosition = {-1, -1};
      placement.rcNormalPosition = rect;
      if (SetWindowPlacement(window, &placement)) return maximized != 0;
    }
  }
  CenterOnMonitor(window);
  return false;
}

void SaveWindowPlacement(HWND window) {
  if (window == nullptr || !IsWindowVisible(window)) return;
  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(placement);
  if (!GetWindowPlacement(window, &placement)) return;
  const std::wstring file = StateFile(true);
  if (file.empty()) return;
  // The size it goes back to when un-maximized, so a maximized window still
  // remembers its normal size.
  const RECT& rect = placement.rcNormalPosition;
  const bool maximized =
      placement.showCmd == SW_SHOWMAXIMIZED ||
      (placement.showCmd == SW_SHOWMINIMIZED &&
       (placement.flags & WPF_RESTORETOMAXIMIZED) != 0);
  WriteInt(file, L"x", rect.left);
  WriteInt(file, L"y", rect.top);
  WriteInt(file, L"width", rect.right - rect.left);
  WriteInt(file, L"height", rect.bottom - rect.top);
  WriteInt(file, L"maximized", maximized ? 1 : 0);
}
