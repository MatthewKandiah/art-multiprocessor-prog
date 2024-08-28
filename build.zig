const std = @import("std");

pub fn build(b: *std.Build) !void {
    const ex_num = b.option([]const u8, "ex", "Exercise number") orelse @panic("You have to provide an exercise number");
    var buf1: [32]u8 = undefined;
    var buf2: [32]u8 = undefined;
    const ex_name = try std.fmt.bufPrint(&buf1, "ex{s}", .{ex_num});
    const ex_path = try std.fmt.bufPrint(&buf2, "src/ex{s}.zig", .{ex_num});
    const exe = b.addExecutable(.{
        .name = ex_name,
        .root_source_file = b.path(ex_path),
        .target = b.host,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run the exercise");
    run_step.dependOn(&run_exe.step);
}
