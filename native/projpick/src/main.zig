//! projpick — a resident project picker for Windows.
//!
//! Why it is built this way (the failure modes of the previous picker):
//!   - The hotkey is a RegisterHotKey registration, not a low-level keyboard
//!     hook. The system matches it, so it cannot time out and be silently
//!     unhooked, it still fires over elevated windows, and a conflicting
//!     registration is reported instead of failing quietly.
//!   - The window is created once at logon and only shown/hidden. A summon
//!     spawns no process, starts no terminal, and runs no scan: the index is
//!     in memory, and WM_HOTKEY grants this process the foreground.
//!   - Rescans run on a background thread and swap the index in when done.
//!
//! Usage:
//!   projpick            show the picker (starts the daemon if needed)
//!   projpick --daemon   run resident (what the logon entry runs)
//!   projpick --install  register this exe at logon and start it
//!   projpick --uninstall / --quit / --scan / --list / --version

const std = @import("std");
const w = @import("win32.zig");
const util = @import("util.zig");
const fuzzy = @import("fuzzy.zig");
const index = @import("index.zig");

const gpa = util.gpa;
const L = w.L;
const version = "1.0.0";

const class_name = L("ProjPickWindow");
const mutex_name = L("Local\\projpick-daemon");
const WM_APP_SHOW = w.WM_APP + 1;
const WM_APP_INDEX = w.WM_APP + 2;
const WM_APP_QUIT = w.WM_APP + 3;
const HOTKEY_ID = 1;
const TIMER_HOTKEY_RETRY = 1;
const TIMER_PREWARM = 2;

// -- configuration ---------------------------------------------------------------

// Built-in colors (Gruvbox Dark) until the profile writes theme.ini.
const Theme = struct {
    bg: u32 = 0x202020,
    fg: u32 = 0xDDC7A1,
    muted: u32 = 0x948576,
    accent: u32 = 0xD8A657,
    selection: u32 = 0x504945,
    match: u32 = 0xE78A4E,
};

const Config = struct {
    mods: u32 = w.MOD_CONTROL | w.MOD_ALT,
    vk: u32 = 'P',
    hotkey_text: []const u16 = L("Ctrl+Alt+P"),
    editor: []const u16 = L("code"),
    terminal: []const u16 = L("wt.exe -d \"{path}\""),
    projects_root: []const u16 = &.{},
    extra_roots: []const []const u16 = &.{},
    font: ?[:0]const u16 = null, // set only by font= in config.ini
    font_px: i32 = 15,
    rows: i32 = 10,
    monitor: enum { cursor, active, primary } = .cursor,
    prewarm: bool = true,
    high_priority: bool = false,
};

const config_template =
    \\# projpick configuration. Restart with `projpick --quit` then `projpick`
    \\# (or log off and on) after changing the hotkey.
    \\
    \\# Global hotkey: Ctrl/Alt/Shift/Win + a letter, digit, F1-F24 or Space.
    \\hotkey=Ctrl+Alt+P
    \\
    \\# Command for Enter. {path} is the project folder; appended if omitted.
    \\# Defaults to %Z_PROJECT_EDITOR% or `code`.
    \\#editor=code
    \\
    \\# Command for Ctrl+E.
    \\#terminal=wt.exe -d "{path}"
    \\
    \\# Every child of this folder is listed (default %Z_PROJECTS_ROOT% or ~\Projects).
    \\#projects=
    \\
    \\# Extra folders to scan besides your home directory, separated by ';'.
    \\#roots=D:\src;E:\work
    \\
    \\# Font for the picker. Default: the terminal font chosen with `font`
    \\# (written to theme.ini by the profile), else Segoe UI.
    \\#font=Segoe UI
    \\#font_size=15
    \\#rows=10
    \\# Monitor to open on: cursor, active, primary
    \\#monitor=cursor
    \\# Warm the PowerShell runtime in the background after logon (1/0)
    \\#prewarm=1
    \\# Process priority while waiting for the hotkey: high or normal
    \\#priority=normal
    \\
;

fn trimSpace(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\r");
}

fn parseHotkey(text: []const u8, cfg: *Config) bool {
    var mods: u32 = 0;
    var vk: u32 = 0;
    var it = std.mem.splitScalar(u8, text, '+');
    while (it.next()) |raw| {
        const t = trimSpace(raw);
        if (std.ascii.eqlIgnoreCase(t, "ctrl") or std.ascii.eqlIgnoreCase(t, "control")) {
            mods |= w.MOD_CONTROL;
        } else if (std.ascii.eqlIgnoreCase(t, "alt")) {
            mods |= w.MOD_ALT;
        } else if (std.ascii.eqlIgnoreCase(t, "shift")) {
            mods |= w.MOD_SHIFT;
        } else if (std.ascii.eqlIgnoreCase(t, "win") or std.ascii.eqlIgnoreCase(t, "super")) {
            mods |= w.MOD_WIN;
        } else if (std.ascii.eqlIgnoreCase(t, "space")) {
            vk = w.VK_SPACE;
        } else if (t.len == 1 and std.ascii.isAlphanumeric(t[0])) {
            vk = std.ascii.toUpper(t[0]);
        } else if (t.len >= 2 and (t[0] == 'F' or t[0] == 'f')) {
            const n = std.fmt.parseInt(u32, t[1..], 10) catch return false;
            if (n < 1 or n > 24) return false;
            vk = w.VK_F1 + n - 1;
        } else return false;
    }
    if (vk == 0 or mods == 0) return false;
    cfg.mods = mods;
    cfg.vk = vk;
    cfg.hotkey_text = util.toUtf16(gpa, text) catch cfg.hotkey_text;
    return true;
}

fn parseHex(text: []const u8) ?u32 {
    const t = std.mem.trimStart(u8, trimSpace(text), "#");
    if (t.len != 6) return null;
    return std.fmt.parseInt(u32, t, 16) catch null;
}

fn configPath() [:0]u16 {
    const base = util.env(gpa, "APPDATA") orelse return util.dataFile("config.ini");
    const dir = util.join(gpa, &.{ base, L("projpick") }) catch unreachable;
    util.ensureDir(dir);
    return util.join(gpa, &.{ dir, L("config.ini") }) catch unreachable;
}

fn loadConfig() Config {
    var cfg = Config{};
    if (util.env(gpa, "Z_PROJECT_EDITOR")) |e| cfg.editor = e;
    if (util.env(gpa, "Z_PROJECTS_ROOT")) |r| cfg.projects_root = r;
    const path = configPath();
    const data = util.readFile(gpa, path, 1 << 20) catch {
        util.writeFileAtomic(gpa, path, config_template) catch {};
        return cfg;
    };
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw| {
        const line = trimSpace(raw);
        if (line.len == 0 or line[0] == '#' or line[0] == ';') continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = trimSpace(line[0..eq]);
        const val = trimSpace(line[eq + 1 ..]);
        if (std.ascii.eqlIgnoreCase(key, "hotkey")) {
            if (!parseHotkey(val, &cfg)) util.log("config: invalid hotkey '{s}', using Ctrl+Alt+P", .{val});
        } else if (std.ascii.eqlIgnoreCase(key, "editor") and val.len > 0) {
            cfg.editor = util.toUtf16(gpa, val) catch cfg.editor;
        } else if (std.ascii.eqlIgnoreCase(key, "terminal") and val.len > 0) {
            cfg.terminal = util.toUtf16(gpa, val) catch cfg.terminal;
        } else if (std.ascii.eqlIgnoreCase(key, "projects") and val.len > 0) {
            cfg.projects_root = util.toUtf16(gpa, val) catch cfg.projects_root;
        } else if (std.ascii.eqlIgnoreCase(key, "roots")) {
            var list: std.ArrayList([]const u16) = .empty;
            var parts = std.mem.splitScalar(u8, val, ';');
            while (parts.next()) |p| {
                const t = trimSpace(p);
                if (t.len > 0) list.append(gpa, util.toUtf16(gpa, t) catch continue) catch {};
            }
            cfg.extra_roots = list.items;
        } else if (std.ascii.eqlIgnoreCase(key, "font") and val.len > 0) {
            cfg.font = util.toUtf16(gpa, val) catch null;
        } else if (std.ascii.eqlIgnoreCase(key, "font_size")) {
            cfg.font_px = std.math.clamp(std.fmt.parseInt(i32, val, 10) catch cfg.font_px, 9, 40);
        } else if (std.ascii.eqlIgnoreCase(key, "rows")) {
            cfg.rows = std.math.clamp(std.fmt.parseInt(i32, val, 10) catch cfg.rows, 3, 40);
        } else if (std.ascii.eqlIgnoreCase(key, "monitor")) {
            if (std.ascii.eqlIgnoreCase(val, "active")) cfg.monitor = .active;
            if (std.ascii.eqlIgnoreCase(val, "primary")) cfg.monitor = .primary;
            if (std.ascii.eqlIgnoreCase(val, "cursor")) cfg.monitor = .cursor;
        } else if (std.ascii.eqlIgnoreCase(key, "priority")) {
            cfg.high_priority = std.ascii.eqlIgnoreCase(val, "high");
        } else if (std.ascii.eqlIgnoreCase(key, "prewarm")) {
            cfg.prewarm = !std.mem.eql(u8, val, "0");
        }
    }
    return cfg;
}

