const std = @import("std");
const Table = @import("../csv.zig").Table;

pub fn calculateMemory(self: *Table) !f64 {
    var total_bytes: usize = 0;
    var col_it = self.columns.iterator();
    while (col_it.next()) |entry| {
        switch (entry.value_ptr.data) {
            .Float => |list| total_bytes += list.items.len * @sizeOf(f32),
            .Int => |list| total_bytes += list.items.len * @sizeOf(i32),
            .String => |list| {
                // For strings, count both array capacity and actual string contents
                total_bytes += list.items.len * @sizeOf([]const u8);
                for (list.items) |str| {
                    total_bytes += str.len;
                }
            },
        }
    }
    const memory_mb = @as(f64, @floatFromInt(total_bytes)) / (1024 * 1024);
    return memory_mb;
}

pub fn measureElapsedTime(start_time: i128) f64 {
    const end_time = std.time.nanoTimestamp();
    const elapsed_nanos = end_time - start_time;
    return @as(f64, @floatFromInt(elapsed_nanos)) / 1_000_000_000.0;
}
