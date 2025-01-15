const std = @import("std");
const Table = @import("../csv.zig").Table;
const ParseError = @import("../csv.zig").ParseError;
const SchemaError = @import("../csv.zig").SchemaError;
const ColumnInfo = @import("../csv.zig").ColumnInfo;
const determineType = @import("type.zig").determineType;

pub inline fn splitAndAppendLine(self: *Table, line: []u8, expected_cols: usize, col_start_idx: usize) !void {
    var cell_count: usize = 0; // tracks total cells seen
    var cell_start: usize = 0;
    var cells_stored: usize = 0; // tracks cells actually stored
    var in_quote: bool = false;

    for (line, 0..) |char, idx| {
        if (char == '"') {
            in_quote = !in_quote;
        } else if (char == ',' and !in_quote) {
            // if a target col then we add
            if (cell_count >= col_start_idx) {
                try appendCell(self, line[cell_start..idx], cell_count);
                cells_stored += 1;
            }
            cell_count += 1;
            cell_start = idx + 1;
        }
    }

    // Handle last cell
    if (cell_start < line.len) {
        if (cell_count >= col_start_idx) {
            try appendCell(self, line[cell_start..], cell_count);
            cells_stored += 1;
        }
        cell_count += 1;
    }

    if (cell_count != expected_cols) {
        std.debug.print("Expected {any} cols, found {any} cols", .{ expected_cols, cell_count });
        return ParseError.MismatchLen;
    }
}

pub inline fn appendCell(self: *Table, cell: []u8, col_idx: usize) !void {
    if (self.indexToName.get(col_idx)) |col_name| {
        if (self.columns.getPtr(col_name)) |col_info| {
            // Parse and append based on column type

            const trimmed = std.mem.trim(u8, cell, " ");
            try col_info.data.append(trimmed);
        }
    }
}

pub fn getHeaderData(allocator: std.mem.Allocator, buffer: []u8, reader: anytype) !struct { header_data: std.ArrayList(u8), remaining_buffer: []const u8 } {
    var bytes_read = try reader.read(buffer);

    if (bytes_read == 0) {
        return SchemaError.NoHeaders;
    }

    var header_data = std.ArrayList(u8).init(allocator);

    var found_newline: bool = false;
    var pos: usize = 0;
    var remaining_buffer: []const u8 = &.{};

    while (!found_newline) {
        while (pos < bytes_read) {
            if (buffer[pos] == '\n') {
                found_newline = true;
                remaining_buffer = buffer[pos + 1 .. bytes_read];
                break;
            }
            pos += 1;
        }

        // header longer then buffer
        try header_data.appendSlice(buffer[0..pos]);

        if (!found_newline) {
            bytes_read = try reader.read(buffer);

            if (bytes_read == 0) {
                if (header_data.items.len > 0) {
                    break;
                }
                return SchemaError.InvalidFormat;
            }

            pos = 0;
        }
    }

    return .{
        .header_data = header_data,
        .remaining_buffer = remaining_buffer,
    };
}

pub fn saveColumnNames(self: *Table, header_data: std.ArrayList(u8)) !void {
    var col_index: usize = 0;
    var header_iter = std.mem.split(u8, header_data.items, ",");

    while (header_iter.next()) |header| {
        const trimmed = std.mem.trim(u8, header, " \r");
        const owned_header = try self.allocator.dupe(u8, trimmed);
        errdefer self.allocator.free(owned_header);

        if (trimmed.len == 0) {
            col_index += 1;
            self.column_start = 1;
            continue;
        }

        const col_info = ColumnInfo{
            .data = undefined,
            .index = col_index,
        };
        try self.indexToName.put(col_index, owned_header);
        try self.columns.put(owned_header, col_info);

        col_index += 1;
    }
}

pub fn saveColumnDtype(self: *Table, line_data: std.ArrayList(u8)) !void {
    var col_index: usize = self.column_start;

    var cell_iter = std.mem.split(u8, line_data.items, ",");

    // skip index if exists
    if (col_index == 1) {
        _ = cell_iter.next();
    }

    while (cell_iter.next()) |_| {
        if (self.indexToName.get(col_index)) |col_name| {
            if (self.columns.getPtr(col_name)) |col| {
                col.data = std.ArrayList([]const u8).init(self.allocator);
            }
        }

        col_index += 1;
    }
}
