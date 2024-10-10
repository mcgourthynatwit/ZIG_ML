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
        row.* = try allocator.alloc(f32, 10);
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

fn ReLu(allocator: std.mem.Allocator, Z: []f32) []f32 {
    var result = try allocator.alloc(f32, Z.len);
    errdefer allocator.free(result);

    for (Z, 0..) |val, i| {
        if (val > 0) {
            result[i] = val;
        } else {
            result[i] = 0;
        }
    }

    return result;
}

// For all dot products in this it is a weight (2d) times a 1d matrix
fn dot(allocator: std.mem.Allocator, W: [][]f32, A: []f32) ![]f32 {
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

fn softmax(allocator: std.mem.Allocator, Z: []f32) ![]f32 {
    var result = try allocator.alloc(f32, Z.len);
    errdefer allocator.free(result);

    var sum: f32 = 0.0;

    // get sum for softmax
    for (Z, 0..) |val, i| {
        result[i] = std.math.exp(val);
        sum += result[i];
    }

    for (result) |*val| {
        val.* /= sum;
    }

    return result;
}

fn addBias(allocator: std.mem.Allocator, Z: *[][]f32, B: []f32) ![]f32 {
    for (Z, 0..) |z_val, i| {
        
    }

    return result;
}

fn oneHot(allocator: std.mem.Allocator, Y: []u8) ![][]u8 {
    // 10 rows(mnist is 0-9)
    const encoded = try allocator.alloc([]u8, 10);

    for (encoded, 0..) |*row, row_idx| {
        row.* = try allocator.alloc(u8, Y.len);
        for (Y, 0..) |y_val, i| {
            if (y_val == row_idx) {
                row.*[i] = 1;
            } else {
                row.*[i] = 0;
            }
        }
    }

    return encoded;
}

fn subtractArray(allocator: std.mem.Allocator, arr1: []f32, arr2: []f32) []f32 {
    if (arr1.len != arr2.len) {
        return error.InvalidFormat;
    }

    var result = try allocator.alloc(f32, arr1.len);

    for (arr1, arr2, 0..) |a1_val, a2_val, i| {
        result[i] = a1_val - a2_val;
    }

    return result;
}

fn forwardProp(allocator: std.mem.Allocator, W1: [][]f32, W2: [][]f32, B1: []f32, B2: []f32, X: []f32) !void {
    var Z1 = try dot(allocator, W1, X);
    Z1 = try addBias(allocator, Z1, B1);
    const A1 = try ReLu(allocator, Z1);

    var Z2 = try dot(allocator, W2, A1);
    Z2 = try addBias(allocator, Z2, B2);
    const A2 = try softmax(allocator, Z2);

    return A2;
}

//fn backProp(allocator: std.mem.Allocator, A1: []f32, A2: []f32, Z1: []f32, Z2: []f32, W2: [][]f32, Y: []f32) !void {
//  var one_hot_y = oneHot(allocator, Y);

//var dZ2 = subtractArray(allocator, A2, one_hot_y);
//}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Calculate dot product

    const data = try readCsv(allocator);
    const Y = try getY(allocator, data);

    defer allocator.free(data);
    defer allocator.free(Y);

    std.debug.print("Rows {any}, cols {any}\n", .{ data.len, data[0].pixels.len });
    std.debug.print("Y {any}\n", .{Y.len});

    const nn = try initNN(allocator);

    defer {
        // Free inner allocations of W1
        for (nn.W1) |row| {
            allocator.free(row);
        }
        // Free inner allocations of W2
        for (nn.W2) |row| {
            allocator.free(row);
        }
        // Free outer allocations
        allocator.free(nn.W1);
        allocator.free(nn.W2);
        allocator.free(nn.B1);
        allocator.free(nn.B2);
    }
}
