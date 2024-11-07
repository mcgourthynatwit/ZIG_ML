const std = @import("std");
const expect = std.testing.expect;
const Table = @import("csv.zig").Table;
const TableError = @import("csv.zig").TableError;
const Tensor = @import("tensor.zig").Tensor;
const TensorError = @import("tensor.zig").TensorError;

//////////////////// CSV /////////////////////

// inits table and is shape [0,0]
test "init_empty_table" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var empty_table: Table = Table.initTable(allocator);
    defer empty_table.deinitTable();

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
    var table_1: Table = Table.initTable(allocator);

    try table_1.readCsvTable("test_data/empty.csv");

    defer table_1.deinitTable();

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
    var table_1: Table = Table.initTable(allocator);

    try table_1.readCsvTable("test_data/header_only.csv");

    defer table_1.deinitTable();

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
    var table_1: Table = Table.initTable(allocator);

    try expect(table_1.readCsvTable("test_data/test.txt") == TableError.InvalidFileType);
    defer table_1.deinitTable();
}

// parses csv with 4 cols 4 rows
test "parse_small_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.initTable(allocator);

    try table_1.readCsvTable("test_data/short_data.csv");

    defer table_1.deinitTable();

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
    var table_1: Table = Table.initTable(allocator);
    defer table_1.deinitTable();

    const start_time: i128 = std.time.nanoTimestamp();

    try table_1.readCsvTable("test_data/med_data.csv");

    const end_time: i128 = std.time.nanoTimestamp();

    const time_read_seconds: f64 = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;

    // normal zig build
    try expect(time_read_seconds < 0.01);

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
    var table_1: Table = Table.initTable(allocator);
    defer table_1.deinitTable();

    const start_time: i128 = std.time.nanoTimestamp();

    try table_1.readCsvTable("test_data/large_data.csv");

    const end_time: i128 = std.time.nanoTimestamp();

    const time_read_seconds: f64 = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;

    // 6.5 for normal zig build
    std.debug.print("TIME WAS {d} \n", .{time_read_seconds});

    // sub 1.0 for -O ReleaseFast
    // try expect(time_read_seconds < 1.0);

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

