const std = @import("std");
const Tensor = @import("tensor.zig").Tensor;

pub const MLError = error{};

pub const RegressionResult = struct {
    r_squared: f32,
    mse: f32,
    mae: f32,
    rmse: f32,
    predictions: []f32,
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
        // Calculate beta = (X^T X)^-1 X^T Y
        var X_C: Tensor = try Tensor.initTensor(X.allocator, X.shape[0], X.shape[1], X.data);

        // First transpose
        var X_T: Tensor = try X_C.transpose();

        // .matmul updates X_T in place
        try X_T.matmul(X_C);
        var beta: Tensor = try X_T.inverseVector();

        // Clear X_T and set it to transposed again since it was modified above
        X_T.deinit();

        X_T = try X_C.transpose();

        try beta.matmul(X_T);
        try beta.matmul(Y);

        try X_C.matmul(beta);

        // Clean up
        beta.deinit();
        X_T.deinit();
        defer X_C.deinit();

        return RegressionResult{
            .r_squared = rSquared(Y, X_C),
            .mse = mse(Y, X_C),
            .mae = mae(Y, X_C),
            .rmse = rmse(Y, X_C),
            .predictions = X_C.data,
        };
    }
};
