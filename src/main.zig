const std = @import("std");
const allocator = std.heap.page_allocator;

const HeaderSignature = "UnityFS";
const Signature = "#$unity3dchina!@";

pub fn ReadAllFromFile(
    alloc: std.mem.Allocator,
    filepath: []const u8,
) ![]const u8 {
    const file = try std.fs.cwd().openFile(
        filepath,
        .{ .mode = .read_only },
    );
    defer file.close();
    return try file.reader().readAllAlloc(alloc, @import("std").math.maxInt(i64));
}

pub fn ReadFromFile(
    filepath: []const u8,
    buffer: []u8,
) !usize {
    const file = try std.fs.cwd().openFile(
        filepath,
        .{ .mode = .read_only },
    );
    defer file.close();
    return try file.reader().readAll(buffer);
}

pub fn skipNullterminatedString(data: []const u8) usize {
    var len: usize = 0;
    while (len < data.len and data[len] != 0) {
        len += 1;
    }
    return len + 1;
}

fn compute_valid_encrypted_key(signatureBytes: []const u8) [16]u8 {
    var encrypted_key: [16]u8 = undefined;
    for (Signature, 0..) |b, i| {
        encrypted_key[i] = b ^ signatureBytes[i];
    }
    return encrypted_key;
}

const AsciiKeyIterator = struct {
    data: []const u8,
    pos: usize = 0,
    consecutive: usize = 0,

    pub fn init(data: []const u8) AsciiKeyIterator {
        return .{
            .data = data,
        };
    }

    pub fn next(self: *AsciiKeyIterator) ?[16]u8 {
        while (self.pos < self.data.len) {
            const byte = self.data[self.pos];
            self.pos += 1;
            if (self.pos >= 16) {
                const key_start = self.pos - 16;
                var key: [16]u8 = undefined;
                @memcpy(&key, self.data[key_start .. key_start + 16].ptr);
                return key;
            }
            if (byte >= 0x20 and byte <= 0x7E) {
                self.consecutive += 1;

                if (self.consecutive >= 16) {
                    const key_start = self.pos - 16;
                    var key: [16]u8 = undefined;
                    @memcpy(&key, self.data[key_start .. key_start + 16].ptr);
                    self.consecutive += 1;
                    return key;
                }
            } else {
                self.consecutive = 0;
            }
        }
        return null;
    }
};

fn skipHeader(data: []const u8) usize {
    var offset: usize = 0;

    offset += skipNullterminatedString(data[offset..]);
    offset += 4;
    offset += skipNullterminatedString(data[offset..]);
    offset += skipNullterminatedString(data[offset..]);
    offset += 8;
    offset += 4;
    offset += 4;
    offset += 4;

    return offset;
}

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 3) {
        std.debug.print("Usage: {s} <bundlefile> <global-metadata.dat>\n", .{args[0]});
        return;
    }

    const bundlefile_filepath = args[1];
    var bundlefile_data: [200]u8 = undefined;
    _ = ReadFromFile(bundlefile_filepath, bundlefile_data[0..]) catch {
        std.debug.print("Failed to read bundle file\n", .{});
        return;
    };

    if (std.mem.startsWith(u8, bundlefile_data[0..], HeaderSignature)) {
        std.debug.print("Bundle file signature is valid\n", .{});
    } else {
        std.debug.print("Bundle file signature is invalid\n", .{});
        return;
    }

    const offset = skipHeader(bundlefile_data[0..]);
    var signatureBytes: [16]u8 = undefined;
    var signatureKey: [16]u8 = undefined;
    @memcpy(signatureBytes[0..], bundlefile_data[(offset + 37)..(offset + 53)]);
    @memcpy(signatureKey[0..], bundlefile_data[(offset + 53)..(offset + 69)]);

    const valid_encrypted_key = compute_valid_encrypted_key(&signatureBytes);

    const global_metadata_filepath = args[2];
    const global_metadata = ReadAllFromFile(allocator, global_metadata_filepath) catch {
        std.debug.print("Failed to read global-metadata.dat\n", .{});
        return;
    };
    defer allocator.free(global_metadata);

    var iter = AsciiKeyIterator.init(global_metadata);
    const start_time = std.time.microTimestamp();
    var key_count: u64 = 0;
    var flag = false;
    while (iter.next()) |key| {
        flag = flag: {
            var ctx = std.crypto.core.aes.Aes128.initEnc(key);
            var out: [16]u8 = undefined;
            ctx.encrypt(out[0..], signatureKey[0..]);
            for (out, valid_encrypted_key) |a, b| {
                if (a != b) {
                    break :flag false;
                }
            }
            break :flag true;
        };

        if (flag) {
            std.debug.print("Found valid key: {s}\n", .{key});
            break;
        }
        key_count += 1;
    }

    const end_time = std.time.microTimestamp();
    const elapsed_time = end_time - start_time;
    const elapsed_time_sec = @as(f64, @floatFromInt(elapsed_time)) / 1_000_000;
    const keys_per_second: f64 = if (elapsed_time > 0) @as(f64, @floatFromInt(key_count)) * 1_000_000.0 / @as(f64, @floatFromInt(elapsed_time)) else 0.0;

    std.debug.print("Elapsed time: {d} sec\n", .{elapsed_time_sec});
    std.debug.print("Total keys checked: {d}\n", .{key_count});
    std.debug.print("Keys per second: {d}\n", .{keys_per_second});
    if (!flag) {
        std.debug.print("No valid key found\n", .{});
    }
}
