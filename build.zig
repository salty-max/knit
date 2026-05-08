const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ----- Library module + artifact ---------------------------------------

    const parsil_mod = b.addModule("parsil", .{
        .root_source_file = b.path("src/parsil.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "parsil",
        .root_module = parsil_mod,
    });
    b.installArtifact(lib);

    // ----- Format ----------------------------------------------------------

    // `zig build fmt` rewrites every .zig file in place.
    const fmt = b.addFmt(.{
        .paths = &.{ "src", "tests", "test.zig", "build.zig" },
        .check = false,
    });
    b.step("fmt", "Format every .zig file in place").dependOn(&fmt.step);

    // `zig build fmt-check` fails on any drift; what CI runs.
    const fmt_check = b.addFmt(.{
        .paths = &.{ "src", "tests", "test.zig", "build.zig" },
        .check = true,
    });
    b.step("fmt-check", "Check formatting without writing").dependOn(&fmt_check.step);

    // ----- Native tests, default optimize ----------------------------------

    const native_test_mod = b.createModule(.{
        .root_source_file = b.path("test.zig"),
        .target = target,
        .optimize = optimize,
    });
    native_test_mod.addImport("parsil", parsil_mod);
    const native_tests = b.addTest(.{ .root_module = native_test_mod });
    const run_native_tests = b.addRunArtifact(native_tests);
    b.step("test", "Run native tests").dependOn(&run_native_tests.step);

    // ----- Native tests in every release mode (CI matrix) ------------------

    const test_modes_step = b.step("test-modes", "Run native tests in every release mode");
    const modes = [_]std.builtin.OptimizeMode{ .Debug, .ReleaseSafe, .ReleaseFast, .ReleaseSmall };
    for (modes) |mode| {
        const mode_name = @tagName(mode);
        const mode_test_mod = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = mode,
        });
        mode_test_mod.addImport("parsil", parsil_mod);
        const mode_tests = b.addTest(.{
            .name = b.fmt("test-{s}", .{mode_name}),
            .root_module = mode_test_mod,
        });
        const run_mode_tests = b.addRunArtifact(mode_tests);
        const mode_step = b.step(b.fmt("test-{s}", .{mode_name}), b.fmt("Run native tests in {s} mode", .{mode_name}));
        mode_step.dependOn(&run_mode_tests.step);
        test_modes_step.dependOn(&run_mode_tests.step);
    }

    // ----- Cross-target compile-only tests ---------------------------------

    const test_all = b.step("test-all", "Run native tests + compile-only on extra targets");
    test_all.dependOn(&run_native_tests.step);

    const extra_targets: []const std.Target.Query = if (builtin.os.tag == .macos)
        &.{
            .{ .cpu_arch = .x86_64, .os_tag = .linux },
            .{ .cpu_arch = .aarch64, .os_tag = .macos },
            .{ .cpu_arch = .x86_64, .os_tag = .windows },
            .{ .cpu_arch = .aarch64, .os_tag = .windows },
            .{ .cpu_arch = .wasm32, .os_tag = .wasi },
        }
    else
        &.{
            .{ .cpu_arch = .x86_64, .os_tag = .linux },
            .{ .cpu_arch = .x86_64, .os_tag = .windows },
            .{ .cpu_arch = .aarch64, .os_tag = .windows },
            .{ .cpu_arch = .wasm32, .os_tag = .wasi },
        };
    for (extra_targets) |tq| {
        const cross_mod = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = b.resolveTargetQuery(tq),
            .optimize = optimize,
        });
        cross_mod.addImport("parsil", parsil_mod);
        const cross_tests = b.addTest(.{ .root_module = cross_mod });
        test_all.dependOn(&cross_tests.step);
    }

    // ----- Lint scripts ----------------------------------------------------
    //
    // Each script is owned by its own Phase 0 issue and may not exist yet —
    // `zig build lint` exits non-zero until every script lands.

    const check_imports = b.addSystemCommand(&.{ "bash", "scripts/check-imports.sh" });
    b.step("imports", "Forbid @import past one parent").dependOn(&check_imports.step);

    const check_unused = b.addSystemCommand(&.{ "bash", "scripts/check-unused.sh" });
    b.step("unused", "Detect unused public exports").dependOn(&check_unused.step);

    const check_strict = b.addSystemCommand(&.{ "bash", "scripts/check-strict.sh" });
    b.step("strict", "Forbid anyerror, *anyopaque in pub APIs, unjustified casts").dependOn(&check_strict.step);

    const check_mirror = b.addSystemCommand(&.{ "bash", "scripts/check-mirror.sh" });
    b.step("mirror", "Verify every parser has its mirror test").dependOn(&check_mirror.step);

    const lint_step = b.step("lint", "Run every static check CI runs");
    lint_step.dependOn(&fmt_check.step);
    lint_step.dependOn(&check_imports.step);
    lint_step.dependOn(&check_unused.step);
    lint_step.dependOn(&check_strict.step);
    lint_step.dependOn(&check_mirror.step);

    // ----- All-in-one CI ---------------------------------------------------

    const ci_step = b.step("ci", "Local equivalent of CI: lint + test-modes + test-all");
    ci_step.dependOn(lint_step);
    ci_step.dependOn(test_modes_step);
    ci_step.dependOn(test_all);

    // ----- Changesets ------------------------------------------------------

    const changeset_new = b.addSystemCommand(&.{ "bash", "scripts/changeset-new.sh" });
    b.step("changeset", "Scaffold a new changeset interactively").dependOn(&changeset_new.step);

    const changeset_version = b.addSystemCommand(&.{ "bash", "scripts/changeset-version.sh" });
    b.step("version", "Consume pending changesets, bump version, prepend CHANGELOG").dependOn(&changeset_version.step);

    // ----- Cleanup ---------------------------------------------------------

    const clean_step = b.step("clean", "Remove zig-out and .zig-cache");
    clean_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
    clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
}