/// theme.ini is written by the PowerShell profile from the active palette and
/// the terminal font. Sets app.theme_font (owned) to the font= line, if any.
fn loadTheme(path: [:0]const u16) Theme {
    var t = Theme{};
    if (app.theme_font) |f| gpa.free(f);
    app.theme_font = null;
    const data = util.readFile(gpa, path, 64 << 10) catch return t;
    defer gpa.free(data);
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw| {
        const line = trimSpace(raw);
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = trimSpace(line[0..eq]);
        if (std.ascii.eqlIgnoreCase(key, "font")) {
            const val = trimSpace(line[eq + 1 ..]);
            if (val.len > 0) app.theme_font = util.toUtf16(gpa, val) catch null;
            continue;
        }
        const v = parseHex(line[eq + 1 ..]) orelse continue;
        inline for (@typeInfo(Theme).@"struct".field_names) |name| {
            if (std.ascii.eqlIgnoreCase(key, name)) @field(t, name) = v;
        }
    }
    return t;
}

// -- application state (UI thread only, except where noted) ---------------------------

const Result = struct { i: u32, score: i32, on_name: bool };

const App = struct {
    hwnd: w.HWND = null,
    cfg: Config = .{},
    theme: Theme = .{},
    theme_path: [:0]u16 = undefined,
    theme_mtime: u64 = 0,
    theme_font: ?[:0]u16 = null, // font= from theme.ini (the terminal font)
    fonts_stale: bool = false, // theme.ini changed: rebuild fonts on next show
    home: [:0]u16 = undefined,
    idx: ?*index.Index = null,
    recent: index.Recent = .{},
    results: std.ArrayList(Result) = .empty,
    query: [256]u16 = undefined,
    qlen: usize = 0,
    sel: usize = 0,
    top: usize = 0,
    dpi: u32 = 96,
    width: i32 = 0,
    height: i32 = 0,
    font: w.HFONT = null,
    font_big: w.HFONT = null,
    font_small: w.HFONT = null,
    mem_dc: w.HDC = null,
    mem_bmp: w.HBITMAP = null,
    mem_w: i32 = 0,
    mem_h: i32 = 0,
    prev_fg: w.HWND = null,
    hotkey_ok: bool = false,
    hotkey_warned: bool = false,
    last_scan_tick: u64 = 0,
    scanning: std.atomic.Value(bool) = .init(false), // shared with the scan thread
    autostart: bool = false,
    debug: bool = false, // PROJPICK_DEBUG=1: log per-summon timings (file IO stays off the hot path otherwise)
    // per-summon input handling stats, logged on hide
    keys: u32 = 0,
    key_max_ms: f64 = 0,
    key_sum_ms: f64 = 0,
    paint_max_ms: f64 = 0,
};

var app: App = .{};

fn dp(px: i32) i32 {
    return @intCast(@divTrunc(@as(i64, px) * app.dpi + 48, 96));
}

// -- index lifecycle --------------------------------------------------------------

fn projectsRoot() []const u16 {
    // Resolved once; the config is fixed for the process lifetime.
    if (app.cfg.projects_root.len == 0) app.cfg.projects_root = util.join(gpa, &.{ app.home, L("Projects") }) catch app.home;
    return app.cfg.projects_root;
}

fn scanThread(_: ?*anyopaque) callconv(.winapi) w.DWORD {
    // Low CPU and I/O priority: a rescan must never compete with the user.
    _ = w.SetThreadPriority(w.GetCurrentThread(), w.THREAD_MODE_BACKGROUND_BEGIN);
    const idx = index.scan(.{ .home = app.home, .projects_root = projectsRoot(), .extra_roots = app.cfg.extra_roots }) catch |e| {
        util.log("scan failed: {s}", .{@errorName(e)});
        app.scanning.store(false, .release);
        return 1;
    };
    const path = util.dataFile("projects.tsv");
    defer gpa.free(path);
    index.save(idx, path) catch |e| util.log("index save failed: {s}", .{@errorName(e)});
    util.log("scan: {d} projects, {d} dirs, {d:.1} ms", .{ idx.items.len, idx.dirs_visited, idx.scan_ms });
    if (w.PostMessageW(app.hwnd, WM_APP_INDEX, 0, @bitCast(@intFromPtr(idx))) == 0) idx.destroy();
    return 0;
}

fn startScan() void {
    if (app.scanning.swap(true, .acq_rel)) return;
    app.last_scan_tick = w.GetTickCount64();
    const h = w.CreateThread(null, 0, scanThread, null, 0, null);
    if (h == null) {
        app.scanning.store(false, .release);
        return;
    }
    _ = w.CloseHandle(h);
}

fn installIndex(idx: *index.Index) void {
    // Keep the current selection on the same project across a rescan.
    var keep: ?[]const u16 = null;
    if (app.idx) |old| {
        if (app.sel < app.results.items.len) keep = util.dupZ(gpa, old.items[app.results.items[app.sel].i].path) catch null;
        old.destroy();
    }
    app.recent.apply(idx);
    app.idx = idx;
    filter();
    if (keep) |k| {
        defer gpa.free(k);
        for (app.results.items, 0..) |r, n| {
            if (util.eqlIgnoreCase(idx.items[r.i].path, k)) {
                app.sel = n;
                break;
            }
        }
        ensureVisible();
    }
}

// -- filtering ------------------------------------------------------------------

fn resultLess(items: []const index.Project, a: Result, b: Result) bool {
    if (a.score != b.score) return a.score > b.score;
    const pa = items[a.i];
    const pb = items[b.i];
    if (pa.recent != pb.recent) return pa.recent > pb.recent;
    if (pa.name.len != pb.name.len) return pa.name.len < pb.name.len;
    return a.i < b.i;
}

fn filter() void {
    app.results.clearRetainingCapacity();
    app.sel = 0;
    app.top = 0;
    const idx = app.idx orelse return updateTitle();
    var qf: [256]u16 = undefined;
    const q = foldQuery(&qf);
    app.results.ensureTotalCapacity(gpa, idx.items.len) catch return;
    for (idx.items, 0..) |p, i| {
        if (q.len == 0) {
            app.results.appendAssumeCapacity(.{ .i = @intCast(i), .score = 0, .on_name = true });
        } else if (fuzzy.score(q, p.fname, p.name)) |sc| {
            app.results.appendAssumeCapacity(.{ .i = @intCast(i), .score = sc + 40, .on_name = true });
        } else if (fuzzy.score(q, p.fdisp, p.disp)) |sc| {
            app.results.appendAssumeCapacity(.{ .i = @intCast(i), .score = sc, .on_name = false });
        }
    }
    std.mem.sort(Result, app.results.items, idx.items, resultLess);
    updateTitle();
}

