const std = @import("std");

const IOError = error{
    EOF,
};

pub fn readAllFromFile(
    alloc: std.mem.Allocator,
    filepath: []const u8,
) ![]const u8 {
    const file = try std.fs.cwd().openFile(
        filepath,
        .{ .mode = .read_only },
    );
    defer file.close();
    // `readToEndAlloc` Deprecated in favor of `Reader`.
    return try file.readToEndAlloc(alloc, std.math.maxInt(usize));
}

pub fn readFromFile(
    filepath: []const u8,
    buffer: []u8,
) !usize {
    const file = try std.fs.cwd().openFile(
        filepath,
        .{ .mode = .read_only },
    );
    defer file.close();
    return try file.read(buffer);
}

pub fn skipNullterminatedString(data: []const u8) !usize {
    var len: usize = 0;
    while (len < data.len and data[len] != 0) {
        len += 1;
    }
    if (len >= data.len or data[len] != 0) {
        return IOError.EOF;
    }
    return len + 1;
}

pub fn readUInt32Be(data: []const u8) !u32 {
    if (data.len < 4) {
        return IOError.EOF;
    }
    return @as(u32, std.mem.readInt(u32, data[0..4], .big));
}
