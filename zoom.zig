// Forward Facing API

const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;
const Table = @import("csv.zig").Table;
const Neural = @import("Neural.zig").NN;

pub const Zoom = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Zoom {
        return Zoom{
            .allocator = allocator,
        };
    }

    pub fn read_csv(self: *Zoom, file_name: []const u8) !*Table {
        var table: Table = Table.init(self.allocator);
        try table.readCsv(file_name);

        return &table;
    }
};