fn foldQuery(buf: *[256]u16) []const u16 {
    if (app.qlen == 0) return buf[0..0];
    const LCMAP_LOWERCASE = 0x00000100;
    const n = w.LCMapStringEx(L(""), LCMAP_LOWERCASE, &app.query, @intCast(app.qlen), buf, 256, null, null, 0);
    if (n != app.qlen) fuzzy.foldAscii(buf[0..app.qlen], app.query[0..app.qlen]);
    // spaces in the query are ignored, like typing into fzf's extended mode without terms
    var n_out: usize = 0;
    for (buf[0..app.qlen]) |c| {
        if (c != ' ') {
            buf[n_out] = c;
            n_out += 1;
        }
    }
    return buf[0..n_out];
}

/// Window title carries the state for automation/benchmarks: "projpick [query] count".
fn updateTitle() void {
    var t: [320]u16 = undefined;
    var n: usize = 0;
    for (L("projpick [")) |c| {
        t[n] = c;
        n += 1;
    }
    @memcpy(t[n .. n + app.qlen], app.query[0..app.qlen]);
    n += app.qlen;
    t[n] = ']';
    n += 1;
    var num: [16]u8 = undefined;
    const ns = std.fmt.bufPrint(&num, " {d}", .{app.results.items.len}) catch "";
    for (ns) |c| {
        t[n] = c;
        n += 1;
    }
    t[n] = 0;
    _ = w.SetWindowTextW(app.hwnd, t[0..n :0]);
}

// -- rendering ------------------------------------------------------------------

/// True when GDI really uses `face` for `font`. For a name that isn't
/// installed, CreateFontW silently substitutes another font.
fn fontIsInstalled(font: w.HFONT, face: [:0]const u16) bool {
    const dc = w.GetDC(null);
    defer _ = w.ReleaseDC(null, dc);
    const old = w.SelectObject(dc, font);
    defer _ = w.SelectObject(dc, old);
    var got: [64]u16 = undefined;
    const n = w.GetTextFaceW(dc, got.len, &got);
    if (n <= 0) return false;
    const name = std.mem.sliceTo(got[0..@intCast(n)], 0);
    if (name.len != face.len) return false;
    for (name, face) |a, b| {
        const la = if (a >= 'A' and a <= 'Z') a + 32 else a;
        const lb = if (b >= 'A' and b <= 'Z') b + 32 else b;
        if (la != lb) return false;
    }
    return true;
}

/// Font order: font= in config.ini, then the terminal font from theme.ini,
/// then Segoe UI; the first one that is installed wins.
fn makeFonts() void {
    for ([_]w.HFONT{ app.font, app.font_big, app.font_small }) |f| {
        if (f != null) _ = w.DeleteObject(f);
    }
    const mk = struct {
        fn f(px: i32, face: [:0]const u16) w.HFONT {
            return w.CreateFontW(-dp(px), 0, 0, 0, w.FW_NORMAL, 0, 0, 0, w.DEFAULT_CHARSET, 0, 0, w.CLEARTYPE_QUALITY, 0, face);
        }
    }.f;
    const fallback: [:0]const u16 = L("Segoe UI");
    var face = fallback;
    const theme_face: ?[:0]const u16 = if (app.theme_font) |f| f else null;
    for ([_]?[:0]const u16{ app.cfg.font, theme_face }) |candidate| {
        const c = candidate orelse continue;
        const probe = mk(app.cfg.font_px, c);
        const ok = probe != null and fontIsInstalled(probe, c);
        if (probe != null) _ = w.DeleteObject(probe);
        if (ok) {
            face = c;
            break;
        }
        if (app.debug) util.log("font: '{f}' is not installed, trying the next one", .{std.unicode.fmtUtf16Le(c)});
    }
    app.font = mk(app.cfg.font_px, face);
    app.font_big = mk(app.cfg.font_px + 3, face);
    app.font_small = mk(app.cfg.font_px - 2, face);
    app.fonts_stale = false;
}

const header_h = 52;
const row_h = 32;
const footer_h = 30;
const pad = 14;

fn layoutSize() void {
    app.width = dp(720);
    app.height = dp(header_h + row_h * app.cfg.rows + footer_h + 8);
}

fn ensureBackbuffer() void {
    if (app.mem_dc != null and app.mem_w == app.width and app.mem_h == app.height) return;
    const screen = w.GetDC(null);
    defer _ = w.ReleaseDC(null, screen);
    if (app.mem_dc == null) app.mem_dc = w.CreateCompatibleDC(screen);
    const bmp = w.CreateCompatibleBitmap(screen, app.width, app.height);
    _ = w.SelectObject(app.mem_dc, bmp);
    if (app.mem_bmp != null) _ = w.DeleteObject(app.mem_bmp);
    app.mem_bmp = bmp;
    app.mem_w = app.width;
    app.mem_h = app.height;
}

fn fill(dc: w.HDC, r: w.RECT, color: u32) void {
    const b = w.CreateSolidBrush(w.rgb(color));
    _ = w.FillRect(dc, &r, b);
    _ = w.DeleteObject(b);
}

fn textWidth(dc: w.HDC, t: []const u16) i32 {
    if (t.len == 0) return 0;
    var sz: w.SIZE = .{};
    _ = w.GetTextExtentPoint32W(dc, t.ptr, @intCast(t.len), &sz);
    return sz.cx;
}

/// Draws `t` from x, clipped at `right`, coloring matched positions. Returns end x.
fn drawRuns(dc: w.HDC, x0: i32, y: i32, right: i32, t: []const u16, matched: []const usize, base: u32, hi: u32) i32 {
    var x = x0;
    var i: usize = 0;
    var m: usize = 0;
    while (i < t.len and x < right) {
        const on = m < matched.len and matched[m] == i;
        var j = i + 1;
        if (on) {
            m += 1;
            while (j < t.len and m < matched.len and matched[m] == j) : (j += 1) m += 1;
        } else {
            while (j < t.len and !(m < matched.len and matched[m] == j)) j += 1;
        }
        _ = w.SetTextColor(dc, w.rgb(if (on) hi else base));
        const clip = w.RECT{ .left = x, .top = y - dp(4), .right = right, .bottom = y + dp(row_h) };
        _ = w.ExtTextOutW(dc, x, y, w.ETO_CLIPPED, &clip, t[i..j].ptr, @intCast(j - i), null);
        x += textWidth(dc, t[i..j]);
        i = j;
    }
    return x;
}

