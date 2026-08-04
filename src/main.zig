const std = @import("std");
const Io = std.Io;

const crunch = @import("crunch");

const shuf = @import("shuf");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;
    const arena = init.arena.allocator();

    const cmd: Cmd = .parse(arena, init.minimal.args);

    const delimiter: u8 = if (cmd.null_terminated) 0 else '\n';

    const items = if (cmd.items) |items| blk: {
        break :blk try arena.dupe([]const u8, items);
    } else blk: {
        const input_file: std.Io.File = .stdin();
        var input_buf: [1024]u8 = undefined;
        var input_file_writer = input_file.reader(io, &input_buf);
        const input = &input_file_writer.interface;

        const data: []const u8 = data: {
            const d = try input.allocRemaining(gpa, .unlimited);
            defer gpa.free(d);
            break :data try arena.dupe(u8, d);
        };

        var lines: std.ArrayList([]const u8) = .empty;
        defer lines.deinit(gpa);

        var idx: usize = 0;
        while (std.mem.findScalarPos(u8, data, idx, delimiter)) |end| : (idx = end + 1) {
            const line = data[idx..end];
            if (cmd.null_terminated) {
                try lines.append(gpa, line);
            } else {
                try lines.append(gpa, std.mem.cutSuffix(u8, line, "\r") orelse line);
            }
        }
        const last_line = data[idx..];
        if (last_line.len != 0) try lines.append(gpa, last_line);

        break :blk try arena.dupe([]const u8, lines.items);
    };

    const line_count = cmd.line_count orelse items.len;

    const seed: u64 = blk: {
        const ts = std.Io.Clock.real.now(io);
        break :blk @bitCast(ts.toMicroseconds());
    };

    var prng: std.Random.DefaultPrng = .init(seed);
    const rand = prng.random();

    var it: shuf.Iterator([]const u8) = .init(rand, items);
    if (line_count <= items.len) it.threshold = items.len; // Only shuffle once

    const output_file: std.Io.File = .stdout();
    var output_buf: [1024]u8 = undefined;
    var output_file_writer = output_file.writer(io, &output_buf);
    const output = &output_file_writer.interface;

    for (0..line_count) |_| {
        try output.writeAll(it.next());
        try output.writeByte(delimiter);
    }
    try output.flush();
}

const Cmd = struct {
    line_count: ?usize,
    null_terminated: bool,
    items: ?[]const []const u8,

    pub fn parse(arena: std.mem.Allocator, args: std.process.Args) Cmd {
        var p: crunch.Parser = .init(arena, args);
        var cmd: Cmd = .{
            .line_count = null,
            .null_terminated = false,
            .items = null,
        };

        while (p.moreOptions()) {
            if (p.help()) exitHelp(0);
            if (p.flag("null")) |nul| {
                cmd.null_terminated = nul;
            } else if (p.option("line-count")) |line_count_opt| {
                cmd.line_count = std.fmt.parseInt(usize, line_count_opt, 10) catch {
                    p.fatal("invalid integer for --line-count: {s}", .{line_count_opt});
                };
            } else {
                p.fatal("unknown option: {s}", .{p.peek().?});
            }
        }

        if (p.moreArguments()) cmd.items = p.remainingArguments();

        return cmd;
    }
};

fn exitHelp(status: u8) noreturn {
    std.debug.print(
        \\usage: shuf [options] [--] [items...]
        \\
        \\Shuffle items provided on the command line or on standard input.
        \\If items are provided on the command line, then standard input is ignored.
        \\
        \\Options
        \\  --[no-]null         Separate input and output items with null characters
        \\  --line-count COUNT  Number of output lines to generate (default: number of input items)
        \\
    , .{});
    std.process.exit(status);
}
