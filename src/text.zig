const std = @import("std");

pub const AlignKind = enum { begin, middle, end };

pub fn Font(comptime T: type, comptime default_painter: T) type {
    return struct {
        size: u32,
        spacing: u32 = 0,
        line_spacing: u32 = 0,
        @"align": struct {
            x: AlignKind = .begin,
            y: AlignKind = .begin,
        },
        painter: T = default_painter,
        fn measureText(font: *const @This(), txt: ?[]const u8, width: u32) struct { x: u32, y: u32 } {
            _ = font;
            _ = txt;
            _ = width;
            return .{ .x = 0, .y = 0 };
        }
    };
}

test "measure text" {
    const Painter = struct {
        pub fn measure_rune(p: *@This(), rune: u32) u32 {
            _ = p;
            _ = rune;
            return 1;
        }
    };
    const TestCase = struct {
        name: []const u8,
        input: struct {
            txt: ?[]const u8,
            width: u32,
            font: Font(Painter, .{}),
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
