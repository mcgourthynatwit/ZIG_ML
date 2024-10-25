const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;

pub const NNError = error{InvalidShape};

pub const Layer = struct {
    rows: usize,
    cols: usize,
    activation: ActivationFn,
    weights: ?Tensor,
    bias: ?Tensor,
};

pub const ActivationFn = enum {
    ReLU,
    Softmax,
};

pub const ForwardResult = struct {
    layer_output: std.ArrayList(Tensor),
    prediction: Tensor,

    pub fn deinit(self: *ForwardResult) void {
        for (self.activations.items) |*activation| {
            activation.deinit();
        }
        self.activations.deinit();
    }
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
            // Only deinit if weights/bias exist
            if (layer.weights) |*weights| {
                weights.deinit();
            }
            if (layer.bias) |*bias| {
                bias.deinit();
            }
        }
        self.layers.deinit();
    }

    fn relu(vals: []f32) void {
        for (vals) |*val| {
            val.* = @max(0.0, val.*);
        }
    }

    fn softmax(vals: []f32) void {
        var sum: f32 = 0.0;

        // store max_val to eliminate any overflow with large #'s
        var max_val: f32 = -std.math.inf(f32);

        for (vals) |val| {
            max_val = @max(max_val, val);
        }

        // Exponentiate each value, adjusted by the max, and calculate the sum
        for (vals) |*val| {
            val.* = @exp(val.* - max_val);
            sum += val.*;
        }

        // Normalize each val to a probability
        for (vals) |*val| {
            val.* /= sum;
        }
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
            data[i] = try randomFloat();
        }

        return data;
    }

    // Adds a layer to the neural network given shape & activation func
    pub fn addLayer(self: *NN, rows: usize, cols: usize, activation: ActivationFn) !void {
        if (self.layers.items.len > 0) {
            const prev_layer = self.layers.items[self.layers.items.len - 1];
            if (prev_layer.cols != rows) {
                // for mat mul rules prev layer cols must equal next layers rows
                return NNError.InvalidShape;
            }
        }

        var layer = Layer{
            .rows = rows,
            .cols = cols,
            .activation = activation,
            .weights = null,
            .bias = null,
        };

        // if first layer then simply is input layer no need for weights & bias
        if (self.layers.items.len == 0) {
            try self.layers.append(layer);
            return;
        }

        // init random weights & bias
        const rand_weight: []f32 = try randomTensorData(self.allocator, rows * cols);
        const rand_bias: []f32 = try randomTensorData(self.allocator, cols);

        defer self.allocator.free(rand_weight);
        defer self.allocator.free(rand_bias);

        // init tensors for weights & bias
        layer.weights = try Tensor.initTensor(self.allocator, rows, cols, rand_weight);
        layer.bias = try Tensor.initTensor(self.allocator, 1, cols, rand_bias);

        try self.layers.append(layer);
    }

    fn forwardProp(self: *NN, input: *Tensor) !ForwardResult {
        var layer_outputs = std.ArrayList(Tensor).init(self.allocator);

        // add input layer
        try layer_outputs.append(try input.clone(self.allocator));

        for (self.layers.items[1..], 0..) |layer, i| {
            var current: Tensor = try layer_outputs.items[i].clone(self.allocator);

            try current.matmul(layer.weights);
            try current.add(layer.bias);
            switch (layer.activation) {
                .ReLU => {
                    relu(&current.data);
                },
                .Softmax => {
                    softmax(&current.data);
                },
            }

            try layer_outputs.append(current);
        }

        return ForwardResult{
            .activations = layer_outputs,
            .prediction = layer_outputs.items[layer_outputs.items.len - 1],
        };
    }

    fn backProp() !void {}

    fn train() !void {}
};
