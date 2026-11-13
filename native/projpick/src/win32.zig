//! Minimal Win32 declarations used by projpick. Plain integer types are used
//! for BOOL/WPARAM/LPARAM so the bindings do not depend on std.os.windows
//! type churn between Zig releases.

pub const BOOL = i32;
pub const UINT = u32;
pub const DWORD = u32;
pub const WORD = u16;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;
pub const HANDLE = ?*anyopaque;
pub const HWND = ?*anyopaque;
pub const HDC = ?*anyopaque;
pub const HGDIOBJ = ?*anyopaque;
pub const HFONT = ?*anyopaque;
pub const HBRUSH = ?*anyopaque;
pub const HBITMAP = ?*anyopaque;
pub const HMONITOR = ?*anyopaque;
pub const HINSTANCE = ?*anyopaque;
pub const HKEY = ?*anyopaque;
pub const HCURSOR = ?*anyopaque;
pub const COLORREF = u32;
pub const WCHAR = u16;

pub const INVALID_HANDLE_VALUE: HANDLE = @ptrFromInt(~@as(usize, 0));

pub const POINT = extern struct { x: i32 = 0, y: i32 = 0 };
pub const SIZE = extern struct { cx: i32 = 0, cy: i32 = 0 };
pub const RECT = extern struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };

pub const MSG = extern struct {
    hwnd: HWND = null,
    message: UINT = 0,
    wParam: WPARAM = 0,
    lParam: LPARAM = 0,
    time: DWORD = 0,
    pt: POINT = .{},
    lPrivate: DWORD = 0,
};

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE = null,
    hIcon: ?*anyopaque = null,
    hCursor: HCURSOR = null,
    hbrBackground: HBRUSH = null,
    lpszMenuName: ?[*:0]const u16 = null,
    lpszClassName: [*:0]const u16,
    hIconSm: ?*anyopaque = null,
};

pub const PAINTSTRUCT = extern struct {
    hdc: HDC = null,
    fErase: BOOL = 0,
    rcPaint: RECT = .{},
    fRestore: BOOL = 0,
    fIncUpdate: BOOL = 0,
    rgbReserved: [32]u8 = @splat(0),
};

pub const MONITORINFO = extern struct {
    cbSize: DWORD = @sizeOf(MONITORINFO),
    rcMonitor: RECT = .{},
    rcWork: RECT = .{},
    dwFlags: DWORD = 0,
};

pub const FILETIME = extern struct { dwLowDateTime: DWORD = 0, dwHighDateTime: DWORD = 0 };

pub const WIN32_FIND_DATAW = extern struct {
    dwFileAttributes: DWORD,
    ftCreationTime: FILETIME,
    ftLastAccessTime: FILETIME,
    ftLastWriteTime: FILETIME,
    nFileSizeHigh: DWORD,
    nFileSizeLow: DWORD,
    dwReserved0: DWORD,
    dwReserved1: DWORD,
    cFileName: [260]u16,
    cAlternateFileName: [14]u16,
    dwFileType: DWORD,
    dwCreatorType: DWORD,
    wFinderFlags: WORD,
};

pub const WIN32_FILE_ATTRIBUTE_DATA = extern struct {
    dwFileAttributes: DWORD = 0,
    ftCreationTime: FILETIME = .{},
    ftLastAccessTime: FILETIME = .{},
    ftLastWriteTime: FILETIME = .{},
    nFileSizeHigh: DWORD = 0,
    nFileSizeLow: DWORD = 0,
};

pub const STARTUPINFOW = extern struct {
    cb: DWORD = @sizeOf(STARTUPINFOW),
    lpReserved: ?[*:0]u16 = null,
    lpDesktop: ?[*:0]u16 = null,
    lpTitle: ?[*:0]u16 = null,
    dwX: DWORD = 0,
    dwY: DWORD = 0,
    dwXSize: DWORD = 0,
    dwYSize: DWORD = 0,
    dwXCountChars: DWORD = 0,
    dwYCountChars: DWORD = 0,
    dwFillAttribute: DWORD = 0,
    dwFlags: DWORD = 0,
    wShowWindow: WORD = 0,
    cbReserved2: WORD = 0,
    lpReserved2: ?*u8 = null,
    hStdInput: HANDLE = null,
    hStdOutput: HANDLE = null,
    hStdError: HANDLE = null,
};