fn render() void {
    ensureBackbuffer();
    const dc = app.mem_dc;
    const th = app.theme;
    fill(dc, .{ .right = app.width, .bottom = app.height }, th.bg);
    _ = w.SetBkMode(dc, w.TRANSPARENT);

    // header: prompt glyph, query, caret, count
    _ = w.SelectObject(dc, app.font_big);
    const qy = dp(15);
    _ = w.SetTextColor(dc, w.rgb(th.accent));
    const prompt = L("›");
    _ = w.ExtTextOutW(dc, dp(pad), qy, 0, null, prompt, 1, null);
    const qx = dp(pad) + textWidth(dc, prompt) + dp(10);
    var caret_x = qx;
    if (app.qlen == 0) {
        _ = w.SetTextColor(dc, w.rgb(th.muted));
        const ph = L("Search projects");
        _ = w.ExtTextOutW(dc, qx + dp(6), qy, 0, null, ph, ph.len, null);
    } else {
        _ = w.SetTextColor(dc, w.rgb(th.fg));
        _ = w.ExtTextOutW(dc, qx, qy, 0, null, &app.query, @intCast(app.qlen), null);
        caret_x = qx + textWidth(dc, app.query[0..app.qlen]);
    }
    fill(dc, .{ .left = caret_x + dp(1), .top = qy, .right = caret_x + dp(1) + @max(1, dp(2)), .bottom = qy + dp(app.cfg.font_px + 6) }, th.accent);

    _ = w.SelectObject(dc, app.font_small);
    var cnt: [48]u16 = undefined;
    var c8: [48]u8 = undefined;
    const total = if (app.idx) |i| i.items.len else 0;
    const cs = std.fmt.bufPrint(&c8, "{d}/{d}{s}", .{ app.results.items.len, total, if (app.scanning.load(.acquire)) " ⟳" else "" }) catch "";
    const cn = std.unicode.utf8ToUtf16Le(&cnt, cs) catch 0;
    _ = w.SetTextColor(dc, w.rgb(th.muted));
    const cw = textWidth(dc, cnt[0..cn]);
    _ = w.ExtTextOutW(dc, app.width - dp(pad) - cw, qy + dp(3), 0, null, &cnt, @intCast(cn), null);
    fill(dc, .{ .left = dp(pad), .top = dp(header_h) - 1, .right = app.width - dp(pad), .bottom = dp(header_h) }, th.selection);

    // rows
    _ = w.SelectObject(dc, app.font);
    var qf: [256]u16 = undefined;
    const q = foldQuery(&qf);
    var pos: [256]usize = undefined;
    const rows: usize = @intCast(app.cfg.rows);
    const name_col = dp(250);
    if (app.idx) |idx| {
        var r: usize = 0;
        while (r < rows and app.top + r < app.results.items.len) : (r += 1) {
            const res = app.results.items[app.top + r];
            const p = idx.items[res.i];
            const y0 = dp(header_h + 4) + @as(i32, @intCast(r)) * dp(row_h);
            const ty = y0 + @divTrunc(dp(row_h) - dp(app.cfg.font_px + 4), 2);
            if (app.top + r == app.sel) {
                fill(dc, .{ .left = dp(6), .top = y0, .right = app.width - dp(6), .bottom = y0 + dp(row_h) }, th.selection);
                fill(dc, .{ .left = dp(6), .top = y0 + dp(6), .right = dp(6) + @max(2, dp(3)), .bottom = y0 + dp(row_h) - dp(6) }, th.accent);
            }
            const name_hits = q.len > 0 and res.on_name and fuzzy.positions(q, p.fname, pos[0..q.len]);
            _ = drawRuns(dc, dp(pad + 6), ty, dp(pad) + name_col - dp(10), p.name, if (name_hits) pos[0..q.len] else &.{}, th.fg, th.match);
            const path_hits = q.len > 0 and !res.on_name and fuzzy.positions(q, p.fdisp, pos[0..q.len]);
            _ = w.SelectObject(dc, app.font_small);
            _ = drawRuns(dc, dp(pad) + name_col, ty + dp(1), app.width - dp(pad), p.disp, if (path_hits) pos[0..q.len] else &.{}, th.muted, th.match);
            _ = w.SelectObject(dc, app.font);
        }
    }
    if (app.results.items.len == 0) {
        _ = w.SetTextColor(dc, w.rgb(th.muted));
        const msg = if (app.idx == null or app.scanning.load(.acquire) and total == 0) L("Scanning for projects…") else L("No matching projects");
        _ = w.ExtTextOutW(dc, dp(pad + 6), dp(header_h + 12), 0, null, msg.ptr, @intCast(msg.len), null);
    }

    // footer
    _ = w.SelectObject(dc, app.font_small);
    _ = w.SetTextColor(dc, w.rgb(th.muted));
    const fy = app.height - dp(footer_h) + dp(6);
    var foot: [160]u16 = undefined;
    var fn_: usize = 0;
    for (L("enter  ")) |c| {
        foot[fn_] = c;
        fn_ += 1;
    }
    const ed = firstToken(app.cfg.editor);
    const edn = @min(ed.len, 40);
    @memcpy(foot[fn_ .. fn_ + edn], ed[0..edn]);
    fn_ += edn;
    for (L("     ctrl+e terminal     ctrl+o folder     ctrl+y copy path     esc")) |c| {
        foot[fn_] = c;
        fn_ += 1;
    }
    _ = w.ExtTextOutW(dc, dp(pad + 6), fy, 0, null, &foot, @intCast(fn_), null);
}

fn paint() void {
    const t0 = util.qpcMs();
    var ps: w.PAINTSTRUCT = .{};
    const dc = w.BeginPaint(app.hwnd, &ps);
    if (app.mem_dc != null) _ = w.BitBlt(dc, 0, 0, app.width, app.height, app.mem_dc, 0, 0, w.SRCCOPY);
    _ = w.EndPaint(app.hwnd, &ps);
    if (app.debug) app.paint_max_ms = @max(app.paint_max_ms, util.qpcMs() - t0);
}

fn redraw() void {
    render();
    _ = w.InvalidateRect(app.hwnd, null, 0);
}

fn ensureVisible() void {
    const rows: usize = @intCast(app.cfg.rows);
    if (app.sel < app.top) app.top = app.sel;
    if (app.sel >= app.top + rows) app.top = app.sel + 1 - rows;
}

fn move(delta: isize) void {
    const n = app.results.items.len;
    if (n == 0) return;
    const cur: isize = @intCast(app.sel);
    const next = std.math.clamp(cur + delta, 0, @as(isize, @intCast(n - 1)));
    app.sel = @intCast(next);
    ensureVisible();
    redraw();
}

// -- show / hide -------------------------------------------------------------------

fn applyDwm() void {
    // No show/hide animation: the window is fully drawn on the first frame,
    // and SetWindowPos doesn't block on the transition.
    const off: w.BOOL = 1;
    _ = w.DwmSetWindowAttribute(app.hwnd, w.DWMWA_TRANSITIONS_FORCEDISABLED, &off, 4);
    const corner: w.DWORD = w.DWMWCP_ROUND;
    _ = w.DwmSetWindowAttribute(app.hwnd, w.DWMWA_WINDOW_CORNER_PREFERENCE, &corner, 4);
    const border: w.DWORD = w.rgb(app.theme.accent);
    _ = w.DwmSetWindowAttribute(app.hwnd, w.DWMWA_BORDER_COLOR, &border, 4);
}

fn targetMonitor() w.HMONITOR {
    switch (app.cfg.monitor) {
        .cursor => {
            var pt: w.POINT = .{};
            _ = w.GetCursorPos(&pt);
            return w.MonitorFromPoint(pt, w.MONITOR_DEFAULTTONEAREST);
        },
        .active => return w.MonitorFromWindow(w.GetForegroundWindow(), w.MONITOR_DEFAULTTONEAREST),
        .primary => return w.MonitorFromPoint(.{}, w.MONITOR_DEFAULTTOPRIMARY),
    }
}

fn focusSelf() void {
    if (w.SetForegroundWindow(app.hwnd) != 0 and w.GetForegroundWindow() == app.hwnd) return;
    // Rare: the foreground lock refused us (e.g. summoned via CLI from a
    // background process). Synthesizing an input event makes this process the
    // last input source, which the lock accepts; VK 0xFF maps to no key.
    const inputs = [_]w.INPUT{ .{ .ki = .{ .wVk = 0xFF } }, .{ .ki = .{ .wVk = 0xFF, .dwFlags = w.KEYEVENTF_KEYUP } } };
    _ = w.SendInput(2, &inputs, @sizeOf(w.INPUT));
    const ok = w.SetForegroundWindow(app.hwnd) != 0;
    util.log("focus fallback used, ok={}", .{ok and w.GetForegroundWindow() == app.hwnd});
}

