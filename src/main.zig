const std = @import("std");
const Io = std.Io;

const shuf = @import("shuf");

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();
    _ = args.next(); // exe
    const seed: u64 = if (args.next()) |seed_str| blk: {
        break :blk try std.fmt.parseInt(u64, seed_str, 10);
    } else blk: {
        const ts = std.Io.Clock.real.now(init.io);
        break :blk @bitCast(ts.toMicroseconds());
    };

    var items: [26 * 26][2]u8 = undefined;
    var idx: usize = 0;
    inline for ('a'..'z' + 1) |c1| {
        inline for ('a'..'z' + 1) |c2| {
            const str: [2]u8 = .{ @intCast(c1), @intCast(c2) };
            items[idx] = str;
            idx += 1;
        }
    }

    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();

    var it: shuf.Iterator([2]u8) = .init(rand, &items);

    const out_file: std.Io.File = .stdout();
    var out_buf: [1024]u8 = undefined;
    var out_file_writer = out_file.writer(init.io, &out_buf);
    const output = &out_file_writer.interface;

    for (0..100) |_| {
        try output.print("{s}\n", .{&it.next()});
    }
    try output.flush();
}
