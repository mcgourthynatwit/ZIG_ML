const std = @import("std");
const Table = @import("../csv.zig").Table;
const ColumnInfo = @import("../csv.zig").ColumnInfo;

pub fn calculateMemory(self: *Table) !f64 {
    var total_bytes: usize = 0;

    // 1. Base table structure
    total_bytes += @sizeOf(Table);

    // 2. Table's HashMaps overhead
    total_bytes += self.columns.capacity() * @sizeOf(std.StringHashMap(ColumnInfo).Entry);
    total_bytes += self.indexToName.capacity() * @sizeOf(std.AutoHashMap(usize, []const u8).Entry);

    // 3. Column names storage
    var name_it = self.indexToName.iterator();
    while (name_it.next()) |entry| {
        total_bytes += entry.value_ptr.len;
    }

    // 4. Column data and structures
    var col_it = self.columns.iterator();
    while (col_it.next()) |entry| {
        // Column structure
        total_bytes += @sizeOf(ColumnInfo);

        // StringIds array
        const stringid_size = entry.value_ptr.data.items.len * @sizeOf(u32);

        // String content
        var string_content_size: usize = 0;
        for (entry.value_ptr.stringPool.values.items) |str| {
            string_content_size += str.len;
        }

        // StringPool structures
        const array_capacity_size = entry.value_ptr.stringPool.values.capacity * @sizeOf([]const u8);
        const hashmap_entry_size = entry.value_ptr.stringPool.unique_strings.count() *
            (@sizeOf([]const u8) + @sizeOf(u32));
        const hashmap_capacity_size = entry.value_ptr.stringPool.unique_strings.capacity() *
            @sizeOf(std.StringHashMap(u32).Entry);

        std.debug.print("Column: {s}\n", .{entry.key_ptr.*});
        std.debug.print("  StringIds size: {d} bytes\n", .{stringid_size});
        std.debug.print("  String content: {d} bytes\n", .{string_content_size});
        std.debug.print("  Array capacity: {d} bytes\n", .{array_capacity_size});
        std.debug.print("  HashMap entries: {d} bytes\n", .{hashmap_entry_size});
        std.debug.print("  HashMap capacity: {d} bytes\n", .{hashmap_capacity_size});
        std.debug.print("  Column structure: {d} bytes\n", .{@sizeOf(ColumnInfo)});

        total_bytes += stringid_size + string_content_size + array_capacity_size +
            hashmap_entry_size + hashmap_capacity_size;
    }

    // Fixed: Padding calculation using proper type conversion
    const padding_estimate: usize = total_bytes / 10; // 10% as integer division

    std.debug.print("\nOverhead Breakdown:\n", .{});
    std.debug.print("  Table structure: {d} bytes\n", .{@sizeOf(Table)});
    std.debug.print("  Table HashMaps: {d} bytes\n", .{self.columns.capacity() * @sizeOf(std.StringHashMap(ColumnInfo).Entry) +
        self.indexToName.capacity() * @sizeOf(std.AutoHashMap(usize, []const u8).Entry)});
    std.debug.print("  Estimated padding: {d} bytes\n", .{padding_estimate});

    total_bytes += padding_estimate;

    const memory_mb = @as(f64, @floatFromInt(total_bytes)) / (1024 * 1024);
    return memory_mb;
}

pub fn measureElapsedTime(start_time: i128) f64 {
    const end_time = std.time.nanoTimestamp();
    const elapsed_nanos = end_time - start_time;
    return @as(f64, @floatFromInt(elapsed_nanos)) / 1_000_000_000.0;
}
