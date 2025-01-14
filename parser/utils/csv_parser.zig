const std = @import("std");
const Table = @import("../csv.zig").Table;
const ParseError = @import("../csv.zig").ParseError;

pub fn splitAndAppendLine(self: *Table, line: []u8, expected_cols: usize, col_start_idx: usize) !void {
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

pub fn appendCell(self: *Table, cell: []u8, col_idx: usize) !void {
    if (self.indexToName.get(col_idx)) |col_name| {
        if (self.columns.getPtr(col_name)) |col_info| {
            // Parse and append based on column type
            switch (col_info.data) {
                .Float => |*list| {
                    const trimmed = std.mem.trim(u8, cell, " ");
                    const value = try std.fmt.parseFloat(f32, trimmed);
                    try list.append(value);
                },
                .Int => |*list| {
                    const trimmed = std.mem.trim(u8, cell, " ");
                    const value = try std.fmt.parseInt(i32, trimmed, 10);
                    try list.append(value);
                },
                .String => |*list| {
                    const trimmed = std.mem.trim(u8, cell, " ");
                    try list.append(trimmed);
                },
            }
        }
    }
}
