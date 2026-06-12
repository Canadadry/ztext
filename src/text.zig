const std = @import("std");

pub const AlignKind = enum { begin, middle, end };
const Rect = struct { x: u32, y: u32, width: u32, height: u32 };

pub fn Font(comptime T: type, comptime default_painter: T, comptime F: type, comptime default_familly: F) type {
    return struct {
        size: u32,
        spacing: u32 = 0,
        line_spacing: u32 = 0,
        @"align": struct {
            x: AlignKind = .begin,
            y: AlignKind = .begin,
        },
        familly: F = default_familly,
        painter: T = default_painter,
        pub fn measureText(font: *const @This(), txt: ?[]const u8, width: u32) struct { x: u32, y: u32 } {
            const text = txt orelse return .{ .x = 0, .y = 0 };
            if (text.len == 0) return .{ .x = 0, .y = 0 };

            var out_x: u32 = 0;
            var out_y: u32 = 0;
            var remaining: []const u8 = text;
            var first = true;

            for (0..1024) |_| {
                const line = font.getNextLine(remaining, width);
                if (out_x < line.size_x) out_x = line.size_x;
                if (!first) out_y += font.line_spacing;
                out_y += line.size_y;
                first = false;
                if (line.end_at < 0) break;
                const consumed: usize = @intCast(line.end_at);
                if (consumed + 1 >= remaining.len) break;
                remaining = remaining[consumed + 1 ..];
            }

            return .{ .x = out_x, .y = out_y };
        }

        fn getNextLine(font: *const @This(), txt: []const u8, width: u32) struct { end_at: i64, size_x: u32, size_y: u32 } {
            if (txt.len == 0) return .{ .end_at = -1, .size_x = 0, .size_y = 0 };

            var line_x: u32 = 0;
            var line_y: u32 = 0;
            var line_end: i64 = -1;

            var word_x: u32 = 0;
            var word_y: u32 = 0;
            var word_end: i64 = -1;

            var last_space_size: u32 = 0;

            var iter = std.unicode.Utf8Iterator{ .bytes = txt, .i = 0 };
            while (iter.nextCodepointSlice()) |slice| {
                const cp = std.unicode.utf8Decode(slice) catch continue;
                const byte_index: i64 = @intCast(iter.i - slice.len);

                const rw = font.painter.measure_rune(cp, font.size, font.familly);
                const rh = font.size;

                if (width > 0 and line_x > 0 and line_x + word_x + rw > width) {
                    const result_x = if (line_x >= last_space_size + 2 * font.spacing)
                        line_x - last_space_size - 2 * font.spacing
                    else
                        0;
                    return .{ .end_at = line_end, .size_x = result_x, .size_y = line_y };
                }

                word_end = byte_index;
                word_x += rw + font.spacing;
                if (rh > word_y) word_y = rh;

                if (cp == ' ' or cp == '\n') {
                    last_space_size = rw;
                    line_end = word_end;
                    line_x += word_x;
                    if (word_y > line_y) line_y = word_y;
                    word_x = 0;
                    word_y = 0;

                    if (cp == '\n') {
                        const result_x = if (line_x >= last_space_size + 2 * font.spacing)
                            line_x - last_space_size - 2 * font.spacing
                        else
                            0;
                        return .{ .end_at = line_end, .size_x = result_x, .size_y = line_y };
                    }
                }
            }

            if (word_end > line_end) line_end = word_end;
            if (word_x > 0) line_x += word_x;
            if (word_y > line_y) line_y = word_y;

            return .{ .end_at = -1, .size_x = line_x, .size_y = line_y };
        }

        fn computeAlign(a: AlignKind, content: u32, container: u32) u32 {
            if (container <= content) return 0;
            const remaining = container - content;
            return switch (a) {
                .begin => 0,
                .middle => remaining / 2,
                .end => remaining,
            };
        }

        fn draw(font: *const @This(), txt: []const u8, rect: Rect) void {
            const dim = font.measureText(txt, rect.width);

            var y: u32 = rect.y + computeAlign(font.@"align".y, dim.y, rect.height);
            var remaining: []const u8 = txt;

            for (0..1024) |iter_i| {
                const line = font.getNextLine(remaining, rect.width);
                std.debug.print("[draw iter={d}] end_at={d} size_x={d} size_y={d} y={d} remaining={s}\n", .{
                    iter_i, line.end_at, line.size_x, line.size_y, y, remaining,
                });
                var x: u32 = rect.x + computeAlign(font.@"align".x, line.size_x, rect.width);

                const slice = if (line.end_at >= 0) remaining[0 .. @as(usize, @intCast(line.end_at)) + 1] else remaining;
                var iter = std.unicode.Utf8Iterator{ .bytes = slice, .i = 0 };
                while (iter.nextCodepointSlice()) |cp_slice| {
                    const cp = std.unicode.utf8Decode(cp_slice) catch continue;
                    if (cp == '\n') break;

                    var mut_painter = font.painter;
                    mut_painter.draw_rune(x, y, cp);
                    const rw = font.painter.measure_rune(cp, font.size, font.familly);
                    x += rw + font.spacing;
                }

                y += line.size_y;

                if (line.end_at < 0) break;
                const consumed: usize = @intCast(line.end_at);
                if (consumed + 1 >= remaining.len) break;
                remaining = remaining[consumed + 1 ..];
                y += font.line_spacing;
            }
        }
    };
}

