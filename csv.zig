const std = @import("std");

pub const TableError = error{ MissingHeader, OutOfMemory };

pub const Table = struct {
    allocator: std.mem.Allocator,
    headers: std.ArrayListAligned([]const u8, null),
    body: std.ArrayListAligned(std.ArrayList([]const u8), null),

    // Creates empty Table struct
    pub fn init(allocator: std.mem.Allocator) Table {
        return Table{
            .allocator = allocator,
            .headers = std.ArrayList([]const u8).init(allocator),
            .body = std.ArrayList(std.ArrayList([]const u8)).init(allocator),
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

    // Helper for parse()
    // Gets the headers of the CSV and directly appends those to self.headers
    pub fn parseHeader(self: *Table, header_line: []const u8) !void {
        var header_items = std.mem.split(u8, header_line, ",");
        self.headers.clearAndFree();
        while (header_items.next()) |item| {
            // Trim any unecessary text
            const trimmed_item = std.mem.trim(u8, item, " \r\n");

            // Append to headers
            try self.headers.append(trimmed_item);
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

        const num_cols = self.headers.items.len;

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
        if (self.headers.items.len == 0) {
            return TableError.MissingHeader;
        }

        const n: usize = @min(5, self.body.items.len);

        std.debug.print("{s}\n", .{self.headers.items});
        for (0..n) |i| {
            std.debug.print("{s}\n", .{self.body.items[i].items});
        }
    }

    // Takes in table struct
    // Returns a 2d char array of the headers [header_idx][header_char_array]
    pub fn columns(self: *Table) [][]const u8 {
        return self.headers.items;
    }

    // Takes in table struct
    // Prints out the number of rows & number of columns.
    pub fn shape(self: *Table) void {
        std.debug.print("{d} rows\n", .{self.body.items.len});
        std.debug.print("{d} columns\n", .{self.headers.items.len});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const csv_data = try Table.readCsv(allocator, "data/train.csv");
    defer allocator.free(csv_data);

    var table: Table = Table.init(allocator);
    defer table.deinit();

    const start_time = std.time.milliTimestamp();

    try table.parse(csv_data);

    const end_time = std.time.milliTimestamp();
    const elapsed_milliseconds = end_time - start_time;
    const elapsed_seconds = @as(f64, @floatFromInt(elapsed_milliseconds)) / 1000.0;
    std.debug.print("Time taken: {d:.3} seconds\n", .{elapsed_seconds});
    table.shape();
}
