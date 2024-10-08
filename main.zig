const std = @import("std");

const ColumnDataPoint = struct {
    label: u8,
    pixels: [784]u8,
};

const CsvError = error{
    TooManyFields,
    InvalidFormat,
    NotEnoughFields,
};

fn appendLine(line: []u8, data: *std.ArrayList(ColumnDataPoint)) !void {
    var iter = std.mem.split(u8, std.mem.trimRight(u8, line, "\r"), ",");
    var point: ColumnDataPoint = undefined;

    // get label
    if (iter.next()) |label_val| {
        point.label = try std.fmt.parseInt(u8, label_val, 10);
    } else {
        return error.InvalidFormat;
    }

    var i: usize = 0;

    while (iter.next()) |pixel_val| : (i += 1) {
        if (i >= 784) return error.TooManyFields;
        point.pixels[i] = try std.fmt.parseInt(u8, pixel_val, 10);
    }
    if (i != 784) return error.NotEnoughFields;
    try data.append(point);
}

fn readCsv(allocator: std.mem.Allocator) ![]ColumnDataPoint {
    const file = try std.fs.cwd().openFile("data/train.csv", .{});
    defer file.close(); // close when function exits

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buffer: [8192]u8 = undefined; // store each line
    var data = std.ArrayList(ColumnDataPoint).init(allocator);
    // read current buffer, save buffer to |line| if not null
    while (try in_stream.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
        try appendLine(line, &data);
    }

    return data.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = try readCsv(allocator);
    defer allocator.free(data);

    std.debug.print("Read {} data points\n", .{data.len});
}
