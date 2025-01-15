const std = @import("std");
const expect = std.testing.expect;
const Table = @import("parser/csv.zig").Table;
const TableError = @import("parser/csv.zig").TableError;
const SchemaError = @import("parser/csv.zig").SchemaError;
const calculateMemory = @import("parser/utils/performance.zig").calculateMemory;
const calculateTime = @import("parser/utils/performance.zig").measureElapsedTime;

//////////////////// CSV /////////////////////
test "parse_empty_csv" {
    const table = Table.readCsv("test_data/empty.csv");

    if (table) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try std.testing.expectEqual(err, SchemaError.NoHeaders);
    }
}

test "parse_header_only_csv" {
    const table = try Table.readCsv("test_data/header_only.csv");

    const header_count = table.columns.count();

    try expect(header_count == 6);
}

test "performance_test" {
    const dir_path: []const u8 = "test_data/performance_testing/movie";
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const full_path = try std.fs.path.join(std.heap.page_allocator, &[_][]const u8{ dir_path, entry.name });
        defer std.heap.page_allocator.free(full_path);

        std.debug.print("\nFile {s}\n", .{entry.name});

        var table: Table = try Table.readCsv(full_path);
        table.deinit();
    }
}
