const std = @import("std");

pub const TableError = error{ MissingHeader, OutOfMemory, InvalidColumn, InvalidDropAllColumns, InvalidFileType, CannotConvertStringToFloat };
const SchemaError = error{ NoHeaders, InvalidFormat };

pub const Column = union(enum) {
    Float: []f32,
    Int: []i32,
    String: [][]const u8,
};

pub const ColumnInfo = struct {
    data: Column,
    index: usize,
};

pub const Table = struct {
    columns: std.StringHashMap(ColumnInfo),
    allocator: std.mem.Allocator,
    len: usize,

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

    fn analyzeSchema(self: *Table, reader: anytype, buffer: []u8) !void {
        try self.getHeaderNames(reader, buffer);
    }

    fn getHeaderNames(self: *Table, reader: anytype, buffer: []u8) !void {
        var bytes_read = try reader.read(buffer);

        if (bytes_read == 0) {
            return SchemaError.NoHeaders;
        }

        // find end of line
        var header_data = std.ArrayList(u8).init(self.allocator);
        defer header_data.deinit();

        var found_newline = false;
        var pos: usize = 0;

        while (!found_newline) {
            while (pos < bytes_read) {
                if (buffer[pos] == '\n') {
                    found_newline = true;
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
                continue;
            }
            const col_info = ColumnInfo{
                .data = undefined,
                .index = col_index,
            };

            try self.columns.put(owned_header, col_info);
            col_index += 1;
        }
    }

    pub fn readCsv(allocator: std.mem.Allocator, file_name: []const u8) !Table {
        var table = Table{
            .allocator = allocator,
            .columns = std.StringHashMap(ColumnInfo).init(allocator),
            .len = 0,
        };

        const validFile: bool = verifyFileType(file_name);

        if (!validFile) {
            return TableError.InvalidFileType;
        }

        const file = try std.fs.cwd().openFile(file_name, .{});

        defer file.close();

        // Get total bytes of file

        // const file_size = try file.getEndPos();

        var buffered_reader = std.io.bufferedReader(file.reader());
        var reader = buffered_reader.reader();

        const buffer_size = 1024 * 1024;
        const read_buffer = try table.allocator.alloc(u8, buffer_size);
        defer table.allocator.free(read_buffer);

        try table.analyzeSchema(&reader, read_buffer);

        return table;
    }
};
