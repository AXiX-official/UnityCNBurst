const std = @import("std");
const allocator = std.heap.page_allocator;
const bundlefile = @import("bundlefile.zig");
const global_metadata = @import("global_metadata.zig");
const keyIter = @import("keyIter.zig");

const Signature = "#$unity3dchina!@";

fn compute_valid_encrypted_key(signatureBytes: []const u8) [16]u8 {
    var encrypted_key: [16]u8 = undefined;
    for (Signature, 0..) |b, i| {
        encrypted_key[i] = b ^ signatureBytes[i];
    }
    return encrypted_key;
}

const BurstResult = struct {
    validKey: ?[16]u8,
    elapsedTimeSec: f64,
    keysPerSecond: f64,
    keyCount: u64,
};

fn burstKey(
    iter: anytype,
    valid_encrypted_key: [16]u8,
    signatureKey: [16]u8,
) BurstResult {
    var validKey: [16]u8 = undefined;
    var key_count: u64 = 0;
    var flag = false;

    const start_time = std.time.microTimestamp();

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
            @memcpy(&validKey, key[0..]);
            break;
        }
        key_count += 1;
    }

    const end_time = std.time.microTimestamp();
    const elapsed_time = end_time - start_time;
    const elapsed_time_sec = @as(f64, @floatFromInt(elapsed_time)) / 1_000_000;
    const keys_per_second: f64 = if (elapsed_time > 0) @as(f64, @floatFromInt(key_count)) * 1_000_000.0 / @as(f64, @floatFromInt(elapsed_time)) else 0.0;

    if (!flag) {
        return BurstResult{ .validKey = null, .elapsedTimeSec = elapsed_time_sec, .keysPerSecond = keys_per_second, .keyCount = key_count };
    } else {
        return BurstResult{
            .validKey = validKey,
            .elapsedTimeSec = elapsed_time_sec,
            .keysPerSecond = keys_per_second,
            .keyCount = key_count,
        };
    }
}

fn burst(bundlefile_path: []const u8, global_metadata_path: []const u8, useRawKeys: bool) !BurstResult {
    const keyData = try bundlefile.readBundleFileFromPath(bundlefile_path);
    const valid_encrypted_key = compute_valid_encrypted_key(&keyData.SignatureBytes);
    const metadata = try global_metadata.readGlobalMetadataFromPath(global_metadata_path);
    defer allocator.free(metadata);

    if (useRawKeys) {
        var iter = keyIter.RawKeyIterator.init(metadata);
        return burstKey(
            &iter,
            valid_encrypted_key,
            keyData.SignatureKey,
        );
    } else {
        var iter = keyIter.AsciiKeyIterator.init(metadata);
        return burstKey(
            &iter,
            valid_encrypted_key,
            keyData.SignatureKey,
        );
    }
}

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 3) {
        std.debug.print("Usage:\n", .{});
        std.debug.print("   {s} <bundlefile> <global-metadata.dat> <options>\n", .{args[0]});
        std.debug.print("Options:\n", .{});
        std.debug.print("   -r: Generate raw hex key set from global-metadata.dat(will generate ascii keys only by default)\n", .{});
        return;
    }

    const bundlefile_path = args[1];
    const global_metadata_path = args[2];

    const useRawKeys: bool = if (args.len > 3 and std.mem.eql(u8, args[3], "-r")) true else false;

    const result = burst(bundlefile_path, global_metadata_path, useRawKeys) catch |err| {
        switch (err) {
            bundlefile.BundleFileError.InvalidBundleFileHeader => std.debug.print("Error: Invalid bundle file header.\n\"{s}\" may not a valid BundleFile.\n", .{bundlefile_path}),
            bundlefile.BundleFileError.NotUnityCNEncrypted => std.debug.print("Error: Bundle file is not UnityCN encrypted.\n\"{s}\" may not using UnityCN encryption.\n", .{bundlefile_path}),
            global_metadata.MetadataFileError.InvalidMetadataHeader => std.debug.print("Error: Invalid global metadata file header.\n\"{s}\" may not a valid global-metadata.dat or the file is encrypted.\n", .{global_metadata_path}),
            else => std.debug.print("Error: something went wrong\n", .{}),
        }
        return;
    };

    std.debug.print("Elapsed time: {d} sec\n", .{result.elapsedTimeSec});
    std.debug.print("Total keys checked: {d}\n", .{result.keyCount});
    std.debug.print("Keys per second: {d}\n\n", .{result.keysPerSecond});
    if (result.validKey) |key| {
        std.debug.print("Valid key found: \n", .{});
        std.debug.print("ASCII: {s}\n", .{key});
        std.debug.print("Hex: ", .{});
        for (key) |b| {
            std.debug.print("{X}", .{b});
        }
    } else {
        std.debug.print("No valid key found.\n", .{});
    }
}
