const std = @import("std");
const Table = @import("../csv.zig").Table;

pub fn calculateMemory(self: *Table) !f64 {
    var total_bytes: usize = 0;
    var col_it = self.columns.iterator();
    while (col_it.next()) |entry| {
        total_bytes += entry.value_ptr.data.items.len * @sizeOf([]const u8);
        for (entry.value_ptr.data.items) |str| {
            total_bytes += str.len;
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
