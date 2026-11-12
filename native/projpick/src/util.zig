//! Small Windows helpers: environment, paths, whole-file IO, logging.
//! All paths are UTF-16 slices; `[:0]u16` where Win32 needs a terminator.

const std = @import("std");
const w = @import("win32.zig");

pub const gpa = std.heap.page_allocator;

pub fn env(a: std.mem.Allocator, comptime name: []const u8) ?[:0]u16 {
    const n = w.GetEnvironmentVariableW(w.L(name), null, 0);
    if (n == 0) return null;
    const buf = a.allocSentinel(u16, n - 1, 0) catch return null;
    const got = w.GetEnvironmentVariableW(w.L(name), buf.ptr, n);
    if (got == 0 or got >= n) {
        a.free(buf);
        return null;
    }
    return buf[0..got :0];
}

/// Joins parts with '\' (no duplicate separators). Caller owns the result.
pub fn join(a: std.mem.Allocator, parts: []const []const u16) ![:0]u16 {
    var len: usize = 0;
    for (parts) |p| len += p.len + 1;
    var out = try a.allocSentinel(u16, len, 0);
    var n: usize = 0;
    for (parts, 0..) |p, i| {
        var part = p;
        if (i > 0) {
            while (part.len > 0 and part[0] == '\\') part = part[1..];
            if (n > 0 and out[n - 1] != '\\') {
                out[n] = '\\';
                n += 1;
            }
        }
        @memcpy(out[n .. n + part.len], part);
        n += part.len;
    }
    out[n] = 0;
    return out[0..n :0];
}

pub fn dupZ(a: std.mem.Allocator, s: []const u16) ![:0]u16 {
    const out = try a.allocSentinel(u16, s.len, 0);
    @memcpy(out[0..s.len], s);
    return out;
}

pub fn toUtf16(a: std.mem.Allocator, s: []const u8) ![:0]u16 {
    return std.unicode.wtf8ToWtf16LeAllocZ(a, s) catch |e| switch (e) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidUtf8,
    };
}

pub fn toUtf8(a: std.mem.Allocator, s: []const u16) ![]u8 {
    return std.unicode.wtf16LeToWtf8Alloc(a, s);
}

pub fn eqlIgnoreCase(a: []const u16, b: []const u16) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        const lx = if (x >= 'A' and x <= 'Z') x + 32 else x;
        const ly = if (y >= 'A' and y <= 'Z') y + 32 else y;
        if (lx != ly) return false;
    }
    return true;
}

pub fn startsWithIgnoreCase(s: []const u16, prefix: []const u16) bool {
    return s.len >= prefix.len and eqlIgnoreCase(s[0..prefix.len], prefix);
}

pub fn endsWithIgnoreCase(s: []const u16, suffix: []const u16) bool {
    return s.len >= suffix.len and eqlIgnoreCase(s[s.len - suffix.len ..], suffix);
}

pub fn exists(path: [:0]const u16) bool {
    var info: w.WIN32_FILE_ATTRIBUTE_DATA = .{};
    return w.GetFileAttributesExW(path, 0, &info) != 0;
}

pub fn isDir(path: [:0]const u16) bool {
    var info: w.WIN32_FILE_ATTRIBUTE_DATA = .{};
    return w.GetFileAttributesExW(path, 0, &info) != 0 and (info.dwFileAttributes & w.FILE_ATTRIBUTE_DIRECTORY) != 0;
}

/// Last-write time as a 64-bit FILETIME, 0 if missing.
pub fn mtime(path: [:0]const u16) u64 {
    var info: w.WIN32_FILE_ATTRIBUTE_DATA = .{};
    if (w.GetFileAttributesExW(path, 0, &info) == 0) return 0;
    return (@as(u64, info.ftLastWriteTime.dwHighDateTime) << 32) | info.ftLastWriteTime.dwLowDateTime;
}

pub fn readFile(a: std.mem.Allocator, path: [:0]const u16, max: usize) ![]u8 {
    const h = w.CreateFileW(path, w.GENERIC_READ, w.FILE_SHARE_READ | w.FILE_SHARE_WRITE | w.FILE_SHARE_DELETE, null, w.OPEN_EXISTING, 0, null);
    if (h == w.INVALID_HANDLE_VALUE) return error.FileNotFound;
    defer _ = w.CloseHandle(h);
    var size: i64 = 0;
    if (w.GetFileSizeEx(h, &size) == 0 or size < 0) return error.ReadFailed;
    const n: usize = @intCast(@min(size, @as(i64, @intCast(max))));
    const buf = try a.alloc(u8, n);
    errdefer a.free(buf);
    var got: usize = 0;
    while (got < n) {
        var r: w.DWORD = 0;
        if (w.ReadFile(h, buf.ptr + got, @intCast(@min(n - got, 1 << 30)), &r, null) == 0 or r == 0) break;
        got += r;
    }
    return buf[0..got];
}