pub const PROCESS_INFORMATION = extern struct {
    hProcess: HANDLE = null,
    hThread: HANDLE = null,
    dwProcessId: DWORD = 0,
    dwThreadId: DWORD = 0,
};

pub const SYSTEMTIME = extern struct {
    wYear: WORD = 0,
    wMonth: WORD = 0,
    wDayOfWeek: WORD = 0,
    wDay: WORD = 0,
    wHour: WORD = 0,
    wMinute: WORD = 0,
    wSecond: WORD = 0,
    wMilliseconds: WORD = 0,
};

// Window messages
pub const WM_DESTROY = 0x0002;
pub const WM_SIZE = 0x0005;
pub const WM_ACTIVATE = 0x0006;
pub const WM_PAINT = 0x000F;
pub const WM_CLOSE = 0x0010;
pub const WM_ERASEBKGND = 0x0014;
pub const WM_SETTINGCHANGE = 0x001A;
pub const WM_SETCURSOR = 0x0020;
pub const WM_KEYDOWN = 0x0100;
pub const WM_CHAR = 0x0102;
pub const WM_SYSKEYDOWN = 0x0104;
pub const WM_TIMER = 0x0113;
pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONDBLCLK = 0x0203;
pub const WM_MOUSEWHEEL = 0x020A;
pub const WM_DPICHANGED = 0x02E0;
pub const WM_APP = 0x8000;
pub const WA_INACTIVE = 0;

// Window styles
pub const WS_POPUP: DWORD = 0x80000000;
pub const WS_CLIPCHILDREN: DWORD = 0x02000000;
pub const WS_EX_TOPMOST: DWORD = 0x00000008;
pub const WS_EX_TOOLWINDOW: DWORD = 0x00000080;
pub const CS_DBLCLKS: UINT = 0x0008;

pub const SW_HIDE = 0;
pub const SW_SHOWNA = 8;
pub const SW_SHOWNORMAL = 1;
pub const SW_SHOW = 5;
pub const SWP_NOSIZE: UINT = 0x0001;
pub const SWP_NOMOVE: UINT = 0x0002;
pub const SWP_NOACTIVATE: UINT = 0x0010;
pub const SWP_SHOWWINDOW: UINT = 0x0040;
pub const HWND_TOPMOST: HWND = @ptrFromInt(~@as(usize, 0)); // (HWND)-1

pub const VK_BACK = 0x08;
pub const VK_TAB = 0x09;
pub const VK_RETURN = 0x0D;
pub const VK_SHIFT = 0x10;
pub const VK_CONTROL = 0x11;
pub const VK_MENU = 0x12;
pub const VK_ESCAPE = 0x1B;
pub const VK_PRIOR = 0x21;
pub const VK_NEXT = 0x22;
pub const VK_END = 0x23;
pub const VK_HOME = 0x24;
pub const VK_UP = 0x26;
pub const VK_DOWN = 0x28;

pub const MONITOR_DEFAULTTONEAREST: DWORD = 2;
pub const MONITOR_DEFAULTTOPRIMARY: DWORD = 1;
pub const MDT_EFFECTIVE_DPI = 0;
pub const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2: isize = -4;

pub const FILE_ATTRIBUTE_DIRECTORY: DWORD = 0x10;
pub const FILE_ATTRIBUTE_REPARSE_POINT: DWORD = 0x400;
pub const FILE_ATTRIBUTE_OFFLINE: DWORD = 0x1000;
pub const FILE_ATTRIBUTE_RECALL_ON_OPEN: DWORD = 0x40000;
pub const FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS: DWORD = 0x400000;
pub const FindExInfoBasic = 1;
pub const FindExSearchNameMatch = 0;
pub const FIND_FIRST_EX_LARGE_FETCH: DWORD = 2;

