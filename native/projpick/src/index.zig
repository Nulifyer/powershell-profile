//! Project discovery and the on-disk index.
//!
//! Discovery rules (Karchy's Windows rules plus the fish `z` convention):
//!   - every child of the projects root (%Z_PROJECTS_ROOT% or ~\Projects) is a
//!     project, unless it is only a container of other projects;
//!   - anywhere under the home directory, a directory holding a marker
//!     (.git, .vscode, package.json, *.sln, ...) is a project and is not
//!     descended into;
//!   - dot-directories, build/dependency folders, reparse points (junctions,
//!     symlinks) and cloud placeholders are never entered, so a scan can't
//!     loop, wander off-volume, or trigger OneDrive downloads.
//!
//! The index is written to %LOCALAPPDATA%\projpick\projects.tsv as
//! "name<TAB>path" lines (UTF-8). The PowerShell profile reads the same file.

const std = @import("std");
const w = @import("win32.zig");
const util = @import("util.zig");

const gpa = util.gpa;

pub const Project = struct {
    name: []const u16,
    path: [:0]const u16,
    disp: []const u16,
    fname: []const u16,
    fdisp: []const u16,
    recent: u32 = 0,
};

pub const Index = struct {
    arena: std.heap.ArenaAllocator,
    items: []Project,
    scan_ms: f64 = 0,
    dirs_visited: usize = 0,

    pub fn destroy(self: *Index) void {
        self.arena.deinit();
        gpa.destroy(self);
    }
};

const markers = [_][]const u8{
    ".git",            ".hg",          ".svn",         ".jj",          ".vscode",        ".idea",         ".devcontainer",
    "go.mod",          "Cargo.toml",   "package.json", "deno.json",    "pyproject.toml", "composer.json", "Gemfile",
    "mix.exs",         "pubspec.yaml", "pom.xml",      "build.gradle", "CMakeLists.txt", "flake.nix",     "build.zig",
    "ProjectSettings",
};
const skip_dirs = [_][]const u8{
    "node_modules", "__pycache__", "venv", "target",       "bin",     "obj",          "packages",                  "vendor", "dist", "build",
    "Library",      "Temp",        "Logs", "PackageCache", "AppData", "$RECYCLE.BIN", "System Volume Information",
};
const skip_root_dirs = [_][]const u8{
    "go",           "Music",    "Videos",     "Pictures", "Downloads",  "Desktop",    "Favorites",        "Contacts", "Links",
    "Saved Games",  "Searches", "3D Objects", "scoop",    "miniconda3", "anaconda3",  "Application Data", "Cookies",  "Local Settings",
    "My Documents", "NetHood",  "PrintHood",  "Recent",   "SendTo",     "Start Menu", "Templates",
};

fn inList(name: []const u16, comptime list: []const []const u8) bool {
    inline for (list) |item| {
        if (util.eqlIgnoreCase(name, w.L(item))) return true;
    }
    return false;
}

fn isMarker(name: []const u16) bool {
    return inList(name, &markers) or util.endsWithIgnoreCase(name, w.L(".sln"));
}

/// Lowercases with the invariant locale; falls back to ASCII folding.
pub fn fold(a: std.mem.Allocator, s: []const u16) ![]u16 {
    const out = try a.alloc(u16, s.len);
    if (s.len == 0) return out;
    const LCMAP_LOWERCASE = 0x00000100;
    const n = w.LCMapStringEx(w.L(""), LCMAP_LOWERCASE, s.ptr, @intCast(s.len), out.ptr, @intCast(out.len), null, null, 0);
    if (n != s.len) @import("fuzzy.zig").foldAscii(out, s);
    return out;
}

const Entry = struct { name: []const u16, attrs: u32 };

/// Lists `dir` once. Returns true if a marker was seen; child directories are
/// appended to `children` (names, allocated in `a`) only when no marker is found.
fn listDir(a: std.mem.Allocator, dir: []const u16, check_markers: bool, children: *std.ArrayList(Entry)) bool {
    const unc = dir.len >= 2 and dir[0] == '\\' and dir[1] == '\\';
    const pattern = (if (unc)
        util.join(a, &.{ dir, w.L("*") })
    else
        util.join(a, &.{ w.L("\\\\?\\"), dir, w.L("*") })) catch return false;
    defer a.free(pattern);
    var fd: w.WIN32_FIND_DATAW = undefined;
    const h = w.FindFirstFileExW(pattern, w.FindExInfoBasic, &fd, w.FindExSearchNameMatch, null, w.FIND_FIRST_EX_LARGE_FETCH);
    if (h == w.INVALID_HANDLE_VALUE) return false;
    defer _ = w.FindClose(h);
    const start = children.items.len;
    while (true) {
        const name = std.mem.sliceTo(&fd.cFileName, 0);
        const dots = (name.len == 1 and name[0] == '.') or (name.len == 2 and name[0] == '.' and name[1] == '.');
        if (!dots) {
            if (check_markers and isMarker(name)) {
                for (children.items[start..]) |c| a.free(c.name);
                children.shrinkRetainingCapacity(start);
                return true;
            }
            if ((fd.dwFileAttributes & w.FILE_ATTRIBUTE_DIRECTORY) != 0) {
                if (a.dupe(u16, name)) |copy| {
                    children.append(a, .{ .name = copy, .attrs = fd.dwFileAttributes }) catch a.free(copy);
                } else |_| {}
            }
        }
        if (w.FindNextFileW(h, &fd) == 0) break;
    }
    return false;
}

