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

    fn processHeader(allocator: std.mem.Allocator, header: *std.ArrayList([]u8), line: []const u8) !void {
        var start: usize = 0;
        for (line, 0..) |c, i| {
            if (c == ',') {
                try header.append(try allocator.dupe(u8, line[start..i]));
                start = i + 1;
            }
        }
        if (start < line.len) {
            try header.append(try allocator.dupe(u8, line[start..]));
        }
    }

    fn freeTable(allocator: std.mem.Allocator, lines: *std.ArrayList([]u8), header: *std.ArrayList([]u8)) void {
        for (header.items) |item| {
            allocator.free(item);
        }
        header.deinit();

        for (lines.items) |item| {
            allocator.free(item);
        }
        lines.deinit();
    }

    fn readCsv(allocator: std.mem.Allocator, path: []const u8) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();
        var buf: [1048576]u8 = undefined;

        // used when reading a line & buff reaches the end
        var buf_offset: usize = 0;

        var total_lines: usize = 0;
        var line_start: usize = 0;

        var header = std.ArrayList([]u8).init(allocator);
        var lines = std.ArrayList([]u8).init(allocator);

        // free header & lines
        defer freeTable(allocator, &lines, &header);

        const start_time = std.time.milliTimestamp();

        while (true) {
            const bytes_read = try in_stream.readAll(buf[buf_offset..]);

            if (bytes_read == 0) break;

            const total_bytes_in_buffer = buf_offset + bytes_read;
            var line_end: usize = buf_offset;

            while (line_end < total_bytes_in_buffer) : (line_end += 1) {
                if (buf[line_end] == '\n') {
                    //const line = buf[line_start..line_end];

                    // assume line 1 is headers
                    if (total_lines == 0) {
                        //try processHeader(allocator, &header, line);
                    } else {
                        // line
                    }

                    total_lines += 1;
                    line_start = line_end + 1;
                }
            }
            // if line_start is less then totalBytes, then the line is not finisehd processing
            if (line_start < total_bytes_in_buffer) {
                buf_offset = total_bytes_in_buffer - line_start;

                for (0..buf_offset) |i| {
                    buf[i] = buf[line_start + i];
                }

                line_start = 0;
            }
            // reset buffOffset if line fully processed
            else {
                buf_offset = 0;
            }
        }
        const end_time = std.time.milliTimestamp();
        const elapsed_milliseconds = end_time - start_time;
        const elapsed_seconds = @as(f64, @floatFromInt(elapsed_milliseconds)) / 1000.0;
        std.debug.print("Time taken: {d:.3} seconds\n", .{elapsed_seconds});
        std.debug.print("Total lines processed: {d}\n", .{total_lines});
    }
};

pub fn main() !void {
    const path: []const u8 = "data/train.csv";
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try Table.readCsv(allocator, path);
}
