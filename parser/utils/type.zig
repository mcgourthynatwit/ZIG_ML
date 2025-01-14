const std = @import("std");
const ColumnType = @import("../csv.zig").ColumnType;

pub fn determineType(value: []const u8) !ColumnType {
    // int
    if (std.fmt.parseInt(i32, value, 10)) |_| {
        return .Int;
    } else |_| {
        if (std.fmt.parseFloat(f32, value)) |_| {
            return .Float;
        } else |_| {
            return .String;
        }
    }
}