fn show() void {
    const t0 = util.qpcMs();
    if (w.IsWindowVisible(app.hwnd) != 0) {
        if (w.GetForegroundWindow() == app.hwnd) return hide(true);
        return focusSelf();
    }
    app.prev_fg = w.GetForegroundWindow();
    const tm = util.mtime(app.theme_path);
    if (tm != app.theme_mtime) {
        app.theme_mtime = tm;
        app.theme = loadTheme(app.theme_path);
        app.fonts_stale = true;
        applyDwm();
    }
    const mon = targetMonitor();
    var mi: w.MONITORINFO = .{};
    _ = w.GetMonitorInfoW(mon, &mi);
    var dx: w.UINT = 96;
    var dy: w.UINT = 96;
    if (w.GetDpiForMonitor(mon, w.MDT_EFFECTIVE_DPI, &dx, &dy) != 0) dx = 96;
    if (dx != app.dpi or app.font == null or app.fonts_stale) {
        app.dpi = dx;
        makeFonts();
    }
    layoutSize();
    app.qlen = 0;
    filter();
    render();
    const t1 = util.qpcMs();
    const wa = mi.rcWork;
    const x = wa.left + @divTrunc(wa.right - wa.left - app.width, 2);
    const y = wa.top + @divTrunc(wa.bottom - wa.top, 5);
    _ = w.SetWindowPos(app.hwnd, w.HWND_TOPMOST, x, y, app.width, app.height, w.SWP_SHOWWINDOW | w.SWP_NOACTIVATE);
    const t2 = util.qpcMs();
    focusSelf();
    if (app.debug) util.log("show: prepare {d:.2} ms, SetWindowPos {d:.2} ms, focus {d:.2} ms (dpi {d})", .{ t1 - t0, t2 - t1, util.qpcMs() - t2, app.dpi });
    if (w.GetTickCount64() - app.last_scan_tick > 120_000) startScan();
}

fn hide(restore_focus: bool) void {
    _ = w.ShowWindow(app.hwnd, w.SW_HIDE);
    if (app.debug and app.keys > 0) util.log("hide: {d} keys, handler avg {d:.3} ms, max {d:.3} ms, paint max {d:.3} ms", .{ app.keys, app.key_sum_ms / @as(f64, @floatFromInt(app.keys)), app.key_max_ms, app.paint_max_ms });
    app.paint_max_ms = 0;
    app.keys = 0;
    app.key_sum_ms = 0;
    app.key_max_ms = 0;
    if (restore_focus and app.prev_fg != null) _ = w.SetForegroundWindow(app.prev_fg);
    app.prev_fg = null;
}

// -- actions ------------------------------------------------------------------------

fn selected() ?index.Project {
    const idx = app.idx orelse return null;
    if (app.sel >= app.results.items.len) return null;
    return idx.items[app.results.items[app.sel].i];
}

fn firstToken(cmd: []const u16) []const u16 {
    var t = std.mem.trimStart(u16, cmd, &.{ ' ', '\t' });
    if (t.len > 0 and t[0] == '"') {
        const end = std.mem.indexOfScalarPos(u16, t, 1, '"') orelse t.len;
        return t[1..end];
    }
    const end = std.mem.indexOfAny(u16, t, &.{ ' ', '\t' }) orelse t.len;
    return t[0..end];
}

fn restAfterFirst(cmd: []const u16) []const u16 {
    var t = std.mem.trimStart(u16, cmd, &.{ ' ', '\t' });
    if (t.len > 0 and t[0] == '"') {
        const end = std.mem.indexOfScalarPos(u16, t, 1, '"') orelse return &.{};
        return std.mem.trimStart(u16, t[end + 1 ..], &.{ ' ', '\t' });
    }
    const end = std.mem.indexOfAny(u16, t, &.{ ' ', '\t' }) orelse return &.{};
    return std.mem.trimStart(u16, t[end..], &.{ ' ', '\t' });
}

/// Value of a variable inside an environment block (Name=Value\0...\0\0).
fn envBlockGet(block: [*]const u16, comptime name: []const u8) ?[]const u16 {
    var p = block;
    while (p[0] != 0) {
        const entry = std.mem.sliceTo(p, 0);
        if (entry.len > name.len and entry[name.len] == '=' and util.eqlIgnoreCase(entry[0..name.len], L(name)))
            return entry[name.len + 1 ..];
        p += entry.len + 1;
    }
    return null;
}

/// Resolves a program name like `code` against PATH (PATHEXT order).
fn resolveProgram(a: std.mem.Allocator, prog: []const u16, path_var: []const u16) ?[:0]u16 {
    const has_dir = std.mem.indexOfAny(u16, prog, &.{ '\\', '/', ':' }) != null;
    const exts = [_][]const u16{ L(""), L(".exe"), L(".cmd"), L(".bat"), L(".com") };
    if (has_dir) {
        for (exts) |e| {
            const cand = std.mem.concatWithSentinel(a, u16, &.{ prog, e }, 0) catch return null;
            if (util.exists(cand) and !util.isDir(cand)) return cand;
            a.free(cand);
        }
        return null;
    }
    var dirs = std.mem.splitScalar(u16, path_var, ';');
    while (dirs.next()) |d| {
        if (d.len == 0) continue;
        for (exts[1..]) |e| {
            const base = util.join(a, &.{ d, prog }) catch continue;
            defer a.free(base);
            const cand = std.mem.concatWithSentinel(a, u16, &.{ base, e }, 0) catch continue;
            if (util.exists(cand)) return cand;
            a.free(cand);
        }
    }
    return null;
}

/// `...\bin\code.cmd` -> `...\Code.exe`: skips cmd.exe and the node CLI shim.
fn siblingExe(a: std.mem.Allocator, script: []const u16) ?[:0]u16 {
    var end = script.len;
    while (end > 0 and script[end - 1] != '\\') end -= 1;
    if (end == 0) return null;
    const file = script[end..];
    const dot = std.mem.lastIndexOfScalar(u16, file, '.') orelse return null;
    const base = file[0..dot];
    var dir = script[0 .. end - 1];
    var level: usize = 0;
    while (level < 3) : (level += 1) {
        var cut = dir.len;
        while (cut > 0 and dir[cut - 1] != '\\') cut -= 1;
        if (cut == 0) return null;
        dir = dir[0 .. cut - 1];
        const cand = util.join(a, &.{ dir, base }) catch return null;
        defer a.free(cand);
        const exe = std.mem.concatWithSentinel(a, u16, &.{ cand, L(".exe") }, 0) catch return null;
        if (util.exists(exe)) return exe;
        a.free(exe);
    }
    return null;
}

