const std = @import("std");
const tensor_file = @import("tensor.zig");
const Tensor = tensor_file.Tensor;

pub const TableError = error{ MissingHeader, OutOfMemory, InvalidColumn, InvalidDropAllColumns, InvalidFileType };

const HeaderEntry = struct {
    header: []const u8,
    index: usize,
};

pub const DataPoint = union(enum) {
    Float: f32,
    Int: i32,
    String: []const u8,
};

// @TODO adjust Table & add enum to handle floats
pub const Table = struct {
    source_data: ?[]const u8,
    allocator: std.mem.Allocator,
    body: std.ArrayList(std.ArrayList(DataPoint)),
    headers: std.StringHashMap(usize),

    // Creates empty Table struct
    pub fn initTable(allocator: std.mem.Allocator) Table {
        return Table{
            .source_data = null,
            .allocator = allocator,
            .body = std.ArrayList(std.ArrayList(DataPoint)).init(allocator),
            .headers = std.StringHashMap(usize).init(allocator),
        };
    }

    pub fn deinitTable(self: *Table) void {
        // For original that holds buffer in source_data
        if (self.source_data) |data| {
            self.allocator.free(data);

            // Header & Data are slices of source_data, just need to free the ArrayList not the individual strings
            var header_it = self.headers.iterator();
            while (header_it.next()) |entry| {
                _ = entry;
            }
            self.headers.deinit();

            for (self.body.items) |*row| {
                row.deinit();
            }
            self.body.deinit();
        }
        // For filtered that are duplicates in different memory then original, need to individaully free header and body strings
        else {
            var header_it = self.headers.iterator();
            while (header_it.next()) |entry| {
                // Free the header strings
                self.allocator.free(entry.key_ptr.*);
            }
            self.headers.deinit();

            for (self.body.items) |*row| {
                for (row.items) |data_point| {
                    switch (data_point) {
                        // For String variants, we need to free the string
                        .String => |str| self.allocator.free(str),
                        // Other variants don't need explicit deallocation
                        .Float, .Int => {},
                    }
                }
                row.deinit();
            }
            self.body.deinit();
        }
    }

    fn verifyFileType(file_name: []const u8) bool {
        const extension_index = std.mem.lastIndexOf(u8, file_name, ".");
        if (extension_index == null) {
            return false;
        }

        // Get the extension (everything after the last '.')
        const extension = file_name[extension_index.?..];

        // Check if the extension is ".csv"
        if (!std.mem.eql(u8, extension, ".csv")) {
            return false;
        }

        return true;
    }
    // Opens file that is passed, gets the number of bytes in the file and creates char [] buffer that holds ENTIRE CSV
    // @TODO may need to optimize as reading the ENTIRE buffer and storing that in single array will be inefficient for very large files.
    // @TODO ensure that table is empty when reading
    pub fn readCsvTable(self: *Table, file_name: []const u8) !void {
        const validFile: bool = verifyFileType(file_name);

        if (!validFile) {
            return TableError.InvalidFileType;
        }

        const file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();

        // Get total bytes of file
        const file_size = try file.getEndPos();

        // @TODO May want to change this to throw an error but if reading an empty CSV simply returns as the table passed to readCsv is empty
        if (file_size == 0) {
            return;
        }

        if (self.source_data) |old_data| {
            self.allocator.free(old_data);
            self.source_data = null;
        }

        // Create buf allocating the file size bytes
        const buffer = try self.allocator.alloc(u8, file_size);

        // Read all bytes of file & store in buffer
        const bytes_read = try file.readAll(buffer);

        std.debug.assert(bytes_read == file_size);

        self.source_data = buffer;
        errdefer self.allocator.free(buffer);

        // parse CSV
        try self.parse(buffer);
    }

    // Add header to table
    fn addHeader(self: *Table, header: []const u8) !void {
        const index = self.headers.count();
        try self.headers.put(header, index);
    }

    // Helper for parse()
    // Gets the headers of the CSV and directly appends those to self.headers
    fn parseHeader(self: *Table, header_line: []const u8) !void {
        var header_items = std.mem.split(u8, header_line, ",");
        self.headers.clearAndFree();
        while (header_items.next()) |item| {
            // Trim any unecessary text
            const trimmed_item = std.mem.trim(u8, item, " \r\n");

            try self.addHeader(trimmed_item);
        }
    }

    fn parseDatapoint(str: []const u8) !DataPoint {
        if (std.fmt.parseFloat(f32, str)) |float_val| {
            return DataPoint{ .Float = float_val };
        } else |_| {
            // Try parsing as integer
            if (std.fmt.parseInt(i32, str, 10)) |int_val| {
                return DataPoint{ .Int = int_val };
            } else |_| {
                // If both fail, return as string
                return DataPoint{ .String = str };
            }
        }
    }

    // Helper for parse()
    // Splits the line passed by "," & iterates through this split char array trimming any unecessary text ("\t\r\n") & appends to row.
    fn parseLine(line: []const u8, row: *std.ArrayList(DataPoint)) !void {
        var it = std.mem.split(u8, line, ",");
        while (it.next()) |field| {
            // Trim any unecessary text
            const trimmed: []const u8 = std.mem.trim(u8, field, " \t\r\n");
            const trimmedDataPoint: DataPoint = try parseDatapoint(trimmed);
            try row.append(trimmedDataPoint);
        }
    }

    // Splits rows in csv_data by '\n', extracts the headers (Assumes first row is the header) @TODO add param that first line ISNOT header.
    // Counts num_cols then estimates the number of rows & allocates table.body arrayList.
    // Iterates through rows & adds each line to table.body.
    fn parse(self: *Table, csv_data: []const u8) TableError!void {
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
        var row = try std.ArrayList(DataPoint).initCapacity(self.allocator, num_cols);
        defer row.deinit();

        while (rows.next()) |line| {
            if (std.mem.trim(u8, line, " \r\n").len == 0) continue;
            try parseLine(line, &row);

            // Append clone of row & clear row for next iteration
            try self.body.append(try row.clone());
            row.clearRetainingCapacity();
        }
    }

    fn printDataPoint(dp: []DataPoint) void {
        for (dp) |data| {
            switch (data) {
                .Float => |f| std.debug.print("{d} ", .{f}),
                .Int => |i| std.debug.print("{d} ", .{i}),
                .String => |s| std.debug.print("{s} ", .{s}),
            }
        }
        std.debug.print("\n", .{});
    }

    // Takes in table struct
    // Prints out the columns & the first 5 rows of the table
    // @TODO : Formatting this output for really long rows
    pub fn headTable(self: *Table) !void {
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
            printDataPoint(self.body.items[i].items);
        }
    }

    // Takes in table struct
    // Returns a 2d char array of the headers [header_idx][header_char_array]
    pub fn columns(self: *Table) !void {
        // allocate array to sort
        var headers = try self.allocator.alloc(HeaderEntry, self.headers.count());
        defer self.allocator.free(headers);

        // sort headers by index
        try self.sortHeaders(&headers);

        for (headers) |header| {
            std.debug.print("{s} \n", .{header.header});
        }
    }

    // Takes in table struct
    // Prints out the number of rows & number of columns.
    pub fn shapeTable(self: *Table) void {
        std.debug.print("{d} rows\n", .{self.body.items.len});
        std.debug.print("{d} columns\n", .{self.headers.count()});
    }

    // Check to see if header exists in table
    fn headerExists(self: *Table, header: []const u8) bool {
        return self.headers.contains(header);
    }

    // Helper function for head or when printing out, since hashmap does not store the
    // headers in the order they where added we need to sort and print.
    fn sortHeaders(self: *Table, headers: *[]HeaderEntry) !void {
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
                return a.index < b.index;
            }
        };

        // built in func to sort using compareByIndex to specify sorting by index
        std.mem.sort(HeaderEntry, headers.*, {}, compare.compareByIndex);
    }

    // Helper function for filter that parses a row of an original table and only appends the cells in specified cols
    fn addFilteredRow(allocator: std.mem.Allocator, line: std.ArrayList([]const u8), cols: std.AutoHashMap(usize, void), row: *std.ArrayList([]const u8)) !void {
        for (0.., line.items) |idx, cell| {
            if (cols.contains(idx)) {
                const owned_cell = try allocator.dupe(u8, cell);

                try row.append(owned_cell);
            }
        }
    }

    // @TODO There is certainly some way to optimize this, zig can utilize c++ API wonder if we can integrate CUDA
    // Returns a new Table that is subset of input table containing filtered rows
    pub fn filterTable(self: *Table, allocator: std.mem.Allocator, cols: []const []const u8) !Table {
        if (cols.len == 0 or cols.len > self.headers.count()) {
            return TableError.InvalidColumn;
        }

        // Hashmap to store col index for quick lookup
        var filter_map = std.AutoHashMap(usize, void).init(self.allocator);
        defer filter_map.deinit();

        // Iterate through passed array and fill in hashmap
        for (cols) |col| {
            if (!self.headerExists(col)) {
                return TableError.InvalidColumn;
            }
            const colIdx = try self.getHeaderIdx(col);
            try filter_map.put(colIdx, {});
        }

        // Init filtered table struct
        var filtered_table = Table.init(allocator);

        var headers = try self.allocator.alloc(HeaderEntry, self.headers.count());
        defer self.allocator.free(headers);

        // Sort headers by index
        try self.sortHeaders(&headers);

        // Put filtered headers into filter Table
        for (headers) |header| {
            if (filter_map.contains(header.index)) {
                const owned_header = try self.allocator.dupe(u8, header.header);

                try filtered_table.addHeader(owned_header);
            }
        }

        const num_cols = cols.len;

        // Estimated rows = total bytes / (cols * 7) ~ 7 is a an estimate of num bytes per cell this can be changed as testing proceeds
        const estimated_rows = self.body.items.len / (num_cols * 7);

        // Allocate estimate
        try filtered_table.body.ensureTotalCapacity(estimated_rows);

        // Store row data that will be appened onto self.body
        var row = try std.ArrayList([]const u8).initCapacity(self.allocator, num_cols);
        defer row.deinit();

        // Iterate through rows of original table and use helper func to process & append
        for (self.body.items) |unfiltered_row| {
            try addFilteredRow(self.allocator, unfiltered_row, filter_map, &row);

            try filtered_table.body.append(try row.clone());
            row.clearRetainingCapacity();
        }

        return filtered_table;
    }

    // Gets the index of the header of a table
    fn getHeaderIdx(self: *Table, col: []const u8) !usize {
        if (self.headers.get(col)) |idx| {
            return idx;
        }

        return TableError.InvalidColumn;
    }

    // Drops specified cols of a table returning a new table
    pub fn dropColumnTable(self: *Table, allocator: std.mem.Allocator, cols: []const []const u8) !Table {
        const dropped_num: usize = cols.len;
        if (dropped_num == 0 or dropped_num > self.headers.count()) {
            return TableError.InvalidColumn;
        }

        // Create a map to track indices to drop
        var drop_map = std.AutoHashMap(usize, void).init(allocator);
        defer drop_map.deinit();

        // Validate columns and collect their indices
        for (cols) |col| {
            if (!self.headerExists(col)) {
                return TableError.InvalidColumn;
            }
            const colIdx = try self.getHeaderIdx(col);
            try drop_map.put(colIdx, {});
        }

        // If they try and drop all raise error
        if (drop_map.count() == self.headers.count()) {
            return TableError.InvalidDropAllColumns;
        }

        // Else build out array of remaining columns
        var remaining_cols = std.ArrayList([]const u8).init(allocator);
        defer {
            for (remaining_cols.items) |item| {
                allocator.free(item);
            }
            remaining_cols.deinit();
        }

        var header_iter = self.headers.iterator();

        // Collect remaining columns
        while (header_iter.next()) |entry| {
            const idx = entry.value_ptr.*;
            if (!drop_map.contains(idx)) {
                try remaining_cols.append(try allocator.dupe(u8, entry.key_ptr.*));
            }
        }

        // call filter with remaining columns
        const new_table: Table = try self.filter(allocator, remaining_cols.items);
        errdefer new_table.deinit();

        return new_table;
    }

    // @TODO
    // Converts table to a matrix for matrix operations
    //pub fn toMatrix(self: *Table) !Matrix {}
};