test "measure text" {
    const Painter = struct {
        pub fn measure_rune(painter: *const @This(), rune: u32, size: u32, familly: u32) u32 {
            _ = painter;
            _ = rune;
            _ = familly;
            return size / 2;
        }
    };
    const TestCase = struct {
        name: []const u8,
        input: struct {
            txt: ?[]const u8,
            width: u32,
            font: Font(Painter, .{}, u32, 0),
        },
        expected: struct {
            x: u32,
            y: u32,
        },
    };
    var diagnostics = std.json.Diagnostics{};
    var reader: std.Io.Reader = .fixed(@embedFile("measure-text-testscase.json"));
    var json_reader = std.json.Reader.init(std.testing.allocator, &reader);
    defer json_reader.deinit();
    json_reader.enableDiagnostics(&diagnostics);

    const tests = std.json.parseFromTokenSource([]TestCase, std.testing.allocator, &json_reader, .{}) catch |err| {
        std.debug.print("{d}:{d} : {}\n", .{ diagnostics.getLine(), diagnostics.getColumn(), err });
        return err;
    };
    defer tests.deinit();

    var any_failed = false;
    for (tests.value) |tt| {
        const got = tt.input.font.measureText(tt.input.txt, tt.input.width);
        if (got.x != tt.expected.x) {
            std.debug.print("FAIL [{s}]: x expected={d} got={d}\n", .{ tt.name, tt.expected.x, got.x });
            any_failed = true;
        }
        if (got.y != tt.expected.y) {
            std.debug.print("FAIL [{s}]: y expected={d} got={d}\n", .{ tt.name, tt.expected.y, got.y });
            any_failed = true;
        }
    }

    if (any_failed) return error.TestFailed;
}

test "draw text" {
    const window_width = 32;
    const window_height = 16;

    const Painter = struct {
        buffer: *[window_height][window_width]u8,

        pub fn measure_rune(painter: *const @This(), rune: u32, width: u32, familly: u32) u32 {
            _ = painter;
            _ = rune;
            _ = width;
            _ = familly;
            return 1;
        }

        pub fn draw_rune(p: *@This(), x: u32, y: u32, cp: u32) void {
            if (y >= window_height or x >= window_width) return;
            p.buffer[y][x] = @intCast(cp & 0xFF);
        }
    };

    const TestCase = struct {
        name: []const u8,
        input: struct {
            txt: []const u8,
            window: struct { width: u32, height: u32 },
            rect: Rect,
            font: Font(Painter, .{ .buffer = undefined }, u32, 0),
        },
        expected: struct {
            buffer: [][]const u8,
        },
    };

    var diagnostics = std.json.Diagnostics{};
    var reader: std.Io.Reader = .fixed(@embedFile("draw-text-testscase.json"));
    var json_reader = std.json.Reader.init(std.testing.allocator, &reader);
    defer json_reader.deinit();
    json_reader.enableDiagnostics(&diagnostics);

    const tests = std.json.parseFromTokenSource([]TestCase, std.testing.allocator, &json_reader, .{}) catch |err| {
        std.debug.print("{d}:{d} : {}\n", .{ diagnostics.getLine(), diagnostics.getColumn(), err });
        return err;
    };
    defer tests.deinit();

    var any_failed = false;
    for (tests.value) |tt| {
        var raw_buffer: [window_height][window_width]u8 = undefined;
        for (&raw_buffer) |*row| @memset(row, ' ');

        const w = tt.input.window.width;
        const h = tt.input.window.height;

        const font = Font(Painter, .{ .buffer = undefined }, u32, 0){
            .size = tt.input.font.size,
            .spacing = tt.input.font.spacing,
            .familly = 0,
            .line_spacing = tt.input.font.line_spacing,
            .@"align" = tt.input.font.@"align",
            .painter = Painter{ .buffer = &raw_buffer },
        };

        font.draw(tt.input.txt, tt.input.rect);

        for (tt.expected.buffer, 0..) |expected_row, row_i| {
            if (row_i >= h) break;
            const actual = raw_buffer[row_i][0..w];
            if (!std.mem.eql(u8, actual, expected_row)) {
                std.debug.print("FAIL [{s}] row {d}:\n  expected: {s}\n  got:      {s}\n", .{
                    tt.name, row_i, expected_row, actual,
                });
                any_failed = true;
            }
        }
    }

    if (any_failed) return error.TestFailed;
}