const Scanner = struct {
    arena: std.mem.Allocator, // results
    tmp: std.mem.Allocator, // scratch
    home: []const u16,
    projects_root: []const u16,
    max_depth: u32,
    seen: std.StringHashMapUnmanaged(void) = .empty,
    found: std.ArrayList(Project) = .empty,
    visited: usize = 0,

    fn add(self: *Scanner, path: []const u16) void {
        const folded = fold(self.arena, path) catch return;
        const key = std.mem.sliceAsBytes(folded);
        if (self.seen.contains(key)) return;
        self.seen.put(self.tmp, key, {}) catch return;
        const p = makeProject(self.arena, self.home, path, folded) catch return;
        self.found.append(self.tmp, p) catch return;
    }

    fn skipChild(self: *Scanner, e: Entry, depth: u32, full: []const u16) bool {
        const bad_attrs = w.FILE_ATTRIBUTE_REPARSE_POINT | w.FILE_ATTRIBUTE_OFFLINE |
            w.FILE_ATTRIBUTE_RECALL_ON_OPEN | w.FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS;
        if ((e.attrs & bad_attrs) != 0) return true;
        if (e.name.len > 0 and e.name[0] == '.') return true;
        if (inList(e.name, &skip_dirs)) return true;
        if (depth == 0 and (inList(e.name, &skip_root_dirs) or util.startsWithIgnoreCase(e.name, w.L("OneDrive")))) return true;
        if (util.eqlIgnoreCase(full, self.projects_root)) return true;
        return false;
    }

    /// Depth-first walk from `start`; returns the number of projects added.
    fn walk(self: *Scanner, start: []const u16, start_depth: u32) usize {
        const before = self.found.items.len;
        const Item = struct { path: [:0]u16, depth: u32 };
        var stack: std.ArrayList(Item) = .empty;
        defer stack.deinit(self.tmp);
        const first = util.dupZ(self.tmp, start) catch return 0;
        stack.append(self.tmp, .{ .path = first, .depth = start_depth }) catch return 0;
        var children: std.ArrayList(Entry) = .empty;
        defer children.deinit(self.tmp);
        while (stack.pop()) |it| {
            defer self.tmp.free(it.path);
            self.visited += 1;
            if (self.visited > 300_000) continue;
            children.clearRetainingCapacity();
            const is_project = listDir(self.tmp, it.path, it.depth > 0, &children);
            if (is_project) {
                self.add(it.path);
                continue;
            }
            for (children.items) |c| {
                defer self.tmp.free(c.name);
                if (it.depth + 1 > self.max_depth) continue;
                const full = util.join(self.tmp, &.{ it.path, c.name }) catch continue;
                if (self.skipChild(c, it.depth, full)) {
                    self.tmp.free(full);
                    continue;
                }
                stack.append(self.tmp, .{ .path = full, .depth = it.depth + 1 }) catch self.tmp.free(full);
            }
        }
        return self.found.items.len - before;
    }
};

fn makeProject(a: std.mem.Allocator, home: []const u16, path: []const u16, folded_path: ?[]const u16) !Project {
    const p = try util.dupZ(a, path);
    var name_start: usize = p.len;
    while (name_start > 0 and p[name_start - 1] != '\\') name_start -= 1;
    const name = p[name_start..];
    const disp = if (home.len > 0 and util.startsWithIgnoreCase(p, home) and (p.len == home.len or p[home.len] == '\\')) blk: {
        const d = try a.alloc(u16, p.len - home.len + 1);
        d[0] = '~';
        @memcpy(d[1..], p[home.len..]);
        break :blk d;
    } else p;
    _ = folded_path;
    return .{ .name = name, .path = p, .disp = disp, .fname = try fold(a, name), .fdisp = try fold(a, disp) };
}

fn lessThan(_: void, x: Project, y: Project) bool {
    const o = std.mem.order(u16, x.fname, y.fname);
    if (o != .eq) return o == .lt;
    return std.mem.order(u16, x.fdisp, y.fdisp) == .lt;
}

pub const ScanOptions = struct {
    home: []const u16,
    projects_root: []const u16,
    extra_roots: []const []const u16 = &.{},
    max_depth: u32 = 10,
};

