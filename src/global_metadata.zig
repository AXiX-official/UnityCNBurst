const std = @import("std");
const io = @import("io.zig");
const allocator = std.heap.page_allocator;

const signBytes = [4]u8{ 0xAF, 0x1B, 0xB1, 0xFA };

pub const MetadataFileError = error{
    InvalidMetadataHeader,
};

pub fn readGlobalMetadataFromPath(filepath: []const u8) ![]const u8 {
    const global_metadata = try io.readAllFromFile(allocator, filepath);
    if (global_metadata.len < 4 or !std.mem.startsWith(u8, global_metadata[0..4], &signBytes)) {
        return MetadataFileError.InvalidMetadataHeader;
    }
    return global_metadata;
}
