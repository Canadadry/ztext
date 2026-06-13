# ztext

A comptime-generic text layout and rendering library for Zig.

`ztext` provides text measurement and drawing primitives with support for word wrapping, multi-line layout, horizontal/vertical alignment, configurable spacing, and Unicode (UTF-8). The rendering backend is fully user-defined — `ztext` calls into a `painter` you supply, so it works with any output target (terminal buffers, framebuffers, GUI canvases, etc.).

---

## Features

- Word-wrap within a fixed pixel width
- Multi-line layout with configurable line spacing and character spacing
- Horizontal and vertical alignment (`begin` / `middle` / `end`)
- Unicode-aware iteration (UTF-8 codepoints)
- Comptime-generic: font family and painter types are type parameters — zero runtime overhead
- JSON-driven test suite for both measurement and drawing


## Building

```sh
# Run the test suite
zig build test

# Run the bundled example
zig build example
```

## Adding ztext as a dependency

just run

```bash
zig fetch --save https://github.com/Canadadry/ztext/archive/refs/heads/master.tar.gz
```

And add in your own `build.zig`:

```zig
const ztext_dep = b.dependency("ztext", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("ztext", ztext_dep.module("ztext"));
```
