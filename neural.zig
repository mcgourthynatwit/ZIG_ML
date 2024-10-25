const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;

pub const NNError = error{};

pub const Layer = struct {
    rows: usize,
    cols: usize,
    weights: Tensor,
    bias: Tensor,
};

pub const NN = struct {
    learning_rate: f32,
    allocator: std.mem.Allocator,
    layers: std.ArrayList(Layer),

    // inits a empty nn
    pub fn init(allocator: std.mem.Allocator, learning_rate: f32) !NN {
        return NN{
            .layers = std.ArrayList(Layer).init(allocator),
            .learning_rate = learning_rate,
            .allocator = allocator,
        };
    }

    // free's mem of nn
    pub fn deinit(self: *NN) void {
        for (self.layers.items) |*layer| {
            layer.weights.deinit();
            layer.bias.deinit();
        }
        self.layers.deinit();
    }

    // Returns a random f32 between -1 & 1
    fn randomFloat() !f32 {
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();
        return rand.float(f32) * 2.0 - 1.0; // Float between -1 and 1
    }

    // Fills a tensor data field with f32 values between -1 & 1
    fn randomTensorData(allocator: std.mem.Allocator, n: usize) ![]f32 {
        var data: []f32 = try allocator.alloc(f32, n);

        for (0..n) |i| {
            data[i] = randomFloat();
        }

        return data;
    }
};
