const std = @import("std");

pub fn verifyFileType(file_name: []const u8) bool {
    const extension_index = std.mem.lastIndexOf(u8, file_name, ".");

    if (extension_index == null) {
        return false;
    }

    const extension = file_name[extension_index.?..];

    if (!std.mem.eql(u8, extension, ".csv")) {
        return false;
    }

    return true;
}