pub const GENERIC_READ: DWORD = 0x80000000;
pub const GENERIC_WRITE: DWORD = 0x40000000;
pub const FILE_APPEND_DATA: DWORD = 0x0004;
pub const FILE_SHARE_READ: DWORD = 1;
pub const FILE_SHARE_WRITE: DWORD = 2;
pub const FILE_SHARE_DELETE: DWORD = 4;
pub const CREATE_ALWAYS: DWORD = 2;
pub const OPEN_EXISTING: DWORD = 3;
pub const OPEN_ALWAYS: DWORD = 4;
pub const FILE_END: DWORD = 2;
pub const MOVEFILE_REPLACE_EXISTING: DWORD = 1;
pub const MOVEFILE_WRITE_THROUGH: DWORD = 8;

pub const CREATE_NO_WINDOW: DWORD = 0x08000000;
pub const CREATE_NEW_CONSOLE: DWORD = 0x00000010;
pub const DETACHED_PROCESS: DWORD = 0x00000008;
pub const CREATE_NEW_PROCESS_GROUP: DWORD = 0x00000200;
pub const CREATE_UNICODE_ENVIRONMENT: DWORD = 0x00000400;
pub const CREATE_BREAKAWAY_FROM_JOB: DWORD = 0x01000000;
pub const IDLE_PRIORITY_CLASS: DWORD = 0x00000040;
pub const BELOW_NORMAL_PRIORITY_CLASS: DWORD = 0x00004000;
pub const HIGH_PRIORITY_CLASS: DWORD = 0x00000080;
pub const THREAD_MODE_BACKGROUND_BEGIN: i32 = 0x00010000;
pub const ERROR_ALREADY_EXISTS: DWORD = 183;
pub const WAIT_OBJECT_0: DWORD = 0;
pub const SYNCHRONIZE: DWORD = 0x00100000;
pub const TOKEN_QUERY: DWORD = 0x0008;
pub const TOKEN_DUPLICATE: DWORD = 0x0002;
pub const STD_OUTPUT_HANDLE: DWORD = @bitCast(@as(i32, -11));
pub const ATTACH_PARENT_PROCESS: DWORD = @bitCast(@as(i32, -1));
pub const ASFW_ANY: DWORD = @bitCast(@as(i32, -1));

pub const HKEY_CURRENT_USER: HKEY = @ptrFromInt(0x80000001);
pub const KEY_SET_VALUE: DWORD = 0x0002;
pub const KEY_QUERY_VALUE: DWORD = 0x0001;
pub const REG_SZ: DWORD = 1;

pub const CF_UNICODETEXT: UINT = 13;
pub const GMEM_MOVEABLE: UINT = 0x0002;

pub const TRANSPARENT = 1;
pub const ETO_OPAQUE: UINT = 2;
pub const ETO_CLIPPED: UINT = 4;
pub const FW_NORMAL = 400;
pub const FW_SEMIBOLD = 600;
pub const CLEARTYPE_QUALITY = 5;
pub const DEFAULT_CHARSET = 1;
pub const SRCCOPY: DWORD = 0x00CC0020;
pub const IDC_ARROW: usize = 32512;
pub const MB_OK: UINT = 0;
pub const MB_ICONWARNING: UINT = 0x30;
pub const MB_SETFOREGROUND: UINT = 0x10000;

pub const DWMWA_TRANSITIONS_FORCEDISABLED: DWORD = 3;
pub const DWMWA_WINDOW_CORNER_PREFERENCE: DWORD = 33;
pub const DWMWA_BORDER_COLOR: DWORD = 34;
pub const DWMWA_CLOAKED: DWORD = 14;
pub const GW_HWNDNEXT: UINT = 2;
pub const GW_OWNER: UINT = 4;
pub const GWL_EXSTYLE: i32 = -20;
pub const DWMWCP_ROUND: DWORD = 2;

