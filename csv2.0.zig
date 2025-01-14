const std = @import("std");

pub const TableError = error{ MissingHeader, OutOfMemory, InvalidColumn, InvalidDropAllColumns, InvalidFileType, CannotConvertStringToFloat };
const ParseError = error{MismatchLen};
const SchemaError = error{ NoHeaders, InvalidFormat, NoData };

pub const Column = union(enum) {
    Float: std.ArrayList(f32),
    Int: std.ArrayList(i32),
    String: std.ArrayList([]const u8),
};

pub const ColumnType = enum {
    Float,
    Int,
    String,
};

pub const ColumnInfo = struct {
    data: Column,
    index: usize,
};

pub const Table = struct {
    column_start: usize, // which col starts current implementation ignores index so this is either 0(no idx) or 1
    columns: std.StringHashMap(ColumnInfo),
    indexToName: std.AutoHashMap(usize, []const u8), // maps col idx to name
    allocator: std.mem.Allocator,
    len: usize,
    file_size: usize,

    fn verifyFileType(file_name: []const u8) bool {
        const extension_index = std.mem.lastIndexOf(u8, file_name, ".");

        if (extension_index == null) {
            return false;
        }

        const extension = file_name[extension_index.?..];

        if (!std.mem.eql(u8, extension, ".csv")) {
            return false;
        }

        return true;
    }

    pub fn deinit(self: *Table) void {
        var col_it = self.columns.iterator();
        while (col_it.next()) |entry| {
            switch (entry.value_ptr.data) {
                .Float => |*list| list.deinit(),
                .Int => |*list| list.deinit(),
                .String => |*list| list.deinit(),
            }
        }
        self.columns.deinit();
        self.indexToName.deinit();
    }

    fn analyzeSchema(self: *Table, reader: anytype, buffer: []u8) !usize {
        const estimated_rows: usize = try self.getColumnDtype(reader, buffer);
        return estimated_rows;
    }

    fn getHeaderNames(self: *Table, reader: anytype, buffer: []u8) ![]const u8 {
        var bytes_read = try reader.read(buffer);
        if (bytes_read == 0) {
            return SchemaError.NoHeaders;
        }

        // find end of line
        var header_data = std.ArrayList(u8).init(self.allocator);
        defer header_data.deinit();

        var found_newline = false;
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
                    return SchemaError.InvalidFormat;
                }

                pos = 0;
            }
        }

        var header_iter = std.mem.split(u8, header_data.items, ",");
        var col_index: usize = 0;

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

        return remaining_buffer;
    }

    fn getColumnDtype(self: *Table, reader: anytype, buffer: []u8) !usize {
        var remaining_buffer: []const u8 = try self.getHeaderNames(reader, buffer);

        var bytes_read = remaining_buffer.len;

        if (bytes_read == 0) {
            bytes_read = try reader.read(buffer);

            if (bytes_read == 0) {
                return SchemaError.NoData;
            }

            remaining_buffer = buffer[0..bytes_read];
        }

        var line_data = std.ArrayList(u8).init(self.allocator);
        defer line_data.deinit();

        var found_newline = false;
        var pos: usize = 0;
        var first_row_size: usize = 0; // used to estimate num rows

        while (!found_newline) {
            while (pos < bytes_read) {
                if (buffer[pos] == '\n') {
                    found_newline = true;
                    first_row_size = pos;
                    break;
                }
                pos += 1;
            }
            try line_data.appendSlice(buffer[0..pos]);

            if (!found_newline) {
                bytes_read = try reader.read(buffer);
                if (bytes_read == 0) {
                    // EOF handle currently as okay
                    found_newline = true;
                    first_row_size = pos;
                }
                pos = 0;
            }
        }

        var col_index: usize = self.column_start;

        var cell_iter = std.mem.split(u8, line_data.items, ",");

        // skip index if exists
        if (col_index == 1) {
            _ = cell_iter.next();
        }

        while (cell_iter.next()) |cell| {
            const trimmed = std.mem.trim(u8, cell, " \r");
            const col_type = try determineType(trimmed);
            if (self.indexToName.get(col_index)) |col_name| {
                if (self.columns.getPtr(col_name)) |col| {
                    col.data = switch (col_type) {
                        .Float => .{ .Float = std.ArrayList(f32).init(self.allocator) },
                        .Int => .{ .Int = std.ArrayList(i32).init(self.allocator) },
                        .String => .{ .String = std.ArrayList([]const u8).init(self.allocator) },
                    };
                }
            }

            col_index += 1;
        }

        // estimate num rows
        const estimated_rows = self.file_size / first_row_size;
        return estimated_rows;
    }

    fn determineType(value: []const u8) !ColumnType {
        // int
        if (std.fmt.parseInt(i32, value, 10)) |_| {
            return .Int;
        } else |_| {
            if (std.fmt.parseFloat(f32, value)) |_| {
                return .Float;
            } else |_| {
                return .String;
            }
        }
    }

    fn initCols(self: *Table, estimated_rows: usize) !void {
        var col_it = self.columns.iterator();

        while (col_it.next()) |entry| {
            // Init col arrays
            entry.value_ptr.data = switch (entry.value_ptr.data) {
                .Float => .{ .Float = try std.ArrayList(f32).initCapacity(self.allocator, estimated_rows) },
                .Int => .{ .Int = try std.ArrayList(i32).initCapacity(self.allocator, estimated_rows) },
                .String => .{ .String = try std.ArrayList([]const u8).initCapacity(self.allocator, estimated_rows) },
            };
        }
    }

    fn splitAndAppendLine(self: *Table, line: []u8, expected_cols: usize, col_start_idx: usize) !void {
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
                    try self.appendCell(line[cell_start..idx], cell_count);
                    cells_stored += 1;
                }
                cell_count += 1;
                cell_start = idx + 1;
            }
        }

        // Handle last cell
        if (cell_start < line.len) {
            if (cell_count >= col_start_idx) {
                try self.appendCell(line[cell_start..], cell_count);
                cells_stored += 1;
            }
            cell_count += 1;
        }

        if (cell_count != expected_cols) {
            std.debug.print("Expected {any} cols, found {any} cols", .{ expected_cols, cell_count });
            return ParseError.MismatchLen;
        }
    }

    fn appendCell(self: *Table, cell: []u8, col_idx: usize) !void {
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

    fn parseLine(self: *Table, line: []u8, expected_cols: usize) !void {
        try self.splitAndAppendLine(line, expected_cols, self.column_start);

        return;
    }

    fn calculateMemory(self: *Table) !f64 {
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

    fn parseBody(self: *Table, estimated_rows: usize, file_name: []const u8) !void {
        const start_time = std.time.nanoTimestamp();
        try self.initCols(estimated_rows);

        const file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();

        var buffered_reader = std.io.bufferedReader(file.reader());
        var reader = buffered_reader.reader();

        const buffer_size: usize = 8092 * 1024;
        var buf = try self.allocator.alignedAlloc(u8, @alignOf(u8), buffer_size);
        defer self.allocator.free(buf);

        var remaining = std.ArrayListAligned(u8, @alignOf(u8)).init(self.allocator);
        defer remaining.deinit();

        // Skip header
        _ = try reader.readUntilDelimiter(buf, '\n');

        var i: usize = 0;
        const expected_cols = self.columns.count() + self.column_start;

        while (true) {
            const bytes_read = try reader.read(buf);
            if (bytes_read == 0) break;

            var chunk = buf[0..bytes_read];
            var start: usize = 0;

            if (remaining.items.len > 0) {
                // Append new chunk to remaining data
                try remaining.appendSlice(chunk);
                chunk = remaining.items;
            }

            while (std.mem.indexOfScalar(u8, chunk[start..], '\n')) |end| {
                const line = chunk[start .. start + end];
                const line_copy = try self.allocator.dupe(u8, line);
                try self.parseLine(line_copy, expected_cols);
                start += end + 1;
                i += 1;
            }

            // Handle remaining data
            if (start < chunk.len) {
                remaining.clearRetainingCapacity();
                try remaining.appendSlice(chunk[start..]);
            } else {
                remaining.clearRetainingCapacity();
            }
        }

        // Handle any final remaining data
        if (remaining.items.len > 0) {
            const line_copy = try self.allocator.dupe(u8, remaining.items);
            try self.parseLine(line_copy, expected_cols);
            i += 1;
        }

        const end_time = std.time.nanoTimestamp();
        const elapsed_nanos = end_time - start_time;
        const elapsed_s = @as(f64, @floatFromInt(elapsed_nanos)) / 1_000_000_000.0;
        const memory_mb: f64 = try self.calculateMemory();

        std.debug.print("Lines read: {any}\n", .{i});
        std.debug.print("Time taken: {d:.3}s\n", .{elapsed_s});
        std.debug.print("Memory used: {d:.2}MB\n", .{memory_mb});
    }

    pub fn head(self: *Table) !void {
        var i: usize = self.column_start;
        while (self.indexToName.get(i)) |col_name| {
            std.debug.print("{s}\t", .{col_name});
            i += 1;
        }
        std.debug.print("\n", .{});

        for (0..5) |row| {
            i = self.column_start;
            while (self.indexToName.get(i)) |col_name| {
                if (self.columns.get(col_name)) |col_info| {
                    switch (col_info.data) {
                        .Float => |list| {
                            if (row < list.items.len) {
                                std.debug.print("{d}\t", .{list.items[row]});
                            }
                        },
                        .Int => |list| {
                            if (row < list.items.len) {
                                std.debug.print("{d}\t", .{list.items[row]});
                            }
                        },
                        .String => |list| {
                            if (row < list.items.len) {
                                std.debug.print("{s}\t", .{list.items[row]});
                            }
                        },
                    }
                }
                i += 1;
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn readCsv(file_name: []const u8) !Table {
        const file = try std.fs.cwd().openFile(file_name, .{});
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const allocator: std.mem.Allocator = arena.allocator();
        defer file.close();

        var table = Table{
            .column_start = 0,
            .allocator = allocator,
            .columns = std.StringHashMap(ColumnInfo).init(allocator),
            .indexToName = std.AutoHashMap(usize, []const u8).init(allocator),
            .len = 0,
            .file_size = try file.getEndPos(),
        };

        const validFile: bool = verifyFileType(file_name);

        if (!validFile) {
            return TableError.InvalidFileType;
        }

        var buffered_reader = std.io.bufferedReader(file.reader());
        var reader = buffered_reader.reader();

        const buffer_size = 1024 * 8192;
        const read_buffer = try table.allocator.alloc(u8, buffer_size);
        defer table.allocator.free(read_buffer);

        const estimated_rows: usize = try table.analyzeSchema(&reader, read_buffer);

        try table.parseBody(estimated_rows, file_name);
        return table;
    }
};