pub fn scan(opts: ScanOptions) !*Index {
    const t0 = util.qpcMs();
    const idx = try gpa.create(Index);
    idx.* = .{ .arena = std.heap.ArenaAllocator.init(gpa), .items = &.{} };
    errdefer idx.destroy();
    var tmp_arena = std.heap.ArenaAllocator.init(gpa);
    defer tmp_arena.deinit();
    var s = Scanner{
        .arena = idx.arena.allocator(),
        .tmp = tmp_arena.allocator(),
        .home = opts.home,
        .projects_root = opts.projects_root,
        .max_depth = opts.max_depth,
    };

    // Projects root: each child is a project unless it only contains projects.
    const root_z = try util.dupZ(s.tmp, opts.projects_root);
    if (util.isDir(root_z)) {
        var children: std.ArrayList(Entry) = .empty;
        _ = listDir(s.tmp, opts.projects_root, false, &children);
        for (children.items) |c| {
            if (c.name.len > 0 and c.name[0] == '.') continue;
            const full = util.join(s.tmp, &.{ opts.projects_root, c.name }) catch continue;
            if ((c.attrs & w.FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
                s.add(full); // a deliberate link into ~\Projects
                continue;
            }
            if (s.walk(full, 1) == 0) s.add(full);
        }
    }
    _ = s.walk(opts.home, 0);
    for (opts.extra_roots) |r| _ = s.walk(r, 0);

    std.mem.sort(Project, s.found.items, {}, lessThan);
    idx.items = try idx.arena.allocator().dupe(Project, s.found.items);
    idx.scan_ms = util.qpcMs() - t0;
    idx.dirs_visited = s.visited;
    return idx;
}

pub fn save(idx: *const Index, path: [:0]const u16) !void {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);
    for (idx.items) |p| {
        const n = try util.toUtf8(gpa, p.name);
        defer gpa.free(n);
        const q = try util.toUtf8(gpa, p.path);
        defer gpa.free(q);
        try buf.appendSlice(gpa, n);
        try buf.append(gpa, '\t');
        try buf.appendSlice(gpa, q);
        try buf.append(gpa, '\n');
    }
    try util.writeFileAtomic(gpa, path, buf.items);
}

pub fn load(path: [:0]const u16, home: []const u16) !*Index {
    const data = try util.readFile(gpa, path, 64 << 20);
    defer gpa.free(data);
    const idx = try gpa.create(Index);
    idx.* = .{ .arena = std.heap.ArenaAllocator.init(gpa), .items = &.{} };
    errdefer idx.destroy();
    const a = idx.arena.allocator();
    var list: std.ArrayList(Project) = .empty;
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        const tab = std.mem.indexOfScalar(u8, line, '\t') orelse continue;
        const p16 = util.toUtf16(a, line[tab + 1 ..]) catch continue;
        try list.append(a, try makeProject(a, home, p16, null));
    }
    idx.items = list.items;
    return idx;
}

/// Recently opened project paths, most recent first.
pub const Recent = struct {
    const cap = 64;
    paths: std.ArrayList([:0]u16) = .empty,

    pub fn loadFrom(self: *Recent, path: [:0]const u16) void {
        const data = util.readFile(gpa, path, 1 << 20) catch return;
        defer gpa.free(data);
        var lines = std.mem.splitScalar(u8, data, '\n');
        while (lines.next()) |raw| {
            const line = std.mem.trimEnd(u8, raw, "\r");
            if (line.len == 0) continue;
            const p = util.toUtf16(gpa, line) catch continue;
            self.paths.append(gpa, p) catch return;
            if (self.paths.items.len >= cap) break;
        }
    }

    pub fn touch(self: *Recent, project: []const u16, file: [:0]const u16) void {
        var i: usize = 0;
        while (i < self.paths.items.len) {
            if (util.eqlIgnoreCase(self.paths.items[i], project)) {
                gpa.free(self.paths.orderedRemove(i));
            } else i += 1;
        }
        const copy = util.dupZ(gpa, project) catch return;
        self.paths.insert(gpa, 0, copy) catch return gpa.free(copy);
        if (self.paths.items.len > cap) gpa.free(self.paths.pop().?);
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(gpa);
        for (self.paths.items) |p| {
            const s = util.toUtf8(gpa, p) catch continue;
            defer gpa.free(s);
            buf.appendSlice(gpa, s) catch return;
            buf.append(gpa, '\n') catch return;
        }
        util.writeFileAtomic(gpa, file, buf.items) catch {};
    }

    pub fn apply(self: *const Recent, idx: *Index) void {
        for (idx.items) |*p| {
            p.recent = 0;
            for (self.paths.items, 0..) |r, rank| {
                if (util.eqlIgnoreCase(r, p.path)) {
                    p.recent = @intCast(cap - rank);
                    break;
                }
            }
        }
    }
};
