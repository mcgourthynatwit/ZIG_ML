const std = @import("std");

pub const Table = struct {
    pub const CsvType = union(enum) {
        int: i64,
        float: f64,
        string: []const u8,
        boolean: bool,
    };

    rows: usize,
    cols: usize,
    labels: []*u8,
    data: [][]CsvType,

    fn processLine(i: usize, line: []u8) !void {
        std.debug.print("Line {d} ", .{i});

        for (line) |char| {
            std.debug.print("{c}", .{char});
        }
    }

    fn processHeader(allocator: std.mem.Allocator, header: *std.ArrayList([]const u8), line: []const u8) !void {
        var start: usize = 0;
        for (line, 0..) |c, i| {
            if (c == ',') {
                try header.append(try allocator.dupe(u8, line[start..i]));
                start = i + 1;
            }
        }
        // Don't forget the last field
        if (start < line.len) {
            try header.append(try allocator.dupe(u8, line[start..]));
        }
    }

    fn readCsv(allocator: std.mem.Allocator, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        // 1 MB buff
        var buf: [1048576]u8 = undefined;
        var totalLines: usize = 0;
        var lineStart: usize = 0;
        var i: usize = 0;

        const start_time = std.time.milliTimestamp();

        while (true) {
            i = 0;
            const bytes_read = try in_stream.readAll(&buf);
            if (bytes_read == 0) break;

            while (i < bytes_read) : (i += 1) {
                if (buf[i] == '\n') {
                    const line = buf[lineStart..i];

                    // header
                    if (totalLines == 0) {
                        var header = std.ArrayList([]const u8).init(allocator);
                        defer {
                            for (header.items) |item| {
                                allocator.free(item);
                            }
                            header.deinit();
                        }

                        try processHeader(allocator, &header, line);
                        for (header.items) |field| {
                            std.debug.print("{s} ", .{field});
                        }
                        return;
                    } else if (lineStart < i) {
                        try processLine(totalLines, line);
                    } else {
                        // some error
                    }

                    totalLines += 1;
                    lineStart = i;
                }
            }
        }
        const end_time = std.time.milliTimestamp();
        const elapsed_milliseconds = end_time - start_time;

        const elapsed_seconds = @as(f64, @floatFromInt(elapsed_milliseconds)) / 1000.0;
        std.debug.print("Time taken: {d:.3} seconds\n", .{elapsed_seconds});
        std.debug.print("Total lines processed: {d}\n", .{totalLines});
    }
};

pub fn main() !void {
    const path: []const u8 = "data/train.csv";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try Table.readCsv(allocator, path);
}