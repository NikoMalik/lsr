const std = @import("std");
const zzdoc = @import("zzdoc");

/// Must be kept in sync with git tags
const version: std.SemanticVersion = .{ .major = 1, .minor = 0, .patch = 0 };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    {
        var man_step = zzdoc.addManpageStep(b, .{
            .root_doc_dir = b.path("docs/"),
        });

        const install_step = man_step.addInstallStep(.{});
        b.default_step.dependOn(&install_step.step);
    }

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const io_dep = b.dependency("ourio", .{ .optimize = optimize, .target = target });
    const ourio_m = io_dep.module("ourio");
    strip(ourio_m);
    exe_mod.addImport("ourio", ourio_m);
    const zeit_dep = b.dependency("zeit", .{ .optimize = optimize, .target = target });
    const zeit_m = zeit_dep.module("zeit");
    strip(zeit_m);
    exe_mod.addImport("zeit", zeit_m);

    const opts = b.addOptions();
    const version_string = genVersion(b) catch |err| {
        std.debug.print("{}", .{err});
        @compileError("couldn't get version");
    };
    opts.addOption([]const u8, "version", version_string);
    exe_mod.addOptions("build_options", opts);
    strip(exe_mod);
    const exe = b.addExecutable(.{
        .name = "lsr",
        .root_module = exe_mod,
    });
    strip_step(exe);
    b.installArtifact(exe);

    // run
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // unit tests
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn genVersion(b: *std.Build) ![]const u8 {
    if (!std.process.can_spawn) {
        std.debug.print("error: version info cannot be retrieved from git. Zig version must be provided using -Dversion-string\n", .{});
        std.process.exit(1);
    }
    const version_string = b.fmt("v{d}.{d}.{d}", .{ version.major, version.minor, version.patch });

    var code: u8 = undefined;
    const git_describe_untrimmed = b.runAllowFail(&[_][]const u8{
        "git",
        "-C",
        b.build_root.path orelse ".",
        "describe",
        "--match",
        "*.*.*",
        "--tags",
        "--abbrev=9",
    }, &code, .Ignore) catch {
        return version_string;
    };
    if (!std.mem.startsWith(u8, git_describe_untrimmed, version_string)) {
        std.debug.print("error: tagged version does not match internal version\n", .{});
        std.process.exit(1);
    }
    return std.mem.trim(u8, git_describe_untrimmed, " \n\r");
}

fn strip(root_module: *std.Build.Module) void {
    if (root_module.optimize != .Debug and root_module.optimize != .ReleaseSafe) {
        root_module.strip = true;
        root_module.omit_frame_pointer = true;
        root_module.unwind_tables = .none;
        root_module.sanitize_c = .off;
    } else {
        root_module.strip = false;
        root_module.omit_frame_pointer = false;
        root_module.unwind_tables = .sync;
        root_module.sanitize_c = .full;
    }
}

fn strip_step(step: *std.Build.Step.Compile) void {
    if (step.root_module.optimize != .Debug and step.root_module.optimize != .ReleaseSafe) {
        step.use_llvm = true;
        step.lto = .full;
        step.bundle_compiler_rt = true;
        step.pie = false;
        step.bundle_ubsan_rt = false;
        step.link_gc_sections = true;
        step.link_function_sections = true;
        step.link_data_sections = true;
        step.discard_local_symbols = true;

        step.compress_debug_sections = .none;
    } else {
        step.use_llvm = true;
    }
}
