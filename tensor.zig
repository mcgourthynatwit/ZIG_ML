const std = @import("std");
const csv = @import("csv.zig");
const Table = csv.Table;

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

    // @TODO
    // Adds two tensors together
    //pub fn add(self: *Tensor, other: *Tensor) !void {}

    // @TODO
    // Subtracts two tensors
    //pub fn subtract(self: *Tensor, other: *Tensor) !void {}

    // @TODO
    // Multiplies two tensors in place
    //pub fn multiply(self: *Tensor, other: *Tensor) !void {}

    // @TODO
    // Transposes a tensor
    //pub fn transpose(self: *Tensor) !Tensor {}
};
