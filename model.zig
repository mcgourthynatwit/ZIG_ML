const std = @import("std");

// generates a random floating point between -1 & 1
fn getFloat() !f32 {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });

    const rand = prng.random();

    const rawFloat = rand.float(f32) * 2.0; // Float between -1 and 1
    return @round(rawFloat * 2.0) / 2.0;
}

const Matrix = struct {
    rows: usize,
    cols: usize,
    data: std.ArrayList(std.ArrayList(f32)),

    const MatrixErrors = error{DimensionMismatch};
    // Initialize matrix
    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        var m = Matrix{
            .rows = rows,
            .cols = cols,
            .data = std.ArrayList(std.ArrayList(f32)).init(allocator), // Correct initialization of the outer ArrayList
        };

        // Randomize matrix
        for (rows) |_| {
            var row = std.ArrayList(f32).init(allocator); // Correct initialization of each row
            defer if (row.items.len == 0) row.deinit(); // Clean up row on error

            for (cols) |_| {
                const float = try getFloat();
                try row.append(float);
            }
            try m.data.append(row);
        }

        return m;
    }

    // Free the matrix
    pub fn freeMatrix(self: *Matrix) void {
        for (self.data.items) |*row| {
            row.deinit(); // Deinit each row
        }
        self.data.deinit(); // Deinit the matrix itself
    }

    pub fn addMatrix(self: *Matrix, other: *Matrix) !void {
        if (self.rows != other.rows or self.cols != other.cols) {
            return error.DimensionMismatch;
        }

        for (0..self.rows) |i| {
            for (0..self.cols) |j| {
                self.data.items[i].items[j] += other.data.items[i].items[j];
            }
        }
    }
};

pub fn main() !void {
    std.debug.print("Starting main function\n", .{});

    const allocator = std.heap.page_allocator;

    // Create a 3x3 matrix
    var matrix = try Matrix.init(allocator, 3, 3);
    var matrix2 = try Matrix.init(allocator, 3, 3);

    defer matrix.freeMatrix();
    defer matrix2.freeMatrix();

    for (matrix.data.items, matrix2.data.items, 0..) |row, row2, i| {
        std.debug.print("Row: {}\n", .{i});

        for (row.items, row2.items) |v1, v2| {
            std.debug.print("m1: {d:.2} m2: {d:.2}\n", .{ v1, v2 });
        }
    }

    try matrix.addMatrix(&matrix2);

    for (matrix.data.items, 0..) |row, i| {
        std.debug.print("Add Row: {}\n", .{i});

        for (row.items) |v1| {
            std.debug.print("m1: {d:.2}\n", .{v1});
        }
    }
}
