const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Expose your library as a named module "parsil"
    const parsil_mod = b.addModule("parsil", .{
        .root_source_file = b.path("src/parsil.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Optional: build/install a static library artifact (compatible with Zig 0.15)
    const lib = b.addLibrary(.{
        .name = "parsil",
        .root_module = parsil_mod,
    });
    lib.root_module.resolved_target = target;
    lib.root_module.optimize = optimize;
    b.installArtifact(lib);

    // Tests (run via: `zig build test`)
    const test_mod = b.createModule(.{ .root_source_file = b.path("test.zig"), .target = target, .optimize = optimize });
    const unit_tests = b.addTest(.{ .root_module = test_mod });
    unit_tests.root_module.addImport("parsil", parsil_mod);

    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Cross-target test compilation (compile for additional targets without running)
    const test_all = b.step("test-all", "Run native tests and compile for extra targets");
    test_all.dependOn(&run_tests.step);

    const builtin = @import("builtin");
    const extra_targets: []const std.Target.Query = if (builtin.os.tag == .macos)
        &.{
            // Linux
            .{ .cpu_arch = .x86_64, .os_tag = .linux },
            // macOS (Apple Silicon)
            .{ .cpu_arch = .aarch64, .os_tag = .macos },
            // Windows
            .{ .cpu_arch = .x86_64, .os_tag = .windows },
            .{ .cpu_arch = .aarch64, .os_tag = .windows },
            // WASM (WASI)
            .{ .cpu_arch = .wasm32, .os_tag = .wasi },
        }
    else
        &.{
            // Linux
            .{ .cpu_arch = .x86_64, .os_tag = .linux },
            // Windows
            .{ .cpu_arch = .x86_64, .os_tag = .windows },
            .{ .cpu_arch = .aarch64, .os_tag = .windows },
            // WASM (WASI)
            .{ .cpu_arch = .wasm32, .os_tag = .wasi },
        };
    for (extra_targets) |tq| {
        const cross_test_mod = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = b.resolveTargetQuery(tq),
            .optimize = optimize,
        });
        cross_test_mod.addImport("parsil", parsil_mod);
        const cross_tests = b.addTest(.{ .root_module = cross_test_mod });
        // Compile-only dependency (no run artifact for cross targets)
        test_all.dependOn(&cross_tests.step);
    }
}