// kernel32
pub extern "kernel32" fn GetModuleHandleW(name: ?[*:0]const u16) callconv(.winapi) HINSTANCE;
pub extern "kernel32" fn GetModuleFileNameW(h: HINSTANCE, buf: [*]u16, n: DWORD) callconv(.winapi) DWORD;
pub extern "kernel32" fn GetCommandLineW() callconv(.winapi) [*:0]u16;
pub extern "kernel32" fn CreateMutexW(attrs: ?*anyopaque, owner: BOOL, name: [*:0]const u16) callconv(.winapi) HANDLE;
pub extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;
pub extern "kernel32" fn CloseHandle(h: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn CreateThread(attrs: ?*anyopaque, stack: usize, start: *const fn (?*anyopaque) callconv(.winapi) DWORD, param: ?*anyopaque, flags: DWORD, id: ?*DWORD) callconv(.winapi) HANDLE;
pub extern "kernel32" fn Sleep(ms: DWORD) callconv(.winapi) void;
pub extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
pub extern "kernel32" fn QueryPerformanceCounter(v: *i64) callconv(.winapi) BOOL;
pub extern "kernel32" fn QueryPerformanceFrequency(v: *i64) callconv(.winapi) BOOL;
pub extern "kernel32" fn CreateFileW(name: [*:0]const u16, access: DWORD, share: DWORD, sa: ?*anyopaque, disp: DWORD, flags: DWORD, tmpl: HANDLE) callconv(.winapi) HANDLE;
pub extern "kernel32" fn ReadFile(h: HANDLE, buf: [*]u8, n: DWORD, read: ?*DWORD, ov: ?*anyopaque) callconv(.winapi) BOOL;
pub extern "kernel32" fn WriteFile(h: HANDLE, buf: [*]const u8, n: DWORD, written: ?*DWORD, ov: ?*anyopaque) callconv(.winapi) BOOL;
pub extern "kernel32" fn GetFileSizeEx(h: HANDLE, size: *i64) callconv(.winapi) BOOL;
pub extern "kernel32" fn SetFilePointerEx(h: HANDLE, dist: i64, newpos: ?*i64, method: DWORD) callconv(.winapi) BOOL;
pub extern "kernel32" fn SetEndOfFile(h: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn MoveFileExW(from: [*:0]const u16, to: [*:0]const u16, flags: DWORD) callconv(.winapi) BOOL;
pub extern "kernel32" fn CopyFileW(from: [*:0]const u16, to: [*:0]const u16, fail_if_exists: BOOL) callconv(.winapi) BOOL;
pub extern "kernel32" fn DeleteFileW(name: [*:0]const u16) callconv(.winapi) BOOL;
pub extern "kernel32" fn CreateDirectoryW(name: [*:0]const u16, sa: ?*anyopaque) callconv(.winapi) BOOL;
pub extern "kernel32" fn GetFileAttributesExW(name: [*:0]const u16, level: i32, info: *WIN32_FILE_ATTRIBUTE_DATA) callconv(.winapi) BOOL;
pub extern "kernel32" fn FindFirstFileExW(name: [*:0]const u16, level: i32, data: *WIN32_FIND_DATAW, op: i32, filter: ?*anyopaque, flags: DWORD) callconv(.winapi) HANDLE;
pub extern "kernel32" fn FindNextFileW(h: HANDLE, data: *WIN32_FIND_DATAW) callconv(.winapi) BOOL;
pub extern "kernel32" fn FindClose(h: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn GetEnvironmentVariableW(name: [*:0]const u16, buf: ?[*]u16, n: DWORD) callconv(.winapi) DWORD;
pub extern "kernel32" fn CreateProcessW(app: ?[*:0]const u16, cmd: ?[*:0]u16, pa: ?*anyopaque, ta: ?*anyopaque, inherit: BOOL, flags: DWORD, env: ?*anyopaque, cwd: ?[*:0]const u16, si: *STARTUPINFOW, pi: *PROCESS_INFORMATION) callconv(.winapi) BOOL;
pub extern "kernel32" fn GetStdHandle(which: DWORD) callconv(.winapi) HANDLE;
pub extern "kernel32" fn AttachConsole(pid: DWORD) callconv(.winapi) BOOL;
pub extern "kernel32" fn ExitProcess(code: UINT) callconv(.winapi) noreturn;
pub extern "kernel32" fn GetCurrentProcess() callconv(.winapi) HANDLE;
pub extern "kernel32" fn OpenProcess(access: DWORD, inherit: BOOL, pid: DWORD) callconv(.winapi) HANDLE;
pub extern "kernel32" fn WaitForSingleObject(h: HANDLE, ms: DWORD) callconv(.winapi) DWORD;
pub extern "kernel32" fn GetLocalTime(t: *SYSTEMTIME) callconv(.winapi) void;
pub extern "kernel32" fn GlobalAlloc(flags: UINT, bytes: usize) callconv(.winapi) HANDLE;
pub extern "kernel32" fn GlobalLock(h: HANDLE) callconv(.winapi) ?*anyopaque;
pub extern "kernel32" fn GlobalUnlock(h: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn GlobalFree(h: HANDLE) callconv(.winapi) HANDLE;
pub extern "kernel32" fn LCMapStringEx(locale: ?[*:0]const u16, flags: DWORD, src: [*]const u16, srclen: i32, dst: ?[*]u16, dstlen: i32, ver: ?*anyopaque, res: ?*anyopaque, sort: isize) callconv(.winapi) i32;
pub extern "kernel32" fn SetPriorityClass(h: HANDLE, cls: DWORD) callconv(.winapi) BOOL;
pub extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) DWORD;
pub extern "kernel32" fn GetCurrentThread() callconv(.winapi) HANDLE;
pub extern "kernel32" fn SetThreadPriority(t: HANDLE, prio: i32) callconv(.winapi) BOOL;

// user32
pub extern "user32" fn RegisterClassExW(wc: *const WNDCLASSEXW) callconv(.winapi) u16;
pub extern "user32" fn CreateWindowExW(ex: DWORD, cls: [*:0]const u16, title: [*:0]const u16, style: DWORD, x: i32, y: i32, w: i32, h: i32, parent: HWND, menu: ?*anyopaque, inst: HINSTANCE, param: ?*anyopaque) callconv(.winapi) HWND;
pub extern "user32" fn DestroyWindow(h: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn DefWindowProcW(h: HWND, m: UINT, w: WPARAM, l: LPARAM) callconv(.winapi) LRESULT;
pub extern "user32" fn GetMessageW(msg: *MSG, h: HWND, min: UINT, max: UINT) callconv(.winapi) BOOL;
pub extern "user32" fn TranslateMessage(msg: *const MSG) callconv(.winapi) BOOL;
pub extern "user32" fn DispatchMessageW(msg: *const MSG) callconv(.winapi) LRESULT;
pub extern "user32" fn PostMessageW(h: HWND, m: UINT, w: WPARAM, l: LPARAM) callconv(.winapi) BOOL;
pub extern "user32" fn PostQuitMessage(code: i32) callconv(.winapi) void;
pub extern "user32" fn ShowWindow(h: HWND, cmd: i32) callconv(.winapi) BOOL;
pub extern "user32" fn IsWindowVisible(h: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn SetForegroundWindow(h: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn GetForegroundWindow() callconv(.winapi) HWND;
pub extern "user32" fn GetShellWindow() callconv(.winapi) HWND;
pub extern "user32" fn BringWindowToTop(h: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn SetFocus(h: HWND) callconv(.winapi) HWND;
pub extern "user32" fn SetWindowPos(h: HWND, after: HWND, x: i32, y: i32, cx: i32, cy: i32, flags: UINT) callconv(.winapi) BOOL;
pub extern "user32" fn InvalidateRect(h: HWND, r: ?*const RECT, erase: BOOL) callconv(.winapi) BOOL;
pub extern "user32" fn UpdateWindow(h: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn BeginPaint(h: HWND, ps: *PAINTSTRUCT) callconv(.winapi) HDC;
pub extern "user32" fn EndPaint(h: HWND, ps: *const PAINTSTRUCT) callconv(.winapi) BOOL;
pub extern "user32" fn GetDC(h: HWND) callconv(.winapi) HDC;
pub extern "user32" fn ReleaseDC(h: HWND, dc: HDC) callconv(.winapi) i32;
pub extern "user32" fn FillRect(dc: HDC, r: *const RECT, b: HBRUSH) callconv(.winapi) i32;
pub extern "user32" fn SetTimer(h: HWND, id: usize, ms: UINT, f: ?*anyopaque) callconv(.winapi) usize;
pub extern "user32" fn KillTimer(h: HWND, id: usize) callconv(.winapi) BOOL;
pub extern "user32" fn FindWindowW(cls: ?[*:0]const u16, title: ?[*:0]const u16) callconv(.winapi) HWND;
pub extern "user32" fn SetWindowTextW(h: HWND, t: [*:0]const u16) callconv(.winapi) BOOL;
pub extern "user32" fn GetWindowThreadProcessId(h: HWND, pid: ?*DWORD) callconv(.winapi) DWORD;
pub extern "user32" fn GetWindow(h: HWND, cmd: UINT) callconv(.winapi) HWND;
pub extern "user32" fn GetWindowLongPtrW(h: HWND, index: i32) callconv(.winapi) isize;
pub extern "user32" fn IsIconic(h: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn MonitorFromPoint(pt: POINT, flags: DWORD) callconv(.winapi) HMONITOR;
pub extern "user32" fn MonitorFromWindow(h: HWND, flags: DWORD) callconv(.winapi) HMONITOR;
pub extern "user32" fn GetMonitorInfoW(m: HMONITOR, mi: *MONITORINFO) callconv(.winapi) BOOL;
pub extern "user32" fn GetCursorPos(pt: *POINT) callconv(.winapi) BOOL;
pub extern "user32" fn SetProcessDpiAwarenessContext(ctx: isize) callconv(.winapi) BOOL;
pub extern "user32" fn LoadCursorW(inst: HINSTANCE, name: usize) callconv(.winapi) HCURSOR;
pub extern "user32" fn GetKeyState(vk: i32) callconv(.winapi) i16;
pub extern "user32" fn MessageBoxW(h: HWND, text: [*:0]const u16, caption: [*:0]const u16, flags: UINT) callconv(.winapi) i32;
pub extern "user32" fn OpenClipboard(h: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn CloseClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn EmptyClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn SetClipboardData(fmt: UINT, h: HANDLE) callconv(.winapi) HANDLE;
pub extern "user32" fn GetClipboardData(fmt: UINT) callconv(.winapi) HANDLE;
pub extern "user32" fn AllowSetForegroundWindow(pid: DWORD) callconv(.winapi) BOOL;
pub extern "user32" fn SetCursor(c: HCURSOR) callconv(.winapi) HCURSOR;

// gdi32
pub extern "gdi32" fn CreateCompatibleDC(dc: HDC) callconv(.winapi) HDC;
pub extern "gdi32" fn CreateCompatibleBitmap(dc: HDC, w: i32, h: i32) callconv(.winapi) HBITMAP;
pub extern "gdi32" fn SelectObject(dc: HDC, o: HGDIOBJ) callconv(.winapi) HGDIOBJ;
pub extern "gdi32" fn DeleteObject(o: HGDIOBJ) callconv(.winapi) BOOL;
pub extern "gdi32" fn DeleteDC(dc: HDC) callconv(.winapi) BOOL;
pub extern "gdi32" fn BitBlt(dst: HDC, x: i32, y: i32, w: i32, h: i32, src: HDC, sx: i32, sy: i32, rop: DWORD) callconv(.winapi) BOOL;
pub extern "gdi32" fn GetTextFaceW(dc: HDC, count: i32, name: [*]u16) callconv(.winapi) i32;
pub extern "gdi32" fn CreateFontW(h: i32, w: i32, esc: i32, orient: i32, weight: i32, italic: DWORD, underline: DWORD, strike: DWORD, charset: DWORD, outprec: DWORD, clipprec: DWORD, quality: DWORD, pitch: DWORD, face: [*:0]const u16) callconv(.winapi) HFONT;
pub extern "gdi32" fn SetTextColor(dc: HDC, c: COLORREF) callconv(.winapi) COLORREF;
pub extern "gdi32" fn SetBkMode(dc: HDC, mode: i32) callconv(.winapi) i32;
pub extern "gdi32" fn ExtTextOutW(dc: HDC, x: i32, y: i32, opts: UINT, r: ?*const RECT, s: [*]const u16, n: UINT, dx: ?*const i32) callconv(.winapi) BOOL;
pub extern "gdi32" fn GetTextExtentPoint32W(dc: HDC, s: [*]const u16, n: i32, sz: *SIZE) callconv(.winapi) BOOL;
pub extern "gdi32" fn CreateSolidBrush(c: COLORREF) callconv(.winapi) HBRUSH;

// others
pub extern "imm32" fn ImmDisableIME(thread: DWORD) callconv(.winapi) BOOL;
pub extern "shcore" fn GetDpiForMonitor(m: HMONITOR, kind: i32, x: *UINT, y: *UINT) callconv(.winapi) i32;
pub extern "dwmapi" fn DwmSetWindowAttribute(h: HWND, attr: DWORD, val: *const anyopaque, size: DWORD) callconv(.winapi) i32;
pub extern "dwmapi" fn DwmGetWindowAttribute(h: HWND, attr: DWORD, val: *anyopaque, size: DWORD) callconv(.winapi) i32;
pub extern "shell32" fn ShellExecuteW(h: HWND, op: ?[*:0]const u16, file: [*:0]const u16, params: ?[*:0]const u16, dir: ?[*:0]const u16, show: i32) callconv(.winapi) HINSTANCE;
pub extern "shell32" fn CommandLineToArgvW(cmd: [*:0]const u16, argc: *i32) callconv(.winapi) ?[*][*:0]u16;
pub extern "advapi32" fn RegOpenKeyExW(key: HKEY, sub: [*:0]const u16, opts: DWORD, sam: DWORD, out: *HKEY) callconv(.winapi) i32;
pub extern "advapi32" fn RegSetValueExW(key: HKEY, name: [*:0]const u16, res: DWORD, typ: DWORD, data: [*]const u8, n: DWORD) callconv(.winapi) i32;
pub extern "advapi32" fn RegDeleteValueW(key: HKEY, name: [*:0]const u16) callconv(.winapi) i32;
pub extern "advapi32" fn RegCloseKey(key: HKEY) callconv(.winapi) i32;
pub extern "advapi32" fn OpenProcessToken(proc: HANDLE, access: DWORD, tok: *HANDLE) callconv(.winapi) BOOL;
pub extern "userenv" fn CreateEnvironmentBlock(env: *?*anyopaque, tok: HANDLE, inherit: BOOL) callconv(.winapi) BOOL;
pub extern "userenv" fn DestroyEnvironmentBlock(env: ?*anyopaque) callconv(.winapi) BOOL;

pub fn L(comptime s: []const u8) *const [@import("std").unicode.calcUtf16LeLen(s) catch unreachable:0]u16 {
    return @import("std").unicode.utf8ToUtf16LeStringLiteral(s);
}

pub fn rgb(hex: u32) COLORREF {
    // 0xRRGGBB -> COLORREF 0x00BBGGRR
    return ((hex & 0xFF) << 16) | (hex & 0xFF00) | ((hex >> 16) & 0xFF);
}
