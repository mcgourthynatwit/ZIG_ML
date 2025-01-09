const std = @import("std");
const tensor_file = @import("tensor.zig");
const Tensor = tensor_file.Tensor;

pub const TableError = error{ MissingHeader, OutOfMemory, InvalidColumn, InvalidDropAllColumns, InvalidFileType, CannotConvertStringToFloat };

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
    allocator: std.mem.Allocator,
    body: std.ArrayList(std.ArrayList(DataPoint)),
    headers: std.StringHashMap(usize),

    // Creates empty Table struct
    pub fn initTable(allocator: std.mem.Allocator) Table {
        return Table{
            .allocator = allocator,
            .body = std.ArrayList(std.ArrayList(DataPoint)).init(allocator),
            .headers = std.StringHashMap(usize).init(allocator),
        };
    }

    pub fn deinitTable(self: *Table) void {
        var header_it = self.headers.iterator();
        while (header_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.headers.deinit();

        // Free row data
        for (self.body.items) |*row| {
            for (row.items) |data_point| {
                switch (data_point) {
                    // Free string variants
                    .String => |str| self.allocator.free(str),
                    // Numeric types don't need explicit deallocation
                    .Float, .Int => {},
                }
            }
            row.deinit();
        }
        self.body.deinit();
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

        // Create buf allocating the file size bytes
        const buffer = try self.allocator.alloc(u8, file_size);

        // Read all bytes of file & store in buffer
        const bytes_read = try file.readAll(buffer);

        std.debug.assert(bytes_read == file_size);

        errdefer self.allocator.free(buffer);

        // parse CSV
        try self.parse(buffer);
    }

    // Add header to table
    fn addHeader(self: *Table, header: []const u8) !void {
        const index = self.headers.count();

        const owned_header = try self.allocator.dupe(u8, header);
        errdefer self.allocator.free(owned_header);

        try self.headers.put(owned_header, index);
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

    fn parseDatapoint(str: []const u8, strBuffer: []u8) !DataPoint {
        if (std.fmt.parseFloat(f32, str)) |float_val| {
            return DataPoint{ .Float = float_val };
        } else |_| {
            // Try parsing as integer
            if (std.fmt.parseInt(i32, str, 10)) |int_val| {
                return DataPoint{ .Int = int_val };
            } else |_| {
                // If both fail, return as string
                @memcpy(strBuffer[0..str.len], str);
                return DataPoint{ .String = strBuffer[0..str.len] };
            }
        }
    }

    // Splits rows in csv_data by '\n', extracts the headers (Assumes first row is the header) @TODO add param that first line ISNOT header.
    // Counts num_cols then estimates the number of rows & allocates table.body arrayList.
    // Iterates through rows & adds each line to table.body.
    fn parse(self: *Table, csv_data: []const u8) TableError!void {
        // Ensure header & body are empty
        self.headers.clearAndFree();
        self.body.clearAndFree();

        var ptr_1: usize = 0;
        var ptr_2: usize = 0;

        // Find end of first line
        while (ptr_2 < csv_data.len and csv_data[ptr_2] != '\n') {
            ptr_2 += 1;
        }

        // Ensure we have a header
        if (ptr_2 <= ptr_1) {
            return TableError.MissingHeader;
        }

        try self.parseHeader(csv_data[ptr_1..ptr_2]);
        const num_cols = self.headers.count();

        // Estimated rows calculation
        const estimated_rows = csv_data.len / (num_cols * 7);
        try self.body.ensureTotalCapacity(estimated_rows);

        // preallocated row buffer
        var row = try std.ArrayList(DataPoint).initCapacity(self.allocator, num_cols);
        defer row.deinit();

        // preallocated cell buffer for strings (1024 chars)
        const cell_buffer = try self.allocator.alloc(u8, 1024);

        // Skip past header and newline
        ptr_1 = ptr_2 + 1;
        ptr_2 = ptr_1;

        // Parse body rows
        while (ptr_2 < csv_data.len) {
            if (csv_data[ptr_2] == ',') {
                if (ptr_2 > ptr_1) {
                    const cellDataPoint = try parseDatapoint(csv_data[ptr_1..ptr_2], cell_buffer);
                    try row.append(cellDataPoint);
                }
                ptr_1 = ptr_2 + 1; // Skip past the comma
            } else if (csv_data[ptr_2] == '\n') {
                if (ptr_2 > ptr_1) {
                    const cellDataPoint = try parseDatapoint(csv_data[ptr_1..ptr_2], cell_buffer);
                    try row.append(cellDataPoint);
                }
                if (row.items.len > 0) {
                    try self.body.append(try row.clone());
                    row.clearRetainingCapacity();
                }
                ptr_1 = ptr_2 + 1; // Skip past the newline
            }
            ptr_2 += 1;
        }

        // Handle last row if it doesn't end with a newline
        if (ptr_2 > ptr_1) {
            const cellDataPoint = try parseDatapoint(csv_data[ptr_1..ptr_2], cell_buffer);
            try row.append(cellDataPoint);
            try self.body.append(try row.clone());
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
    fn addFilteredRow(allocator: std.mem.Allocator, line: std.ArrayList(DataPoint), cols: std.AutoHashMap(usize, void), row: *std.ArrayList(DataPoint)) !void {
        for (0.., line.items) |idx, cell| {
            if (cols.contains(idx)) {
                const new_cell = switch (cell) {
                    .String => |str| DataPoint{ .String = try allocator.dupe(u8, str) },
                    .Float => |f| DataPoint{ .Float = f },
                    .Int => |i| DataPoint{ .Int = i },
                };
                try row.append(new_cell);
            }
        }
    }

    // @TODO There is certainly some way to optimize this, zig can utilize c++ API wonder if we can integrate CUDA
    // Returns a new Table that is subset of input table containing filtered rows
    pub fn filterTable(self: *Table, allocator: std.mem.Allocator, cols: []const []const u8) !Table {
        if (cols.len == 0 or cols.len > self.headers.count()) {
            const err = error.InvalidColumn;

            std.debug.print("Error occured: {!} of table with shape {d}{d}\n", .{ err, self.headers.count(), self.body.items.len });
            return TableError.InvalidColumn;
        }

        // Hashmap to store col index for quick lookup
        var filter_map = std.AutoHashMap(usize, void).init(allocator);
        defer filter_map.deinit();

        // Iterate through passed array and fill in hashmap
        for (cols) |col| {
            if (!self.headerExists(col)) {
                const err = error.InvalidColumn;

                std.debug.print("Error occured: {!} of table with shape {d} X {d}, column: {s} DNE\n", .{ err, self.headers.count(), self.body.items.len, col });
                return TableError.InvalidColumn;
            }
            const colIdx = try self.getHeaderIdx(col);
            try filter_map.put(colIdx, {});
        }

        // Init filtered table struct
        var filtered_table = Table.initTable(allocator);

        var headers = try self.allocator.alloc(HeaderEntry, self.headers.count());
        defer self.allocator.free(headers);

        // Sort headers by index
        try self.sortHeaders(&headers);

        // Put filtered headers into filter Table
        for (headers) |header| {
            if (filter_map.contains(header.index)) {
                const owned_header = try allocator.dupe(u8, header.header);

                try filtered_table.addHeader(owned_header);
            }
        }

        const num_cols = cols.len;

        // Estimated rows = total bytes / (cols * 7) ~ 7 is a an estimate of num bytes per cell this can be changed as testing proceeds
        const estimated_rows = self.body.items.len / (num_cols * 7);

        // Allocate estimate
        try filtered_table.body.ensureTotalCapacity(estimated_rows);

        // Store row data that will be appened onto self.body
        var row = try std.ArrayList(DataPoint).initCapacity(allocator, num_cols);
        defer row.deinit();

        // Iterate through rows of original table and use helper func to process & append
        for (self.body.items) |unfiltered_row| {
            try addFilteredRow(allocator, unfiltered_row, filter_map, &row);

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
        const new_table: Table = try self.filterTable(allocator, remaining_cols.items);
        errdefer new_table.deinitTable();

        return new_table;
    }

    // Encodes a categorical column based on uniqueness 1-n (n is unique values in col)
    pub fn encode(self: *Table, cols: []const []const u8) !void {
        for (cols) |col| {
            // Check if column exists
            const colIdx = try self.getHeaderIdx(col);

            // Initialize hashmap for unique values
            var unique_values = std.StringHashMap(usize).init(self.allocator);
            defer unique_values.deinit();

            // First pass: collect unique values and assign encodings
            var next_encoding: usize = 0;

            for (self.body.items) |row| {
                const val = &row.items[colIdx];
                // We can only encode string values
                if (val.* != .String) continue;

                const str_val = val.*.String;

                if (!unique_values.contains(str_val)) {
                    try unique_values.put(str_val, next_encoding);

                    val.* = DataPoint{ .Int = @intCast(next_encoding) };
                    next_encoding += 1;
                } else {
                    const encoding_opt = unique_values.get(str_val);
                    self.allocator.free(str_val);

                    val.* = DataPoint{ .Int = @intCast(encoding_opt.?) };
                }
            }

            var it = unique_values.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
        }
    }

    // Converts table to a tensor for matrix operations
    pub fn tableToTensor(self: *Table) !Tensor {
        // Allocate flat array for tensor data
        const rows = self.body.items.len;
        const cols = self.headers.count();
        var flat_data = try self.allocator.alloc(f32, rows * cols);

        // Convert each DataPoint to f32
        for (self.body.items, 0..) |row, i| {
            for (row.items, 0..) |value, j| {
                flat_data[i * cols + j] = switch (value) {
                    .Float => |f| f,
                    .Int => |n| @floatFromInt(n),
                    .String => {
                        return TableError.CannotConvertStringToFloat;
                    },
                };
            }
        }
        defer self.allocator.free(flat_data);
        return Tensor.initTensor(self.allocator, rows, cols, flat_data);
    }
};
