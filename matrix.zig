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

pub const Matrix = struct {
    rows: usize,
    cols: usize,
    data: std.ArrayList(std.ArrayList(f32)),

    const MatrixErrors = error{DimensionMismatch};
    // Initialize random matrix
    pub fn initRandom(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
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

    // Initialize zero matrix
    pub fn initZero(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
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
                try row.append(0);
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

    pub fn subtractMatrix(self: *Matrix, other: *Matrix) !void {
        if (self.rows != other.rows or self.cols != other.cols) {
            return error.DimensionMismatch;
        }

        for (0..self.rows) |i| {
            for (0..self.cols) |j| {
                self.data.items[i].items[j] -= other.data.items[i].items[j];
            }
        }
    }

    pub fn dotProduct(allocator: std.mem.Allocator, self: *Matrix, other: *Matrix) !Matrix {
        // Matrix dot rules
        if (self.cols != other.rows) {
            return error.DimensionMismatch;
        }

        var m = try Matrix.initZero(allocator, self.rows, other.cols);

        for (0..self.rows, 0..other.cols, 0..self.cols) |i, j, k| {
            m.data.items[i].items[j] += self.data.items[i].items[k] * other.data.items[k].items[j];
        }

        return m;
    }
};
