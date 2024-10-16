const std = @import("std");

pub const TableError = error{ MissingHeader, OutOfMemory };

pub const Table = struct {
    allocator: std.mem.Allocator,
    arena_allocator: std.heap.ArenaAllocator,
    headers: std.ArrayListAligned([]const u8, null),
    body: std.ArrayListAligned([]const u8, null),

    pub fn init(allocator: std.mem.Allocator) Table {
        return Table{
            .allocator = allocator,
            .arena_allocator = std.heap.ArenaAllocator.init(allocator),
            .headers = std.ArrayList([]const u8).init(allocator),
            .body = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Table) void {
        self.headers.deinit();
        self.body.deinit();
        self.arena_allocator.deinit();
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

    pub fn parse(self: *Table, csv_data: []const u8) TableError!void {
        var rows = std.mem.split(u8, csv_data, "\n");
        var header = std.mem.split(u8, rows.next() orelse return TableError.MissingHeader, ",");
        var body = std.mem.split(u8, rows.rest(), ",");

        self.headers.clearAndFree();
        self.body.clearAndFree();

        while (header.next()) |key| if (key.len > 0) try self.headers.append(key);
        while (body.next()) |row| if (row.len > 0) try self.body.append(row);
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
    std.debug.print("Total lines processed: {s}\n", .{table.body.items[0..table.headers.items.len]});
}