fn launch(template: []const u16, project: [:0]const u16) bool {
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();

    // Expand {path}; append it when the template doesn't mention it.
    var cmd: std.ArrayList(u16) = .empty;
    var rest = template;
    var used = false;
    while (std.mem.indexOf(u16, rest, L("{path}"))) |at| {
        cmd.appendSlice(a, rest[0..at]) catch return false;
        cmd.appendSlice(a, project) catch return false;
        rest = rest[at + 6 ..];
        used = true;
    }
    cmd.appendSlice(a, rest) catch return false;
    if (!used) {
        cmd.appendSlice(a, L(" \"")) catch return false;
        cmd.appendSlice(a, project) catch return false;
        cmd.append(a, '"') catch return false;
    }

    // Fresh environment from the registry: picks up PATH changes made after logon.
    var env_block: ?*anyopaque = null;
    var token: w.HANDLE = null;
    if (w.OpenProcessToken(w.GetCurrentProcess(), w.TOKEN_QUERY | w.TOKEN_DUPLICATE, &token) != 0) {
        if (w.CreateEnvironmentBlock(&env_block, token, 0) == 0) env_block = null;
        _ = w.CloseHandle(token);
    }
    defer if (env_block) |e| {
        _ = w.DestroyEnvironmentBlock(e);
    };
    const path_var: []const u16 = if (env_block) |e|
        (envBlockGet(@ptrCast(@alignCast(e)), "Path") orelse &.{})
    else
        (util.env(a, "PATH") orelse &.{});

    const prog = firstToken(cmd.items);
    const args = restAfterFirst(cmd.items);
    var flags: w.DWORD = w.CREATE_NEW_PROCESS_GROUP | (if (env_block != null) w.CREATE_UNICODE_ENVIRONMENT else 0);
    var final: std.ArrayList(u16) = .empty;
    const resolved = resolveProgram(a, prog, path_var);
    if (resolved) |r| {
        if (util.endsWithIgnoreCase(r, L(".cmd")) or util.endsWithIgnoreCase(r, L(".bat"))) {
            if (siblingExe(a, r)) |exe| {
                final.appendSlice(a, L("\"")) catch return false;
                final.appendSlice(a, exe) catch return false;
                final.appendSlice(a, L("\" ")) catch return false;
                final.appendSlice(a, args) catch return false;
            } else {
                // cmd /s strips the outer quotes and keeps the inner ones intact
                final.appendSlice(a, L("cmd.exe /d /s /c \"\"")) catch return false;
                final.appendSlice(a, r) catch return false;
                final.appendSlice(a, L("\" ")) catch return false;
                final.appendSlice(a, args) catch return false;
                final.append(a, '"') catch return false;
                flags |= w.CREATE_NO_WINDOW;
            }
        } else {
            final.appendSlice(a, L("\"")) catch return false;
            final.appendSlice(a, r) catch return false;
            final.appendSlice(a, L("\" ")) catch return false;
            final.appendSlice(a, args) catch return false;
            flags |= w.CREATE_NEW_CONSOLE; // no-op for GUI programs; console tools get a window
        }
    } else {
        util.log("launch: '{f}' not found on PATH", .{std.unicode.fmtUtf16Le(prog)});
        return false;
    }
    final.append(a, 0) catch return false;
    const line: [*:0]u16 = @ptrCast(final.items.ptr);
    _ = w.AllowSetForegroundWindow(w.ASFW_ANY);
    var si: w.STARTUPINFOW = .{};
    var pi: w.PROCESS_INFORMATION = .{};
    if (w.CreateProcessW(null, line, null, null, 0, flags, env_block, project, &si, &pi) == 0) {
        util.log("launch failed ({d}): {f}", .{ w.GetLastError(), std.unicode.fmtUtf16Le(final.items[0 .. final.items.len - 1]) });
        return false;
    }
    _ = w.CloseHandle(pi.hThread);
    _ = w.CloseHandle(pi.hProcess);
    return true;
}

fn openWith(template: []const u16) void {
    const p = selected() orelse return;
    hide(false);
    const ok = launch(template, p.path);
    // Bookkeeping after the launch so file IO never delays the editor.
    const recent_path = util.dataFile("recent.txt");
    defer gpa.free(recent_path);
    app.recent.touch(p.path, recent_path);
    if (app.idx) |idx| app.recent.apply(idx);
    if (!ok) {
        _ = w.MessageBoxW(null, L("projpick could not start the command. See %LOCALAPPDATA%\\projpick\\projpick.log"), L("projpick"), w.MB_OK | w.MB_ICONWARNING | w.MB_SETFOREGROUND);
    }
}

fn openFolder() void {
    const p = selected() orelse return;
    hide(false);
    _ = w.AllowSetForegroundWindow(w.ASFW_ANY);
    _ = w.ShellExecuteW(null, L("open"), p.path, null, null, w.SW_SHOWNORMAL);
}

fn copyPath() void {
    const p = selected() orelse return;
    if (w.OpenClipboard(app.hwnd) == 0) return;
    defer _ = w.CloseClipboard();
    _ = w.EmptyClipboard();
    const bytes = (p.path.len + 1) * 2;
    const h = w.GlobalAlloc(w.GMEM_MOVEABLE, bytes);
    const mem: [*]u16 = @ptrCast(@alignCast(w.GlobalLock(h) orelse return));
    @memcpy(mem[0..p.path.len], p.path);
    mem[p.path.len] = 0;
    _ = w.GlobalUnlock(h);
    if (w.SetClipboardData(w.CF_UNICODETEXT, h) == null) _ = w.GlobalFree(h);
    hide(true);
}

fn pasteQuery() void {
    if (w.OpenClipboard(app.hwnd) == 0) return;
    defer _ = w.CloseClipboard();
    const h = w.GetClipboardData(w.CF_UNICODETEXT);
    const mem: [*:0]const u16 = @ptrCast(@alignCast(w.GlobalLock(h) orelse return));
    defer _ = w.GlobalUnlock(h);
    for (std.mem.sliceTo(mem, 0)) |c| {
        if (c == '\r' or c == '\n' or app.qlen >= app.query.len) break;
        if (c >= 0x20) {
            app.query[app.qlen] = c;
            app.qlen += 1;
        }
    }
}

// -- input --------------------------------------------------------------------------

fn ctrlDown() bool {
    return w.GetKeyState(w.VK_CONTROL) < 0;
}

fn deleteWord() void {
    while (app.qlen > 0 and app.query[app.qlen - 1] == ' ') app.qlen -= 1;
    while (app.qlen > 0 and app.query[app.qlen - 1] != ' ' and app.query[app.qlen - 1] != '\\' and app.query[app.qlen - 1] != '-') app.qlen -= 1;
}

fn onKey(vk: usize) bool {
    const ctrl = ctrlDown();
    const shift = w.GetKeyState(w.VK_SHIFT) < 0;
    const rows: isize = app.cfg.rows;
    if (ctrl) {
        switch (vk) {
            'N', 'J' => move(1),
            'P', 'K' => move(-1),
            'U' => {
                app.qlen = 0;
                filter();
                redraw();
            },
            'W', w.VK_BACK => {
                deleteWord();
                filter();
                redraw();
            },
            'E' => openWith(app.cfg.terminal),
            'O' => openFolder(),
            'Y', 'C' => copyPath(),
            'V' => {
                pasteQuery();
                filter();
                redraw();
            },
            'R' => {
                startScan();
                redraw();
            },
            w.VK_RETURN => openWith(app.cfg.terminal),
            else => return false,
        }
        return true;
    }
    switch (vk) {
        w.VK_ESCAPE => hide(true),
        w.VK_RETURN => openWith(app.cfg.editor),
        w.VK_DOWN => move(1),
        w.VK_UP => move(-1),
        w.VK_TAB => move(if (shift) -1 else 1),
        w.VK_NEXT => move(rows),
        w.VK_PRIOR => move(-rows),
        w.VK_HOME => move(-@as(isize, @intCast(app.results.items.len))),
        w.VK_END => move(@intCast(app.results.items.len)),
        w.VK_BACK => {
            if (app.qlen > 0) app.qlen -= 1;
            filter();
            redraw();
        },
        else => return false,
    }
    return true;
}

fn rowAt(lparam: w.LPARAM) ?usize {
    const lp: usize = @bitCast(lparam);
    const y: i32 = @as(i16, @bitCast(@as(u16, @truncate(lp >> 16))));
    const top = dp(header_h + 4);
    if (y < top) return null;
    const r: usize = @intCast(@divTrunc(y - top, dp(row_h)));
    if (r >= @as(usize, @intCast(app.cfg.rows))) return null;
    const i = app.top + r;
    return if (i < app.results.items.len) i else null;
}

// -- window procedure ------------------------------------------------------------------

fn registerHotkey() void {
    if (app.hotkey_ok) return;
    if (w.RegisterHotKey(app.hwnd, HOTKEY_ID, app.cfg.mods | w.MOD_NOREPEAT, app.cfg.vk) != 0) {
        app.hotkey_ok = true;
        _ = w.KillTimer(app.hwnd, TIMER_HOTKEY_RETRY);
        util.log("hotkey {f} registered", .{std.unicode.fmtUtf16Le(app.cfg.hotkey_text)});
        return;
    }
    const err = w.GetLastError();
    util.log("hotkey {f} unavailable (error {d}); retrying every 10 s", .{ std.unicode.fmtUtf16Le(app.cfg.hotkey_text), err });
    _ = w.SetTimer(app.hwnd, TIMER_HOTKEY_RETRY, 10_000, null);
    if (!app.hotkey_warned) {
        app.hotkey_warned = true;
        _ = w.CreateThread(null, 0, warnThread, null, 0, null);
    }
}