/// Writes atomically: temp file next to the target, then replace.
pub fn writeFileAtomic(a: std.mem.Allocator, path: [:0]const u16, data: []const u8) !void {
    const tmp = try std.mem.concatWithSentinel(a, u16, &.{ path, w.L(".tmp") }, 0);
    defer a.free(tmp);
    const h = w.CreateFileW(tmp, w.GENERIC_WRITE, 0, null, w.CREATE_ALWAYS, 0, null);
    if (h == w.INVALID_HANDLE_VALUE) return error.WriteFailed;
    var off: usize = 0;
    var ok = true;
    while (off < data.len) {
        var wr: w.DWORD = 0;
        if (w.WriteFile(h, data.ptr + off, @intCast(@min(data.len - off, 1 << 30)), &wr, null) == 0) {
            ok = false;
            break;
        }
        off += wr;
    }
    _ = w.CloseHandle(h);
    if (!ok or w.MoveFileExW(tmp, path, w.MOVEFILE_REPLACE_EXISTING) == 0) {
        _ = w.DeleteFileW(tmp);
        return error.WriteFailed;
    }
}

pub fn ensureDir(path: [:0]const u16) void {
    _ = w.CreateDirectoryW(path, null);
}

/// %LOCALAPPDATA%\projpick (created on demand). Lives for the process.
pub fn dataDir() [:0]u16 {
    const S = struct {
        var dir: ?[:0]u16 = null;
    };
    if (S.dir) |d| return d;
    const base = env(gpa, "LOCALAPPDATA") orelse env(gpa, "TEMP") orelse (dupZ(gpa, w.L("C:\\")) catch unreachable);
    const d = join(gpa, &.{ base, w.L("projpick") }) catch unreachable;
    ensureDir(d);
    S.dir = d;
    return d;
}

pub fn dataFile(comptime name: []const u8) [:0]u16 {
    return join(gpa, &.{ dataDir(), w.L(name) }) catch unreachable;
}

var log_lock: std.atomic.Value(bool) = .init(false);

/// Appends a timestamped line to %LOCALAPPDATA%\projpick\projpick.log
/// (truncated when it grows past 256 KiB). Never fails the caller.
pub fn log(comptime fmt: []const u8, args: anytype) void {
    while (log_lock.swap(true, .acquire)) w.Sleep(0);
    defer log_lock.store(false, .release);
    var buf: [2048]u8 = undefined;
    var t: w.SYSTEMTIME = .{};
    w.GetLocalTime(&t);
    const head = std.fmt.bufPrint(&buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3} [{d}] ", .{
        t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond, t.wMilliseconds, w.GetCurrentProcessId(),
    }) catch return;
    const body = std.fmt.bufPrint(buf[head.len..], fmt ++ "\r\n", args) catch buf[head.len..head.len];
    const path = dataFile("projpick.log");
    defer gpa.free(path);
    const h = w.CreateFileW(path, w.FILE_APPEND_DATA | w.GENERIC_WRITE, w.FILE_SHARE_READ | w.FILE_SHARE_WRITE, null, w.OPEN_ALWAYS, 0, null);
    if (h == w.INVALID_HANDLE_VALUE) return;
    defer _ = w.CloseHandle(h);
    var size: i64 = 0;
    if (w.GetFileSizeEx(h, &size) != 0 and size > 256 * 1024) {
        _ = w.SetFilePointerEx(h, 0, null, 0);
        _ = w.SetEndOfFile(h);
    }
    _ = w.SetFilePointerEx(h, 0, null, w.FILE_END);
    var wr: w.DWORD = 0;
    _ = w.WriteFile(h, &buf, @intCast(head.len + body.len), &wr, null);
}

pub fn qpcMs() f64 {
    const S = struct {
        var freq: i64 = 0;
    };
    if (S.freq == 0) _ = w.QueryPerformanceFrequency(&S.freq);
    var v: i64 = 0;
    _ = w.QueryPerformanceCounter(&v);
    return @as(f64, @floatFromInt(v)) * 1000.0 / @as(f64, @floatFromInt(S.freq));
}
