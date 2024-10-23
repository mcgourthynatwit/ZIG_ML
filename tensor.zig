const std = @import("std");
const csv = @import("csv.zig");
const Table = csv.Table;

const Tensor = struct {
    data: []f32, // 1d flattened array continous in memory
    shape: []usize, // Shape [row, col]
    strides: []usize, // Navigation

    // @TODO
    // Converts a table struct to a tensor
    pub fn toTensor(table: *Table) !Tensor {}

    // @TODO
    // Converts a tensor struct to a tensor
    pub fn toTable(self: *Tensor) !Table {}

    // @TODO
    // Adds two tensors together
    pub fn add(self: *Tensor, other: *Tensor) !void {}

    // @TODO
    // Subtracts two tensors
    pub fn subtract(self: *Tensor, other: *Tensor) !void {}

    // @TODO
    // Multiplies two tensors in place
    pub fn multiply(self: *Tensor, other: *Tensor) !void {}

    // @TODO
    // Transposes a tensor
    pub fn transpose(self: *Tensor) !Tensor {}
};
