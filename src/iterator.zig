const std = @import("std");

pub fn Iterator(T: type) type {
    return struct {
        items: []T,
        /// Index of the next item
        idx: usize,
        consumed: usize,
        threshold: usize,
        rand: std.Random,

        const Self = @This();

        pub fn init(rand: std.Random, items: []T) Self {
            rand.shuffle(T, items);
            return .{
                .items = items,
                .idx = 0,
                .consumed = 0,
                .threshold = @trunc(@as(f32, @floatFromInt(items.len)) * (2.0 / 5.0)),
                .rand = rand,
            };
        }

        pub fn next(it: *Self) T {
            const item = it.items[it.idx];
            it.idx = (it.idx + 1) % it.items.len;
            it.consumed += 1;

            if (it.consumed >= it.threshold) {
                it.consumed = 0;

                const shuf_offset = it.idx;
                const shuf_len = it.items.len - it.threshold;

                for (1..shuf_len) |i| {
                    const j = it.rand.intRangeAtMost(usize, 0, i);
                    // i and j indices converted to ring buffer
                    const i_rb = (shuf_offset + i) % it.items.len;
                    const j_rb = (shuf_offset + j) % it.items.len;
                    std.mem.swap(T, &it.items[i_rb], &it.items[j_rb]);
                }
            }

            return item;
        }
    };
}
