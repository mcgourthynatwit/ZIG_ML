const std = @import("std");
const expect = std.testing.expect;
const Table = @import("csv.zig").Table;

//////////////////// CSV /////////////////////
test "init_empty_table" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var empty_table: Table = Table.init(allocator);
    defer empty_table.deinit();

    // header is empty
    try expect(empty_table.headers.count() == 0);
    // body is empty
    try expect(empty_table.body.items.len == 0);
}

test "parse_empty_csv" {}

// Only has one line
test "parse_header_only_csv" {}

// There are more cols in rows then number of header in header row
test "parse_invalid_csv_1" {}

// Rows have a different shape then header count
test "parse_invalid_csv_2" {}

test "parse_invalid_txt" {}

test "parse_small_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/short_data.csv");

    defer table_1.deinit();

    std.debug.print("Header count is {d}\n", .{table_1.headers.count()});
    try expect(table_1.headers.count() == 4);
}

test "parse_med_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/med_data.csv");

    defer table_1.deinit();

    std.debug.print("Header count is {d}\n", .{table_1.headers.count()});
    try expect(table_1.headers.count() == 784);
}

test "parse_large_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/large_data.csv");

    defer table_1.deinit();

    std.debug.print("Header count is {d}\n", .{table_1.headers.count()});
    try expect(table_1.headers.count() == 785);
}
