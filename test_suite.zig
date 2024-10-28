const std = @import("std");
const expect = std.testing.expect;
const Table = @import("csv.zig").Table;
const TableError = @import("csv.zig").TableError;

//////////////////// CSV /////////////////////

// inits table and is shape [0,0]
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

// parses empty CSV should not add anything expected shape [0,0]
test "parse_empty_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/empty.csv");

    defer table_1.deinit();

    // Check columns
    const header_count = table_1.headers.count();
    if (header_count != 0) {
        std.debug.print("\nTest failed: Expected 0 headers but found {d} headers\n", .{header_count});
        try expect(false);
    }
    try expect(header_count == 0);

    // Check rows
    const row_count = table_1.body.items.len;
    if (row_count != 0) {
        std.debug.print("\nTest failed: Expected 0 rows but found {d} rows\n", .{row_count});
        try expect(false);
    }
    try expect(row_count == 0);
}

// Only has one line(headers)
test "parse_header_only_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/header_only.csv");

    defer table_1.deinit();

    // Check columns
    const header_count = table_1.headers.count();
    if (header_count != 6) {
        std.debug.print("\nTest failed: Expected 6 headers but found {d} headers\n", .{header_count});
        try expect(false);
    }
    try expect(header_count == 6);

    // Check rows
    const row_count = table_1.body.items.len;
    if (row_count != 0) {
        std.debug.print("\nTest failed: Expected 0 rows but found {d} rows\n", .{row_count});
        try expect(false);
    }
    try expect(row_count == 0);
}

// There are more cols in rows then number of header in header row
test "parse_invalid_csv_1" {}

// Rows have a different shape then header count
test "parse_invalid_csv_2" {}

// attempt to parse a txt file
test "parse_invalid_txt" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try expect(table_1.readCsv("test_data/test.txt") == TableError.InvalidFileType);
    defer table_1.deinit();
}

// parses csv with 4 cols 4 rows
test "parse_small_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/short_data.csv");

    defer table_1.deinit();

    // Check columns
    const header_count = table_1.headers.count();
    if (header_count != 4) {
        std.debug.print("\nTest failed: Expected 4 headers but found {d} headers\n", .{header_count});
        try expect(false);
    }
    try expect(header_count == 4);

    // Check rows
    const row_count = table_1.body.items.len;
    if (row_count != 4) {
        std.debug.print("\nTest failed: Expected 4 rows but found {d} rows\n", .{row_count});
        try expect(false);
    }
    try expect(row_count == 4);
}

// parses csv with 6 cols, 100 rows
test "parse_med_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/med_data.csv");

    defer table_1.deinit();

    // Check columns
    const header_count = table_1.headers.count();
    if (header_count != 6) {
        std.debug.print("\nTest failed: Expected 6 headers but found {d} headers\n", .{header_count});
        try expect(false);
    }
    try expect(header_count == 6);

    // Check rows
    const row_count = table_1.body.items.len;
    if (row_count != 100) {
        std.debug.print("\nTest failed: Expected 100 rows but found {d} rows\n", .{row_count});
        try expect(false);
    }
    try expect(row_count == 100);
}

// parses csv with 785 cols 42000 rows
test "parse_large_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.init(allocator);

    try table_1.readCsv("test_data/large_data.csv");

    defer table_1.deinit();

    // Check columns
    const header_count = table_1.headers.count();
    if (header_count != 785) {
        std.debug.print("\nTest failed: Expected 785 headers but found {d} headers\n", .{header_count});
        try expect(false);
    }
    try expect(header_count == 785);

    // Check rows
    const row_count = table_1.body.items.len;
    if (row_count != 42000) {
        std.debug.print("\nTest failed: Expected 42,000 rows but found {d} rows\n", .{row_count});
        try expect(false);
    }
    try expect(row_count == 42000);
}

//////////////////// Tensor /////////////////////

//////////////////// Integration Tests /////////////////////

//////////////////// CSV -> Tensor /////////////////////

//////////////////// CSV -> Tensor -> neural /////////////////////
