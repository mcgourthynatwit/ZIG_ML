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

// Returns an [n x 1] array holdings the features for each input
fn getY(allocator: std.mem.Allocator, data: []ColumnDataPoint) ![]u8 {
    const length = data.len;
    var Y = try allocator.alloc(u8, length);

    for (data, 0..) |datapoint, i| {
        Y[i] = datapoint.label;
    }

    return Y;
}

fn transpose(allocator: std.mem.Allocator, data: []ColumnDataPoint) ![][]u8 {
    const num_cols = data.len; // Number of images (42000)
    const num_rows = data[0].pixels.len; // Number of pixels per image (784)

    // Allocate space for cols(train samples)
    const transposed_data = try allocator.alloc([]u8, num_cols);
    errdefer allocator.free(transposed_data);

    // Loop and fill each col with 784 rows(pixels for sample)
    for (transposed_data, 0..) |*col, i| {
        col.* = try allocator.alloc(u8, num_rows);
        errdefer allocator.free(col.*);

        // Copy the pixels
        @memcpy(col.*, &data[i].pixels);
    }

    return transposed_data;
}
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const data = try readCsv(allocator);

    const Y = try getY(allocator, data);

    defer allocator.free(data);
    defer allocator.free(Y);

    const transposed = try transpose(allocator, data);

    defer {
        for (transposed) |row| {
            allocator.free(row);
        }
        allocator.free(transposed);
    }
}
