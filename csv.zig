const std = @import("std");

pub const TableError = error{ MissingHeader, OutOfMemory };

pub const Table = struct {
    allocator: std.mem.Allocator,
    arena_allocator: std.heap.ArenaAllocator,
    headers: std.ArrayListAligned([]const u8, null),
    body: std.ArrayListAligned(std.ArrayList([]const u8), null),

    pub fn init(allocator: std.mem.Allocator) Table {
        return Table{
            .allocator = allocator,
            .arena_allocator = std.heap.ArenaAllocator.init(allocator),
            .headers = std.ArrayList([]const u8).init(allocator),
            .body = std.ArrayList(std.ArrayList([]const u8)).init(allocator),
        };
    }

    pub fn deinit(self: *Table) void {
        self.headers.deinit();

        for (self.body.items) |*row| {
            row.deinit();
        }
        self.body.deinit();
    }

    pub fn readCsv(allocator: std.mem.Allocator, file_name: []const u8) ![]const u8 {
        const file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();

        const file_size = try file.getEndPos();

        const buffer = try allocator.alloc(u8, file_size);
        errdefer allocator.free(buffer);

        const bytes_read = try file.readAll(buffer);

        std.debug.assert(bytes_read == file_size);

        return buffer;
    }

    pub fn parseHeader(self: *Table, header_line: []const u8) !void {
        var header_items = std.mem.split(u8, header_line, ",");
        self.headers.clearAndFree();
        while (header_items.next()) |item| {
            const trimmed_item = std.mem.trim(u8, item, " \r\n");
            try self.headers.append(trimmed_item);
        }
    }

    fn parseLine(self: *Table, line: []const u8, num_cols: usize, row: *std.ArrayList([]const u8)) !void {
        var it = std.mem.split(u8, line, ",");
        while (it.next()) |field| {
            const trimmed = std.mem.trim(u8, field, " \t\r\n");
            try row.append(trimmed);
        }

        // Pad with empty strings if necessary
        while (row.items.len < num_cols) {
            try row.append(try self.allocator.dupe(u8, ""));
        }
    }

    pub fn parse(self: *Table, csv_data: []const u8) TableError!void {
        var rows = std.mem.split(u8, csv_data, "\n");

        self.headers.clearAndFree();
        self.body.clearAndFree();

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

        var row = try std.ArrayList([]const u8).initCapacity(self.allocator, num_cols);
        defer row.deinit();

        while (rows.next()) |line| {
            if (std.mem.trim(u8, line, " \r\n").len == 0) continue;
            try self.parseLine(line, num_cols, &row);
            try self.body.append(try row.clone());
            row.clearRetainingCapacity(); // clear row for next iteration
        }
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
    std.debug.print("Row 1 {s}\n", .{table.body.items[0].items});
}
