const std = @import("std");
const expect = std.testing.expect;
const Table = @import("csv.zig").Table;
const TableError = @import("csv.zig").TableError;
const SchemaError = @import("csv.zig").SchemaError;

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
