const std = @import("std");

const Table = @import("csv.zig").Table;
const TensorObject = @import("tensor.zig").Tensor;
const DataPoint = @import("csv.zig").DataPoint;
pub const Zoom = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Zoom {
        return Zoom{
            .allocator = allocator,
        };
    }
};

pub const DataFrame = struct {
    table: Table,

    pub fn init(allocator: std.mem.Allocator) !DataFrame {
        const table = Table{
            .source_data = null,
            .allocator = allocator,
            .body = std.ArrayListAligned(std.ArrayList(DataPoint), null).init(allocator),
            .headers = std.StringHashMap(usize).init(allocator),
        };
        return DataFrame{
            .table = table,
        };
    }

    pub fn deinit(self: *DataFrame) void {
        self.table.deinitTable();
    }

    pub fn readCsv(allocator: std.mem.Allocator, file_name: []const u8) !DataFrame {
        var df = try DataFrame.init(allocator);
        const start_time: i128 = std.time.nanoTimestamp();

        try df.table.readCsvTable(file_name);

        const end_time: i128 = std.time.nanoTimestamp();
        const time_read_seconds: f64 = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000_000.0;

        std.debug.print("Parsed csv in {d} seconds.\n", .{time_read_seconds});

        return df;
    }

    pub fn head(self: *DataFrame) !void {
        try self.table.headTable();
    }

    pub fn columns(self: *DataFrame) !void {
        try self.table.columns();
    }

    pub fn shape(self: *DataFrame) !void {
        self.table.shapeTable();
    }

    pub fn filter(self: *DataFrame, allocator: std.mem.Allocator, cols: []const []const u8) !DataFrame {
        const filtered_table = try self.table.filterTable(allocator, cols);
        return DataFrame{ .table = filtered_table };
    }

    pub fn drop(self: *DataFrame, allocator: std.mem.Allocator, cols: []const []const u8) !DataFrame {
        const dropped_table = try self.table.dropColumnTable(allocator, cols);
        return DataFrame{ .table = dropped_table };
    }

    pub fn toTensor(self: *DataFrame, allocator: std.mem.Allocator) !Tensor {
        var tensorObject: TensorObject = try self.table.tableToTensor(allocator);
        defer tensorObject.deinitTensor();
        return Tensor.init(allocator, tensorObject.shape[0], tensorObject.shape[1], tensorObject.data);
    }
};

pub const Tensor = struct {
    allocator: std.mem.Allocator,
    tensor: TensorObject,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize, data: []const f32) !Tensor {
        const tensorObject: TensorObject = try TensorObject.initTensor(allocator, rows, cols, data);

        return Tensor{
            .allocator = allocator,
            .tensor = tensorObject,
        };
    }

    pub fn deinit(self: *Tensor) void {
        self.tensor.deinitTensor();
    }

    pub fn head(self: *Tensor) void {
        self.tensor.headTensor();
    }

    pub fn add(self: *Tensor, other: Tensor) !void {
        self.tensor.add(other.tensor);
    }

    pub fn subtract(self: *Tensor, other: Tensor) !void {
        self.tensor.subtract(other.tensor);
    }

    pub fn matmul(self: *Tensor, other: Tensor) !void {
        self.tensor.matmul(other.tensor);
    }

    pub fn addBias(self: *Tensor, bias: Tensor) !void {
        self.tensor.addBias(bias.tensor);
    }

    pub fn transpose(self: *Tensor) !Tensor {
        const transposedData: TensorObject = self.tensor.transpose();

        const tensorTransposed: Tensor = Tensor.init(self.allocator, transposedData.shape[0], transposedData.shape[1], transposedData.data);

        return tensorTransposed;
    }

    pub fn inverse(self: *Tensor) !Tensor {
        const inverseData: TensorObject = self.tensor.inverseVector();

        const inverseTenosr: Tensor = Tensor.init(self.allocator, inverseData.shape[0], inverseData.shape[1], inverseData.data);

        return inverseTenosr;
    }
};