test "filter_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var table_1: Table = Table.initTable(allocator);

    // rank,title,description,genre,rating,year
    try table_1.readCsvTable("test_data/med_data.csv");
    defer table_1.deinitTable();

    // Empty filter
    const col_filter_0 = [_][]const u8{};

    // Too many cols
    const col_filter_1 = [_][]const u8{ "rank", "title", "description", "genre", "rating", "year", "year" };

    // Invalid column
    const col_filter_2 = [_][]const u8{"invalid_col"};

    // Invalid column with valid columns
    const col_filter_3 = [_][]const u8{ "rank", "title", "invalid_col" };

    // Valid columns
    const col_filter_4 = [_][]const u8{ "rank", "title" };
    const col_filter_5 = [_][]const u8{ "rank", "title", "description", "genre", "rating", "year" };

    // Test that passing empty array raises InvalidColumn erorr
    if (table_1.filterTable(allocator, &col_filter_0)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    // Test that passing header array that containes more then Table header count raises InvalidColumn erorr
    if (table_1.filterTable(allocator, &col_filter_1)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    // Test that passing array with col value that doesnt exist raises InvalidColumn erorr
    if (table_1.filterTable(allocator, &col_filter_2)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    // Test that passing array with col value that doesnt exist along with "good" col values still raises InvalidColumn erorr
    if (table_1.filterTable(allocator, &col_filter_3)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    var table_filter_1: Table = try table_1.filterTable(allocator, &col_filter_4);
    var table_filter_2: Table = try table_1.filterTable(allocator, &col_filter_5);

    defer table_filter_1.deinitTable();
    defer table_filter_2.deinitTable();

    try expect(table_filter_1.headers.count() == 2);
    try expect(table_filter_1.body.items.len == table_1.body.items.len);

    try expect(table_filter_2.headers.count() == 6);
    try expect(table_filter_2.body.items.len == table_1.body.items.len);
}

test "drop_csv" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var table_1: Table = Table.initTable(allocator);
    defer table_1.deinitTable();

    // rank,title,description,genre,rating,year
    try table_1.readCsvTable("test_data/med_data.csv");

    // Empty drop
    const col_drop_0 = [_][]const u8{};

    // Too many cols
    const col_drop_1 = [_][]const u8{ "rank", "title", "description", "genre", "rating", "year", "year" };

    // Invalid column
    const col_drop_2 = [_][]const u8{"invalid_col"};

    // Invalid column with valid columns
    const col_drop_3 = [_][]const u8{ "rank", "title", "invalid_col" };

    // Drop all this should erro
    const col_drop_4 = [_][]const u8{ "rank", "title", "description", "genre", "rating", "year" };

    // Valid columns
    const col_drop_5 = [_][]const u8{ "rank", "title" };

    // Valid columns
    const col_drop_6 = [_][]const u8{ "rank", "title", "genre", "rating" };

    // Test that passing empty array raises InvalidColumn erorr
    if (table_1.dropColumnTable(allocator, &col_drop_0)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    // Test that passing too many cols raises InvalidColumn erorr
    if (table_1.dropColumnTable(allocator, &col_drop_1)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    // Test that passing array with col value that doesnt exist raises InvalidColumn erorr
    if (table_1.dropColumnTable(allocator, &col_drop_2)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    // Test that passing array with col value that doesnt exist along with "good" col values still raises InvalidColumn erorr
    if (table_1.dropColumnTable(allocator, &col_drop_3)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidColumn);
    }

    // Test that passing array with all cols raises InvalidDropAllColumns erorr
    if (table_1.dropColumnTable(allocator, &col_drop_4)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try expect(err == error.InvalidDropAllColumns);
    }

    var table_drop_1: Table = try table_1.dropColumnTable(allocator, &col_drop_5);
    defer table_drop_1.deinitTable();

    var table_drop_2: Table = try table_1.dropColumnTable(allocator, &col_drop_6);
    defer table_drop_2.deinitTable();

    try expect(table_drop_1.headers.count() == 4);
    try expect(table_drop_1.body.items.len == table_1.body.items.len);

    try expect(table_drop_2.headers.count() == 2);
    try expect(table_drop_2.body.items.len == table_1.body.items.len);
}

//////////////////// Tensor /////////////////////
test "tensor_init_1" {}

test "tensor_dot_product" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const tensor_data_1 = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const tensor_data_2 = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };

    var tensor_1: Tensor = try Tensor.initTensor(allocator, 2, 3, &tensor_data_1);
    var tensor_2: Tensor = try Tensor.initTensor(allocator, 3, 2, &tensor_data_2);

    defer tensor_1.deinitTensor();
    defer tensor_2.deinitTensor();

    try expect(tensor_1.shape[0] == 2);
    try expect(tensor_1.shape[1] == 3);

    try expect(tensor_2.shape[0] == 3);
    try expect(tensor_2.shape[1] == 2);

    try tensor_1.matmul(tensor_2);

    try expect(tensor_1.shape[0] == 2);
    try expect(tensor_1.shape[1] == 2);

    try expect(std.mem.eql(f32, tensor_1.data[0..4], &[_]f32{ 22.0, 28.0, 49.0, 64.0 }));

    var t_transposed: Tensor = try tensor_2.transpose();
    defer t_transposed.deinitTensor();

    try expect(t_transposed.shape[0] == 2);
    try expect(t_transposed.shape[1] == 3);
    try expect(std.mem.eql(f32, t_transposed.data[0..6], &[_]f32{ 1.0, 3.0, 5.0, 2.0, 4.0, 6.0 }));

    try tensor_1.matmul(t_transposed);

    try expect(std.mem.eql(f32, tensor_1.data[0..6], &[_]f32{ 78.0, 178.0, 278.0, 177.0, 403.0, 629.0 }));
    try expect(tensor_1.shape[0] == 2);
    try expect(tensor_1.shape[1] == 3);
}

//////////////////// Integration Tests /////////////////////

//////////////////// CSV -> Tensor /////////////////////

test "csv_tensor_2" {}

test "csv_tensor_3" {}

//////////////////// CSV -> Tensor -> neural /////////////////////
