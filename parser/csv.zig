const std = @import("std");
const verifyFileType = @import("utils/verifyFile.zig").verifyFileType;
const calculateMemory = @import("utils/performance.zig").calculateMemory;
const calculateTime = @import("utils/performance.zig").measureElapsedTime;

const CsvParser = @import("utils/csv_parser.zig");

pub const TableError = error{ MissingHeader, OutOfMemory, InvalidColumn, InvalidDropAllColumns, InvalidFileType, CannotConvertStringToFloat };
pub const ParseError = error{MismatchLen};
pub const SchemaError = error{ NoHeaders, InvalidFormat, NoData };

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

const BufferConfig = struct {
    const BUFFER_SIZE: comptime_int = 8092 * 1024;
    const READ_BUFFER_SIZE: comptime_int = 1024 * 8192;
};

pub const Table = struct {
    column_start: usize, // which col starts current implementation ignores index so this is either 0(no idx) or 1
    columns: std.StringHashMap(ColumnInfo),
    indexToName: std.AutoHashMap(usize, []const u8), // maps col idx to name
    allocator: std.mem.Allocator,
    len: usize,
    file_size: usize,

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
        const result = try CsvParser.getHeaderData(self.allocator, buffer, reader);

        try CsvParser.saveColumnNames(self, result.header_data);

        return result.remaining_buffer;
    }

    fn getColumnDtype(self: *Table, reader: anytype, buffer: []u8) !usize {
        var remaining_buffer: []const u8 = try self.getHeaderNames(reader, buffer);

        var bytes_read = remaining_buffer.len;

        if (bytes_read == 0) {
            bytes_read = try reader.read(buffer);

            // file has no rows
            if (bytes_read == 0) {
                return 0;
            }

            remaining_buffer = buffer[0..bytes_read];
        }

        var line_data = std.ArrayList(u8).init(self.allocator);
        defer line_data.deinit();

        var found_newline = false;
        var pos: usize = 0;
        var first_row_size: usize = 0;

        // Get first line data
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

        try CsvParser.saveColumnDtype(self, line_data);

        // estimate num rows
        const estimated_rows = self.file_size / first_row_size;
        return estimated_rows;
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

    inline fn parseLine(self: *Table, line: []u8, expected_cols: usize) !void {
        try CsvParser.splitAndAppendLine(self, line, expected_cols, self.column_start);

        return;
    }

    fn parseBody(self: *Table, estimated_rows: usize, file_name: []const u8) !void {
        const start_time = std.time.nanoTimestamp();
        try self.initCols(estimated_rows);

        const file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();

        var buffered_reader = std.io.bufferedReader(file.reader());
        var reader = buffered_reader.reader();

        var buf = try self.allocator.alignedAlloc(u8, @alignOf(u8), BufferConfig.BUFFER_SIZE);
        defer self.allocator.free(buf);

        var remaining = std.ArrayListAligned(u8, @alignOf(u8)).init(self.allocator);
        defer remaining.deinit();

        // Skip header
        if (reader.readUntilDelimiter(buf, '\n')) |_| {
            // Header was read successfully, continue with body
        } else |err| {
            // This is fine just means there's no body (no \n char on header line)
            if (err == error.EndOfStream) {
                return;
            }
            return err;
        }

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

        const elapsed_s = calculateTime(start_time);
        const memory_mb: f64 = try calculateMemory(self);

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

    pub fn printCols(self: *Table) !void {
        var i: usize = self.column_start;

        while (self.indexToName.get(i)) |col_name| {
            std.debug.print("{s}\n", .{col_name});
            i += 1;
        }
    }

    pub fn shape(self: *Table) !void {
        const num_cols: usize = self.columns.count();
        const first_col = self.indexToName.get(self.column_start) orelse {
            return error.NoColumns;
        };

        const col_info = self.columns.get(first_col) orelse {
            return error.ColumnNotFound;
        };

        const num_rows: usize = switch (col_info.data) {
            .Int => |arr| arr.items.len,
            .Float => |arr| arr.items.len,
            .String => |arr| arr.items.len,
        };
        std.debug.print("{} columns x {} rows\n", .{ num_cols, num_rows });
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