fn warnThread(_: ?*anyopaque) callconv(.winapi) w.DWORD {
    var buf: [400]u16 = undefined;
    var n: usize = 0;
    for ([_][]const u16{ L("The hotkey "), app.cfg.hotkey_text, L(" is already taken by another program, so projpick can't use it yet (it keeps retrying).\n\nTo pick another, edit hotkey= in %APPDATA%\\projpick\\config.ini and run `projpick --quit`, then `projpick`.") }) |part| {
        const m = @min(part.len, buf.len - 1 - n);
        @memcpy(buf[n .. n + m], part[0..m]);
        n += m;
    }
    buf[n] = 0;
    _ = w.MessageBoxW(null, buf[0..n :0], L("projpick"), w.MB_OK | w.MB_ICONWARNING | w.MB_SETFOREGROUND);
    return 0;
}

fn prewarm() void {
    // After logon the first PowerShell start pays for reading and scanning its
    // runtime. Do that once now, idle priority, so the first terminal doesn't.
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();
    const a = arena.allocator();
    const pf = util.env(a, "ProgramFiles") orelse return;
    const pwsh = util.join(a, &.{ pf, L("PowerShell\\7\\pwsh.exe") }) catch return;
    if (!util.exists(pwsh)) return;
    const cmd = std.mem.concatWithSentinel(a, u16, &.{ L("\""), pwsh, L("\" -NoLogo -NonInteractive -Command \"Import-Module PSReadLine; exit\"") }, 0) catch return;
    var si: w.STARTUPINFOW = .{};
    var pi: w.PROCESS_INFORMATION = .{};
    if (w.CreateProcessW(null, cmd, null, null, 0, w.CREATE_NO_WINDOW | w.IDLE_PRIORITY_CLASS, null, null, &si, &pi) != 0) {
        util.log("prewarm: started pwsh pid {d}", .{pi.dwProcessId});
        _ = w.CloseHandle(pi.hThread);
        _ = w.CloseHandle(pi.hProcess);
    }
}

fn wndProc(hwnd: w.HWND, msg: w.UINT, wp: w.WPARAM, lp: w.LPARAM) callconv(.winapi) w.LRESULT {
    switch (msg) {
        w.WM_HOTKEY => {
            if (wp == HOTKEY_ID) show();
            return 0;
        },
        WM_APP_SHOW => {
            show();
            return 0;
        },
        WM_APP_INDEX => {
            const idx: *index.Index = @ptrFromInt(@as(usize, @bitCast(lp)));
            app.scanning.store(false, .release);
            installIndex(idx);
            if (w.IsWindowVisible(hwnd) != 0) redraw();
            return 0;
        },
        WM_APP_QUIT, w.WM_CLOSE => {
            _ = w.DestroyWindow(hwnd);
            return 0;
        },
        w.WM_DESTROY => {
            w.PostQuitMessage(0);
            return 0;
        },
        w.WM_TIMER => {
            if (wp == TIMER_HOTKEY_RETRY) registerHotkey();
            if (wp == TIMER_PREWARM) {
                _ = w.KillTimer(hwnd, TIMER_PREWARM);
                prewarm();
            }
            return 0;
        },
        w.WM_ACTIVATE => {
            if ((wp & 0xFFFF) == w.WA_INACTIVE and w.IsWindowVisible(hwnd) != 0) hide(false);
            return 0;
        },
        w.WM_KEYDOWN, w.WM_SYSKEYDOWN => {
            if (onKey(wp)) return 0;
        },
        w.WM_CHAR => {
            const c: u16 = @truncate(wp);
            if (c >= 0x20 and c != 0x7F and app.qlen < app.query.len) {
                const t0 = util.qpcMs();
                app.query[app.qlen] = c;
                app.qlen += 1;
                filter();
                redraw();
                const dt = util.qpcMs() - t0;
                app.keys += 1;
                app.key_sum_ms += dt;
                app.key_max_ms = @max(app.key_max_ms, dt);
            }
            return 0;
        },
        w.WM_LBUTTONDOWN => {
            if (rowAt(lp)) |i| {
                app.sel = i;
                redraw();
            }
            return 0;
        },
        w.WM_LBUTTONDBLCLK => {
            if (rowAt(lp)) |i| {
                app.sel = i;
                openWith(app.cfg.editor);
            }
            return 0;
        },
        w.WM_MOUSEWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @truncate(wp >> 16)));
            move(if (delta > 0) -3 else 3);
            return 0;
        },
        w.WM_SETCURSOR => {
            _ = w.SetCursor(w.LoadCursorW(null, w.IDC_ARROW));
            return 1;
        },
        w.WM_DPICHANGED => {
            app.dpi = @truncate(wp & 0xFFFF);
            makeFonts();
            layoutSize();
            const r: *const w.RECT = @ptrFromInt(@as(usize, @bitCast(lp)));
            _ = w.SetWindowPos(hwnd, null, r.left, r.top, app.width, app.height, w.SWP_NOACTIVATE);
            redraw();
            return 0;
        },
        w.WM_ERASEBKGND => return 1,
        w.WM_PAINT => {
            paint();
            return 0;
        },
        else => {},
    }
    return w.DefWindowProcW(hwnd, msg, wp, lp);
}

// -- daemon ---------------------------------------------------------------------------

fn imeWanted() bool {
    const v = util.env(gpa, "PROJPICK_IME") orelse return false;
    return v.len > 0 and v[0] == '1';
}

