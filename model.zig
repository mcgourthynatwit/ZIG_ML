const std = @import("std");
const Matrix = @import("matrix.zig").Matrix;

pub const Network = struct{
    layers: usize,
    weights: []Matrix,
    biases: []Matrix,
    data: []Matrix,
    activation: Activation,
    learningRate: f32,

    fn init()
}

pub fn main() !void {
    std.debug.print("Starting main function\n", .{});

    const allocator = std.heap.page_allocator;

    // Create a 3x3 matrix
    var matrix = try Matrix.initRandom(allocator, 3, 3);
    var matrix2 = try Matrix.initRandom(allocator, 3, 3);
    var zeroMatrix = try Matrix.initZero(allocator, 4, 4);

    defer matrix.freeMatrix();
    defer matrix2.freeMatrix();
    defer zeroMatrix.freeMatrix();

    for (matrix.data.items, matrix2.data.items, 0..) |row, row2, i| {
        std.debug.print("Row: {}\n", .{i});

        for (row.items, row2.items) |v1, v2| {
            std.debug.print("m1: {d:.2} m2: {d:.2}\n", .{ v1, v2 });
        }
    }

    //try matrix.addMatrix(&matrix2);

    var result = try Matrix.dotProduct(allocator, &matrix, &matrix2);
    defer result.freeMatrix();

    std.debug.print("Result of dot product:\n", .{});
    for (result.data.items) |row| {
        for (row.items) |value| {
            std.debug.print("{d} ", .{value});
        }
        std.debug.print("\n", .{});
    }
}
