const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;

pub const MLError = error{};

pub const RegressionResult = struct {
    r_squared: f32,
    mse: f32,
    mae: f32,
    rmse: f32,
    predictions: []f32,
    coefficients: []f32,
    intercept: f32,
    allocator: std.mem.Allocator, // Add this

    pub fn deinit(self: *RegressionResult) void {
        self.allocator.free(self.predictions);
        self.allocator.free(self.coefficients);
    }
};

pub const ML = struct {
    pub fn mean(T: Tensor) f32 {
        const n: f32 = @as(f32, @floatFromInt(T.data.len));
        var sum: f32 = 0.0;

        for (T.data) |val| {
            sum += val;
        }
        return sum / n;
    }

    // Calculates r^2 given Y_A -> actual y val & Y_P -> predicted y val
    pub fn rSquared(Y_A: Tensor, Y_P: Tensor) f32 {
        var SSR: f32 = 0.0;
        var SST: f32 = 0.0;
        const M: f32 = mean(Y_A);

        for (0..Y_A.data.len) |i| {
            SSR += (Y_A.data[i] - Y_P.data[i]) * (Y_A.data[i] - Y_P.data[i]);
            SST += (Y_A.data[i] - M) * (Y_A.data[i] - M);
        }

        return (1 - (SSR / SST));
    }

    // Calculates MSE given Y_A -> actual y val & Y_P -> Predicted y val
    pub fn mse(Y_A: Tensor, Y_P: Tensor) f32 {
        var sum: f32 = 0.0;
        const n: f32 = @as(f32, @floatFromInt(Y_A.data.len));

        for (0..Y_A.data.len) |idx| {
            const val: f32 = Y_A.data[idx] - Y_P.data[idx];
            sum += (val * val);
        }

        return sum / n;
    }

    // Calculates RMSE given Y_A -> actual y val & Y_P -> Predicted y val
    pub fn rmse(Y_A: Tensor, Y_P: Tensor) f32 {
        var sum: f32 = 0.0;
        const n: f32 = @as(f32, @floatFromInt(Y_A.data.len));

        for (0..Y_A.data.len) |idx| {
            const val: f32 = Y_A.data[idx] - Y_P.data[idx];
            sum += (val * val);
        }

        return std.math.sqrt(sum / n);
    }

    // Calculates MAE given Y_A -> actual y val & Y_P -> Predicted y val
    pub fn mae(Y_A: Tensor, Y_P: Tensor) f32 {
        const n: f32 = @as(f32, @floatFromInt(Y_A.data.len));
        var sum: f32 = 0.0;

        for (0..Y_A.data.len) |idx| {
            const val: f32 = Y_A.data[idx] - Y_P.data[idx];
            sum += (val * val);
        }

        return @abs(sum / n);
    }

    // OLS
    pub fn linearRegression(X: Tensor, Y: Tensor) !RegressionResult {
        var X_augmented = try X.clone();
        try X_augmented.addOnesColumn();
        defer X_augmented.deinitTensor();

        var X_C: Tensor = try Tensor.initTensor(X_augmented.allocator, X_augmented.shape[0], X_augmented.shape[1], X_augmented.data);
        var X_T: Tensor = try X_C.transpose();
        try X_T.matmul(X_C);
        var beta: Tensor = try X_T.inverseVector();

        X_T.deinitTensor();
        X_T = try X_C.transpose();
        try beta.matmul(X_T);
        try beta.matmul(Y);

        // Create our result values before any cleanup
        const coeffs = try X_augmented.allocator.alloc(f32, beta.data.len - 1);
        @memcpy(coeffs, beta.data[1..]);
        const intercept = beta.data[0];
        try X_C.matmul(beta);

        // Store metrics before cleanup
        const r2 = rSquared(Y, X_C);
        const mean_se = mse(Y, X_C);
        const mean_ae = mae(Y, X_C);
        const root_mse = rmse(Y, X_C);
        const preds = try X_augmented.allocator.dupe(f32, X_C.data);

        // Now do cleanup
        beta.deinitTensor();
        X_T.deinitTensor();
        X_C.deinitTensor();

        return RegressionResult{
            .r_squared = r2,
            .mse = mean_se,
            .mae = mean_ae,
            .rmse = root_mse,
            .predictions = preds,
            .coefficients = coeffs,
            .intercept = intercept,
            .allocator = X_augmented.allocator,
        };
    }
};
