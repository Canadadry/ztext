const std = @import("std");

pub const AlignKind = enum { begin, middle, end };

const Font = struct {
    size: u32,
    spacing: u32,
    line_spacing: u32,
    @"align": struct {
        x: AlignKind,
        y: AlignKind,
    },
};

const TestCase = struct {
    name: []const u8,
    input: struct {
        txt: ?[]const u8,
        width: u32,
        font: Font,
    },
    expected: struct {
        x: u32,
        y: u32,
    },
};

fn measureText(txt: ?[]const u8, width: u32, font: Font) struct { x: u32, y: u32 } {
    _ = txt;
    _ = width;
    _ = font;
    return .{ .x = 0, .y = 0 };
}

test "measure text" {
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
        const got = measureText(tt.input.txt, tt.input.width, tt.input.font);
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
