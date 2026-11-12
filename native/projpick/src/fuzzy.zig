//! fzf-style subsequence matching over case-folded UTF-16.
//!
//! The match window is found greedily forwards, then tightened backwards
//! (fzf "v1"), so `score` and `positions` agree on which characters matched.
//! Scores reward matches at word boundaries, consecutive runs and the start
//! of the text, and penalize gaps. Both inputs must already be folded (see
//! `foldAscii`, or LCMapStringEx on Windows for full Unicode folding).

const std = @import("std");

const score_match = 16;
const bonus_boundary = 10;
const bonus_first = 8;
const bonus_consecutive = 5;
const penalty_gap_start = 3;
const penalty_gap = 1;

fn isSep(c: u16) bool {
    return switch (c) {
        ' ', '-', '_', '.', '/', '\\', ':', '@', '+' => true,
        else => false,
    };
}

/// Finds the tightest window [start, end] containing pattern as a subsequence.
fn window(pattern: []const u16, text: []const u16) ?struct { start: usize, end: usize } {
    if (pattern.len == 0 or pattern.len > text.len) return null;
    var pi: usize = 0;
    var end: usize = 0;
    for (text, 0..) |c, i| {
        if (c == pattern[pi]) {
            pi += 1;
            if (pi == pattern.len) {
                end = i;
                break;
            }
        }
    } else return null;
    var start = end;
    var k: usize = pattern.len;
    var i: usize = end + 1;
    while (i > 0) {
        i -= 1;
        if (text[i] == pattern[k - 1]) {
            k -= 1;
            if (k == 0) {
                start = i;
                break;
            }
        }
    }
    return .{ .start = start, .end = end };
}

/// Returns null when pattern is not a subsequence of text.
/// `orig` is the unfolded text (used for camelCase boundaries); same length as text.
pub fn score(pattern: []const u16, text: []const u16, orig: []const u16) ?i32 {
    const w = window(pattern, text) orelse return null;
    var s: i32 = 0;
    var pi: usize = 0;
    var prev_matched = false;
    var in_gap = false;
    // Like fzf, a consecutive run keeps the boundary bonus of its first
    // character, so "api" in "api-1" beats "a-p-i" scattered over boundaries.
    var run_bonus: i32 = 0;
    var i = w.start;
    while (i <= w.end) : (i += 1) {
        if (pi < pattern.len and text[i] == pattern[pi]) {
            var b: i32 = 0;
            if (i == 0) {
                b = bonus_boundary + bonus_first;
            } else if (isSep(text[i - 1])) {
                b = bonus_boundary;
            } else if (orig[i] >= 'A' and orig[i] <= 'Z' and orig[i - 1] >= 'a' and orig[i - 1] <= 'z') {
                b = bonus_boundary - 2;
            }
            if (prev_matched) {
                b = @max(b, @max(run_bonus, bonus_consecutive));
            } else {
                run_bonus = b;
            }
            s += score_match + b;
            pi += 1;
            prev_matched = true;
            in_gap = false;
        } else {
            s -= if (in_gap) penalty_gap else penalty_gap_start;
            in_gap = true;
            prev_matched = false;
        }
    }
    // Prefer matches close to the start, and shorter texts.
    s -= @intCast(@min(w.start, 15));
    s -= @intCast(@min(text.len / 8, 8));
    return s;
}

/// Writes the matched indices into `out` (must hold pattern.len entries).
pub fn positions(pattern: []const u16, text: []const u16, out: []usize) bool {
    const w = window(pattern, text) orelse return false;
    var pi: usize = 0;
    var i = w.start;
    while (i <= w.end and pi < pattern.len) : (i += 1) {
        if (text[i] == pattern[pi]) {
            out[pi] = i;
            pi += 1;
        }
    }
    return pi == pattern.len;
}

pub fn foldAscii(dst: []u16, src: []const u16) void {
    for (src, 0..) |c, i| dst[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
}

// -- tests --------------------------------------------------------------------

fn u(comptime s: []const u8) []const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(s);
}

fn sc(comptime p: []const u8, comptime t: []const u8) ?i32 {
    var folded: [256]u16 = undefined;
    const tt = u(t);
    foldAscii(folded[0..tt.len], tt);
    var pf: [64]u16 = undefined;
    const pp = u(p);
    foldAscii(pf[0..pp.len], pp);
    return score(pf[0..pp.len], folded[0..tt.len], tt);
}

test "non-matches return null" {
    try std.testing.expect(sc("xyz", "powershell-profile") == null);
    try std.testing.expect(sc("ab", "a") == null);
    try std.testing.expect(sc("", "abc") == null);
}

test "case-insensitive subsequence" {
    try std.testing.expect(sc("PP", "powershell-profile") != null);
    try std.testing.expect(sc("fp", "FilePilot") != null);
}

test "prefix and boundary matches rank higher" {
    // "api" exact prefix beats a scattered match
    try std.testing.expect(sc("api", "api-1").? > sc("api", "a-p-i-legacy").?);
    // word boundary beats mid-word
    try std.testing.expect(sc("pro", "my-profile").? > sc("pro", "unprovable").?);
    // camelCase boundary counts
    try std.testing.expect(sc("fp", "FilePilot").? > sc("fp", "flipper").?);
    // consecutive beats gapped
    try std.testing.expect(sc("sql", "sqlgo").? > sc("sql", "s-q-l").?);
}

test "positions agree with the tight window" {
    var out: [3]usize = undefined;
    var t: [32]u16 = undefined;
    const src = u("xx-api-api");
    foldAscii(t[0..src.len], src);
    try std.testing.expect(positions(u("api"), t[0..src.len], &out));
    // greedy-forward finds the first full match, backward pass keeps it tight
    try std.testing.expectEqual(@as(usize, 3), out[0]);
    try std.testing.expectEqual(@as(usize, 5), out[2]);
}