fn runDaemon(show_now: bool, autostart: bool) u8 {
    const mutex = w.CreateMutexW(null, 0, mutex_name);
    if (mutex == null or w.GetLastError() == w.ERROR_ALREADY_EXISTS) {
        if (show_now) signalShow();
        return 0;
    }
    _ = w.SetProcessDpiAwarenessContext(w.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    // Keystrokes skip the IME/text-services round trip (measured ~10 ms per
    // key). Project names are typed as plain characters; must run before
    // the first window is created.
    if (!imeWanted()) _ = w.ImmDisableIME(0);
    app.autostart = autostart;
    if (util.env(gpa, "PROJPICK_DEBUG")) |v| app.debug = v.len > 0 and v[0] == '1';
    app.home = util.env(gpa, "USERPROFILE") orelse (util.dupZ(gpa, L("C:\\")) catch return 1);
    app.cfg = loadConfig();
    // Measured with 8 busy threads on 4 cores: summons stay under 5 ms p99 at
    // normal priority (Windows boosts the thread that receives the hotkey),
    // so high priority is opt-in only.
    if (app.cfg.high_priority) _ = w.SetPriorityClass(w.GetCurrentProcess(), w.HIGH_PRIORITY_CLASS);
    app.theme_path = util.dataFile("theme.ini");
    app.theme_mtime = util.mtime(app.theme_path);
    app.theme = loadTheme(app.theme_path);
    const recent_path = util.dataFile("recent.txt");
    app.recent.loadFrom(recent_path);
    gpa.free(recent_path);

    const inst = w.GetModuleHandleW(null);
    const wc = w.WNDCLASSEXW{ .style = w.CS_DBLCLKS, .lpfnWndProc = wndProc, .hInstance = inst, .hCursor = w.LoadCursorW(null, w.IDC_ARROW), .lpszClassName = class_name };
    if (w.RegisterClassExW(&wc) == 0) return 1;
    app.hwnd = w.CreateWindowExW(w.WS_EX_TOOLWINDOW | w.WS_EX_TOPMOST, class_name, L("projpick [] 0"), w.WS_POPUP, 0, 0, 720, 480, null, null, inst, null);
    if (app.hwnd == null) return 1;
    applyDwm();
    registerHotkey();

    // The persisted index makes the first summon instant; a rescan follows.
    const tsv = util.dataFile("projects.tsv");
    if (index.load(tsv, app.home)) |idx| installIndex(idx) else |_| {}
    gpa.free(tsv);
    _ = projectsRoot();
    startScan();
    if (autostart and app.cfg.prewarm) _ = w.SetTimer(app.hwnd, TIMER_PREWARM, 15_000, null);
    util.log("daemon {s} started (autostart={})", .{ version, autostart });
    if (show_now) show();

    var m: w.MSG = .{};
    while (w.GetMessageW(&m, null, 0, 0) > 0) {
        _ = w.TranslateMessage(&m);
        _ = w.DispatchMessageW(&m);
    }
    util.log("daemon exiting", .{});
    _ = w.CloseHandle(mutex);
    return 0;
}

fn daemonWindow() w.HWND {
    return w.FindWindowW(class_name, null);
}

fn signalShow() void {
    const h = daemonWindow();
    if (h == null) return;
    var pid: w.DWORD = 0;
    _ = w.GetWindowThreadProcessId(h, &pid);
    _ = w.AllowSetForegroundWindow(pid); // we hold foreground rights as the process the user just started
    _ = w.PostMessageW(h, WM_APP_SHOW, 0, 0);
}

fn quitDaemon() bool {
    const h = daemonWindow();
    if (h == null) return false;
    var pid: w.DWORD = 0;
    _ = w.GetWindowThreadProcessId(h, &pid);
    const proc = w.OpenProcess(w.SYNCHRONIZE, 0, pid);
    _ = w.PostMessageW(h, WM_APP_QUIT, 0, 0);
    if (proc != null) {
        _ = w.WaitForSingleObject(proc, 3000);
        _ = w.CloseHandle(proc);
    }
    return true;
}

// -- CLI ----------------------------------------------------------------------------

var out_handle: w.HANDLE = null;

fn out(comptime fmt: []const u8, args: anytype) void {
    if (out_handle == null) {
        out_handle = w.GetStdHandle(w.STD_OUTPUT_HANDLE);
        if (out_handle == null or out_handle == w.INVALID_HANDLE_VALUE) {
            _ = w.AttachConsole(w.ATTACH_PARENT_PROCESS);
            out_handle = w.GetStdHandle(w.STD_OUTPUT_HANDLE);
        }
    }
    var buf: [4096]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, fmt, args) catch return;
    var wr: w.DWORD = 0;
    _ = w.WriteFile(out_handle, text.ptr, @intCast(text.len), &wr, null);
}

fn selfPath(a: std.mem.Allocator) ![:0]u16 {
    var buf: [32768]u16 = undefined;
    const n = w.GetModuleFileNameW(null, &buf, buf.len);
    if (n == 0) return error.Unexpected;
    return util.dupZ(a, buf[0..n]);
}

fn startDetached(exe: [:0]const u16, args: []const u16) bool {
    const cmd = std.mem.concatWithSentinel(gpa, u16, &.{ L("\""), exe, L("\" "), args }, 0) catch return false;
    defer gpa.free(cmd);
    var si: w.STARTUPINFOW = .{};
    var pi: w.PROCESS_INFORMATION = .{};
    if (w.CreateProcessW(null, cmd, null, null, 0, w.DETACHED_PROCESS | w.CREATE_NEW_PROCESS_GROUP, null, null, &si, &pi) == 0) return false;
    _ = w.CloseHandle(pi.hThread);
    _ = w.CloseHandle(pi.hProcess);
    return true;
}

const run_key = L("Software\\Microsoft\\Windows\\CurrentVersion\\Run");

fn install() u8 {
    // Registers this exe (bin\projpick.exe, built by profile-setup) to start at
    // logon and starts it. bin\ is not tracked by git, so a pull never
    // collides with the running daemon; setup stops it before rebuilding.
    const me = selfPath(gpa) catch return 1;
    var key: w.HKEY = null;
    if (w.RegOpenKeyExW(w.HKEY_CURRENT_USER, run_key, 0, w.KEY_SET_VALUE, &key) == 0) {
        const val = std.mem.concatWithSentinel(gpa, u16, &.{ L("\""), me, L("\" --daemon --autostart") }, 0) catch return 1;
        const bytes = std.mem.sliceAsBytes(val[0 .. val.len + 1]);
        _ = w.RegSetValueExW(key, L("projpick"), 0, w.REG_SZ, bytes.ptr, @intCast(bytes.len));
        _ = w.RegCloseKey(key);
    }
    if (daemonWindow() == null) _ = startDetached(me, L("--daemon"));
    out("projpick {s} installed: {f} (starts at logon)\n", .{ version, std.unicode.fmtUtf16Le(me) });
    return 0;
}

fn uninstall() u8 {
    _ = quitDaemon();
    var key: w.HKEY = null;
    if (w.RegOpenKeyExW(w.HKEY_CURRENT_USER, run_key, 0, w.KEY_SET_VALUE, &key) == 0) {
        _ = w.RegDeleteValueW(key, L("projpick"));
        _ = w.RegCloseKey(key);
    }
    out("projpick: removed from logon and stopped\n", .{});
    return 0;
}

fn scanCli(print: bool) u8 {
    const home = util.env(gpa, "USERPROFILE") orelse return 1;
    app.home = home;
    app.cfg = loadConfig();
    const idx = index.scan(.{ .home = home, .projects_root = projectsRoot(), .extra_roots = app.cfg.extra_roots }) catch return 1;
    const path = util.dataFile("projects.tsv");
    index.save(idx, path) catch {};
    if (print) {
        for (idx.items) |p| out("{f}\t{f}\n", .{ std.unicode.fmtUtf16Le(p.name), std.unicode.fmtUtf16Le(p.path) });
    } else {
        out("{d} projects ({d} directories) in {d:.1} ms -> {f}\n", .{ idx.items.len, idx.dirs_visited, idx.scan_ms, std.unicode.fmtUtf16Le(path) });
    }
    return 0;
}

fn listCli() u8 {
    const path = util.dataFile("projects.tsv");
    const data = util.readFile(gpa, path, 64 << 20) catch return scanCli(true);
    var wr: w.DWORD = 0;
    out("", .{});
    _ = w.WriteFile(out_handle, data.ptr, @intCast(data.len), &wr, null);
    return 0;
}

fn realMain() u8 {
    var argc: i32 = 0;
    const argv = w.CommandLineToArgvW(w.GetCommandLineW(), &argc) orelse return 1;
    var opt_daemon = false;
    var opt_auto = false;
    var i: usize = 1;
    while (i < @as(usize, @intCast(argc))) : (i += 1) {
        const a = std.mem.sliceTo(argv[i], 0);
        if (util.eqlIgnoreCase(a, L("--daemon"))) {
            opt_daemon = true;
        } else if (util.eqlIgnoreCase(a, L("--autostart"))) {
            opt_auto = true;
        } else if (util.eqlIgnoreCase(a, L("--install"))) {
            return install();
        } else if (util.eqlIgnoreCase(a, L("--uninstall"))) {
            return uninstall();
        } else if (util.eqlIgnoreCase(a, L("--quit"))) {
            return if (quitDaemon()) 0 else 1;
        } else if (util.eqlIgnoreCase(a, L("--scan"))) {
            return scanCli(false);
        } else if (util.eqlIgnoreCase(a, L("--list"))) {
            return listCli();
        } else if (util.eqlIgnoreCase(a, L("--version"))) {
            out("projpick {s}\n", .{version});
            return 0;
        } else if (util.eqlIgnoreCase(a, L("--show"))) {
            // default
        } else {
            out("usage: projpick [--show|--daemon|--install|--uninstall|--quit|--scan|--list|--version]\n", .{});
            return 2;
        }
    }
    if (opt_daemon) return runDaemon(false, opt_auto);
    if (daemonWindow() != null) {
        signalShow();
        return 0;
    }
    return runDaemon(true, false);
}

pub fn main() void {
    w.ExitProcess(realMain());
}

test {
    _ = fuzzy;
}
