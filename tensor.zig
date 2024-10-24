const std = @import("std");
const csv = @import("csv.zig");
const Table = csv.Table;

pub const TensorError = error{ InvalidDimensions, OutOfBounds };

pub const Tensor = struct {
    data: []f32, // 1d flattened array continous in memory
    shape: []usize, // Shape [row, col]
    strides: []usize, // Navigation
    allocator: std.mem.Allocator,

    // @TODO
    // Converts a tensor struct to a tensor
    //pub fn toTable(self: *Tensor) !Table {}

    // outputs the first 5 rows of a tensor
    pub fn head(self: Tensor) void {
        // rows
        for (0..self.shape[0]) |i| {
            if (i == 5) {
                return;
            }
            // cols
            for (0..self.shape[1]) |j| {
                const index = (i * self.strides[0]) + (j * self.strides[1]);
                std.debug.print("{d:.2} ", .{self.data[index]});
            }
            std.debug.print("\n", .{});
        }
    }

    // free's data, shape & strides of a tensor
    pub fn deinit(self: *Tensor) void {
        self.allocator.free(self.data);
        self.allocator.free(self.shape);
        self.allocator.free(self.strides);
    }

    // Init a tensor from scratch passing rows, cols & arr of floats
    // data must be in format: const tensor_data = [_]f32{ 1.0, 2.0 ... };
    pub fn initTensor(allocator: std.mem.Allocator, rows: usize, cols: usize, data: []const f32) !Tensor {
        const tensor_size = rows * cols;

        if (tensor_size != data.len) {
            return TensorError.InvalidDimensions;
        }

        var tensor_data = try allocator.alloc(f32, tensor_size);
        errdefer allocator.free(tensor_data);

        var tensor_shape = try allocator.alloc(usize, 2);
        errdefer allocator.free(tensor_shape);

        tensor_shape[0] = rows;
        tensor_shape[1] = cols;

        var strides = try allocator.alloc(usize, 2);
        errdefer allocator.free(strides);

        strides[0] = cols;
        strides[1] = 1;

        // fill in tensor
        var i: usize = 0;

        for (data) |item| {
            tensor_data[i] = item;
            i += 1;
        }

        return Tensor{
            .data = tensor_data,
            .shape = tensor_shape,
            .strides = strides,
            .allocator = allocator,
        };
    }

    // gets the value at the row/col passed, helper function for Gauss Jordan
    pub fn get(self: Tensor, row: usize, col: usize) !f32 {
        if (row >= self.shape[0] or col >= self.shape[1]) {
            return TensorError.OutOfBounds;
        }
        return self.data[(row * self.strides[0]) + (col * self.strides[1])];
    }

    pub fn getRow(self: Tensor, row: usize) ![]f32 {
        if (row >= self.shape[0]) {
            return TensorError.OutOfBounds;
        }

        const start_index = (row * self.strides[0]) + (0 * self.strides[1]);
        const end_index = (row * self.strides[0]) + (self.shape[1] * self.strides[1]);

        return self.data[start_index..end_index];
    }
    //////////////////// TENSOR MATHEMATICAL FUNCTIONS  /////////////////////
    // @TODO initial implementation will be updating tensor in place but going forward may add field to return a new tensor

    // Adds two tensors together
    pub fn add(self: *Tensor, other: Tensor) !void {
        if (self.data.len != other.data.len) {
            return TensorError.InvalidDimensions;
        }

        for (0..self.data.len) |idx| {
            self.data[idx] = self.data[idx] + other.data[idx];
        }
    }

    // Subtracts two tensors
    pub fn subtract(self: *Tensor, other: Tensor) !void {
        if (self.data.len != other.data.len) {
            return TensorError.InvalidDimensions;
        }

        for (0..self.data.len) |idx| {
            self.data[idx] = self.data[idx] - other.data[idx];
        }
    }

    // Dot product of two tensors(matrices)
    pub fn matmul(self: *Tensor, other: Tensor) !void {
        if (self.shape[1] != other.shape[0]) {
            return TensorError.InvalidDimensions;
        }

        const rows = self.shape[0];
        const cols = other.shape[1];

        // dimensions of new tensor (mat dot prod rules)
        const data = try self.allocator.alloc(f32, rows * cols);

        var i: usize = 0;

        while (i < rows) : (i += 1) {
            var j: usize = 0;
            while (j < cols) : (j += 1) {
                var sum: f32 = 0.0;
                var k: usize = 0;
                while (k < other.shape[0]) : (k += 1) {
                    const self_idx = i * self.strides[0] + k * self.strides[1];
                    const other_idx = k * other.strides[0] + j * other.strides[1];
                    sum += self.data[self_idx] * other.data[other_idx];
                }
                const result_idx = i * cols + j;
                data[result_idx] = sum;
            }
        }

        // free old data from mem
        self.allocator.free(self.data);

        // update with new
        self.data = data;
        self.shape[0] = rows;
        self.shape[1] = cols;
        self.strides[0] = cols;
        self.strides[1] = 1;
    }

    //pub fn transpose(self: *Tensor) !Tensor {}

    //pub fn matrixInv(self: *Tensor) !Tensor {a}

    // @TODO
    // Multiplies two tensors in place
    //pub fn multiply(self: *Tensor, other: *Tensor) !void {}

    pub fn initIdentityMatrix(self: *Tensor) !Tensor {
        const tensor_size = self.shape[0] * self.shape[1];

        var tensor_data = try self.allocator.alloc(f32, tensor_size);

        var tensor_shape = try self.allocator.alloc(usize, 2);

        tensor_shape[0] = self.shape[0];
        tensor_shape[1] = self.shape[1];

        var strides = try self.allocator.alloc(usize, 2);

        strides[0] = self.shape[1];
        strides[1] = 1;

        // fill zeros
        for (0..tensor_size) |idx| {
            tensor_data[idx] = 0;
        }

        var i: usize = 0;
        while (i < self.shape[0]) : (i += 1) {
            const idx: usize = i * self.shape[1] + i; // Diagonal index
            tensor_data[idx] = 1;
        }

        return Tensor{
            .data = tensor_data,
            .shape = tensor_shape,
            .strides = strides,
            .allocator = self.allocator,
        };
    }
    // Transposes a tensor
    pub fn transpose(self: *Tensor) !Tensor {
        const tensor_size = self.shape[0] * self.shape[1];

        var transposed_data = try self.allocator.alloc(f32, tensor_size);

        for (0..self.shape[0]) |original_row_idx| {
            for (0..self.shape[1]) |original_col_idx| {
                // Get original tensor data index
                const src_index = (original_row_idx * self.strides[0]) + (original_col_idx * self.strides[1]);

                // Get transposed index val, Essentially : (original_col_idx * self.shape) gets the transposed row index while original_row_index indicates the offset(transposed col index)
                const dst_index = (original_col_idx * self.shape[0]) + original_row_idx;

                // Updated transposed_data
                transposed_data[dst_index] = self.data[src_index];
            }
        }

        const tensor: Tensor = try initTensor(self.allocator, self.shape[1], self.shape[0], transposed_data);
        self.allocator.free(transposed_data);
        return tensor;
    }

    pub fn inverseVector(self: *Tensor) !Tensor {
        // to take an inverse mat must be square
        if (self.shape[0] != self.shape[1]) {
            return TensorError.InvalidDimensions;
        }
    }

    // Gaussian Jordan Elimination to inverse higher order matrices (3x3, 4,4 ... )s
    pub fn gaussJordanElim(self: *Tensor) !f32 {
        var clonedTensor: Tensor = try self.clone();
        errdefer clonedTensor.deinit();

        var identityMatrix: Tensor = self.initIdentityMatrix();
        errdefer identityMatrix.deinit();

        const n = self.shape[0];

        for (0..n) |i| {
            if (clonedTensor.get(i, i) == 0) {}
        }
    }

    //////////////////// Gauss Jordan Helpers /////////////////////

    // operation 1: Swap two rows
    //pub fn swapRows(self: *Tensor, row_1: usize, row_2: usize) !void {
    //  var tmp: []f32 = self.allocator.alloc(f32, self.shape[0]);
    //}

    // operation 2: scale a row by a non-zero val
    //pub fn scaleRow(self: *Tensor, row_num: usize, scalar: usize) !void {}

    // operation 3: add/subtract a non-zero scalar multiple of one row to another
    //pub fn addScaledRow(self: *Tensor, src_row: usize, dest_row: usize) !void {}
};
