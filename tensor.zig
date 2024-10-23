const std = @import("std");
const csv = @import("csv.zig");
const Table = csv.Table;

pub const TensorError = error{InvalidDimensions};

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

        var tensor_shape = try allocator.alloc(usize, 2);

        tensor_shape[0] = rows;
        tensor_shape[1] = cols;

        var strides = try allocator.alloc(usize, 2);

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

    // @TODO
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
};
