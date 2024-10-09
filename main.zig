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

// Helper function for initNN to randomley generate f16 between -1 & 1
fn getFloat() !f32 {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    const rand = prng.random();

    const a = rand.float(f32) * 2.0 - 1.0;

    return a;
}

// Inits the weights & bias of the neural network, will be a single hidden layer w/ an input & output layer
// In total will have two weights and two bias, will be initialized random
fn initNN(allocator: std.mem.Allocator) !struct { W1: [][]f32, W2: [][]f32, B1: []f32, B2: []f32 } {
    const W1 = try allocator.alloc([]f32, 10);
    const W2 = try allocator.alloc([]f32, 10);
    const B1 = try allocator.alloc(f32, 10);
    const B2 = try allocator.alloc(f32, 10);

    for (W1) |*row| {
        row.* = try allocator.alloc(f32, 784);
        for (row.*) |*val| {
            val.* = try getFloat();
        }
    }

    for (W2) |*row| {
        row.* = try allocator.alloc(f32, 1);
        for (row.*) |*val| {
            val.* = try getFloat();
        }
    }

    for (B1) |*val| {
        val.* = try getFloat();
    }

    for (B2) |*val| {
        val.* = try getFloat();
    }

    return .{ .W1 = W1, .W2 = W2, .B1 = B1, .B2 = B2 };
}

fn ReLu(Z: u8) u8 {
    if (Z > 0) {
        return Z;
    }

    return 0;
}

// For all dot products in this it is a weight (2d) times a 1d matrix
fn dot(allocator: std.mem.Allocator, W: []const []const f32, A: []const f32) ![]f32 {
    // matrix dot product rules
    if (W[0].len != A.len) {
        return error.InvalidFormat;
    }
    // # rows in result array == # rows in W (matrix dot rules)
    var result = try allocator.alloc(f32, W.len);
    errdefer allocator.free(result);

    for (W, 0..) |row, i| {
        result[i] = 0;
        for (row, A) |w_val, a_val| {
            result[i] += w_val * a_val;
        }
    }

    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Calculate dot product

    const data = try readCsv(allocator);
    const Y = try getY(allocator, data);

    defer allocator.free(data);
    defer allocator.free(Y);

    const nn = try initNN(allocator); // Pass the allocator to initNN

    defer allocator.free(nn.W1);
    defer allocator.free(nn.W2);
    defer allocator.free(nn.B1);
    defer allocator.free(nn.B2);
}
