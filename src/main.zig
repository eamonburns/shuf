const std = @import("std");
const Io = std.Io;

const shuf = @import("shuf");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var args = try init.minimal.args.iterateAllocator(gpa);
    defer args.deinit();
    _ = args.next(); // exe
    const seed: u64 = if (args.next()) |seed_str| blk: {
        break :blk try std.fmt.parseInt(u64, seed_str, 10);
    } else blk: {
        const ts = std.Io.Clock.real.now(io);
        break :blk @bitCast(ts.toMicroseconds());
    };

    const input_file: std.Io.File = .stdin();
    var input_buf: [1024]u8 = undefined;
    var input_file_writer = input_file.reader(io, &input_buf);
    const input = &input_file_writer.interface;

    const data = try input.allocRemaining(gpa, .unlimited);
    defer gpa.free(data);

    var lines: std.ArrayList([]const u8) = .empty;
    defer lines.deinit(gpa);

    var idx: usize = 0;
    while (std.mem.findScalarPos(u8, data, idx, '\n')) |end| : (idx = end + 1) {
        const line = data[idx..end];
        try lines.append(gpa, std.mem.cutSuffix(u8, line, "\r") orelse line);
    }
    const last_line = data[idx..];
    if (last_line.len != 0) try lines.append(gpa, last_line);

    const items = try lines.toOwnedSlice(gpa);
    defer gpa.free(items);

    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();

    var it: shuf.Iterator([]const u8) = .init(rand, items);

    const output_file: std.Io.File = .stdout();
    var output_buf: [1024]u8 = undefined;
    var output_file_writer = output_file.writer(io, &output_buf);
    const output = &output_file_writer.interface;

    for (0..100) |_| {
        try output.print("{s}\n", .{it.next()});
    }
    try output.flush();
}
