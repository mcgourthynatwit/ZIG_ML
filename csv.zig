const std = @import("std");
const Matrix = @import("matrix.zig");

pub const TableError = error{ MissingHeader, OutOfMemory, InvalidColumn };

const HeaderEntry = struct {
    header: []const u8,
    index: usize,
};

pub const Table = struct {
    allocator: std.mem.Allocator,
    body: std.ArrayListAligned(std.ArrayList([]const u8), null),
    headers: std.StringHashMap(usize),

    // Creates empty Table struct
    pub fn init(allocator: std.mem.Allocator) Table {
        return Table{
            .allocator = allocator,
            .body = std.ArrayList(std.ArrayList([]const u8)).init(allocator),
            .headers = std.StringHashMap(usize).init(allocator),
        };
    }

    // Free's memory stored in the ArrayLists of headers & body of table
    pub fn deinit(self: *Table) void {
        self.headers.deinit();

        for (self.body.items) |*row| {
            row.deinit();
        }
        self.body.deinit();
    }

    // Opens file that is passed, gets the number of bytes in the file and creates char [] buffer that holds ENTIRE CSV
    // @TODO may need to optimize as reading the ENTIRE buffer and storing that in single array will be inefficient for very large files.
    pub fn readCsv(allocator: std.mem.Allocator, file_name: []const u8) ![]const u8 {
        const file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();

        // Get total bytes of file
        const file_size = try file.getEndPos();

        // Create buf allocating the file size bytes
        const buffer = try allocator.alloc(u8, file_size);
        errdefer allocator.free(buffer);

        // Read all bytes of file & store in buffer
        const bytes_read = try file.readAll(buffer);

        std.debug.assert(bytes_read == file_size);

        return buffer;
    }

    pub fn addHeader(self: *Table, header: []const u8) !void {
        const index = self.headers.count();
        try self.headers.put(header, index);
    }

    // Helper for parse()
    // Gets the headers of the CSV and directly appends those to self.headers
    pub fn parseHeader(self: *Table, header_line: []const u8) !void {
        var header_items = std.mem.split(u8, header_line, ",");
        self.headers.clearAndFree();
        while (header_items.next()) |item| {
            // Trim any unecessary text
            const trimmed_item = std.mem.trim(u8, item, " \r\n");

            // Append to headers
            try self.addHeader(trimmed_item);
        }
    }

    // Helper for parse()
    // Splits the line passed by "," & iterates through this split char array trimming any unecessary text ("\t\r\n") & appends to row.
    fn parseLine(self: *Table, line: []const u8, num_cols: usize, row: *std.ArrayList([]const u8)) !void {
        var it = std.mem.split(u8, line, ",");
        while (it.next()) |field| {
            // Trim any unecessary text
            const trimmed = std.mem.trim(u8, field, " \t\r\n");

            // Append to row
            try row.append(trimmed);
        }

        // Pad with empty strings if necessary
        while (row.items.len < num_cols) {
            try row.append(try self.allocator.dupe(u8, ""));
        }
    }

    // Splits rows in csv_data by '\n', extracts the headers (Assumes first row is the header) @TODO add param that first line ISNOT header.
    // Counts num_cols then estimates the number of rows & allocates table.body arrayList.
    // Iterates through rows & adds each line to table.body.
    pub fn parse(self: *Table, csv_data: []const u8) TableError!void {
        // Split by delimiter of row
        var rows = std.mem.split(u8, csv_data, "\n");

        // Ensure header & body are empty
        self.headers.clearAndFree();
        self.body.clearAndFree();

        // Assume first row is header and parse headers using parseHeader()
        if (rows.next()) |header_line| {
            try self.parseHeader(header_line);
        } else {
            return TableError.MissingHeader;
        }

        const num_cols = self.headers.count();

        // Estimated rows = total bytes of buffer / (cols * 7) ~ 7 is a an estimate of num bytes per cell this can be changed as testing proceeds
        const estimated_rows = csv_data.len / (num_cols * 7);

        // Allocate estimate
        try self.body.ensureTotalCapacity(estimated_rows);

        // Store row data that will be appened onto self.body
        var row = try std.ArrayList([]const u8).initCapacity(self.allocator, num_cols);
        defer row.deinit();

        while (rows.next()) |line| {
            if (std.mem.trim(u8, line, " \r\n").len == 0) continue;
            try self.parseLine(line, num_cols, &row);

            // Append clone of row & clear row for next iteration
            try self.body.append(try row.clone());
            row.clearRetainingCapacity();
        }
    }

    // Takes in table struct
    // Prints out the columns & the first 5 rows of the table
    // @TODO : Formatting this output for really long rows
    pub fn head(self: *Table) !void {
        if (self.headers.count() == 0) {
            return TableError.MissingHeader;
        }

        const n: usize = @min(5, self.body.items.len);

        // allocate array to sort
        var headers = try self.allocator.alloc(HeaderEntry, self.headers.count());
        defer self.allocator.free(headers);

        // sort headers by index
        try self.sortHeaders(&headers);

        for (headers) |header| {
            std.debug.print("{s} ", .{header.header});
        }
        std.debug.print("\n", .{});

        for (0..n) |i| {
            std.debug.print("\n{s}", .{self.body.items[i].items});
        }
    }

    // Takes in table struct
    // Returns a 2d char array of the headers [header_idx][header_char_array]
    pub fn columns(self: *Table) [][]const u8 {
        return self.headers.count();
    }

    // Takes in table struct
    // Prints out the number of rows & number of columns.
    pub fn shape(self: *Table) void {
        std.debug.print("{d} rows\n", .{self.body.items.len});
        std.debug.print("{d} columns\n", .{self.headers.count()});
    }

    pub fn headerExists(self: *Table, header: []const u8) bool {
        return self.headers.contains(header);
    }

    // Helper function for head or when printing out, since hashmap does not store the
    // headers in the order they where added we need to sort and print.
    pub fn sortHeaders(self: *Table, headers: *[]HeaderEntry) !void {
        var it = self.headers.iterator();
        var i: usize = 0;

        // populate headers with {header, index}
        while (it.next()) |entry| {
            headers.*[i] = HeaderEntry{ .header = entry.key_ptr.*, .index = entry.value_ptr.* };
            i += 1;
        }

        // compare by index
        const compare = struct {
            fn compareByIndex(_: void, a: HeaderEntry, b: HeaderEntry) bool {
                if (a.index < b.index) {
                    return true;
                } else {
                    return false;
                }
            }
        };

        // built in func to sort using compareByIndex to specify sorting by index
        std.mem.sort(HeaderEntry, headers.*, {}, compare.compareByIndex);
    }

    // @TODO
    // Returns a new Table that is subset of input table containing filtered rows
    pub fn filter(self: *Table, allocator: std.mem.Allocator, cols: []const []const u8) !Table {
        var filter_map = std.AutoHashMap(usize, void).init(self.allocator);
        defer filter_map.deinit();

        for (cols) |col| {
            if (!self.headerExists(col)) {
                return TableError.InvalidColumn;
            }
            const colIdx = try self.getHeaderIdx(col);
            try filter_map.put(colIdx, {});
        }

        var FilteredTable = Table.init(allocator);

        var headers = try self.allocator.alloc(HeaderEntry, self.headers.count());
        defer self.allocator.free(headers);

        // sort headers by index
        try self.sortHeaders(&headers);

        for (headers) |header| {
            if (filter_map.contains(header.index)) {
                try FilteredTable.addHeader(header.header);
            }
        }

        return FilteredTable;

        // sort old headers

        // put headers into filteredTable

        // iterate through rows and append to each

    }

    pub fn getHeaderIdx(self: *Table, col: []const u8) !usize {
        if (self.headers.get(col)) |idx| {
            return idx;
        }

        return TableError.InvalidColumn;
    }

    // @TODO
    // Drops specified cols of a table inplace
    pub fn drop(self: *Table, cols: [][]u8) !void {
        const dropped_num: usize = cols.len;
        var drop_map = std.AutoHashMap(dropped_num, void).init(self.allocator);
        defer drop_map.deinit();

        for (cols) |col| {
            if (!self.headerExists(col)) {
                return TableError.InvalidColumn;
            }
            const colIdx = try self.getHeaderIdx(col);
            drop_map.put(colIdx);
        }
    }

    // @TODO
    // Converts table to a matrix for matrix operations
    //pub fn toMatrix(self: *Table) !Matrix {}
};
