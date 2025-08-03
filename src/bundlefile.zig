const std = @import("std");
const io = @import("io.zig");

pub const BundleFileError = error{
    InvalidBundleFileHeader,
    NotUnityCNEncrypted,
};

const HeaderSignature = "UnityFS";

const UnityRevision = struct {
    major: u32,
    minor: u32,
    patch: u32,
};

fn parseUnityRevision(data: []const u8) !UnityRevision {
    var revision = UnityRevision{ .major = 0, .minor = 0, .patch = 0 };
    var dotCount: usize = 0;
    var num: u32 = 0;
    for (data) |b| {
        if (b >= '0' and b <= '9') {
            num = num * 10 + (b - '0');
        } else {
            switch (dotCount) {
                0 => revision.major = num,
                1 => revision.minor = num,
                2 => {
                    revision.patch = num;
                    return revision;
                },
                else => return revision,
            }
            dotCount += 1;
            num = 0;
        }
    }
    return revision;
}

fn versionJudge(version: UnityRevision) bool {
    return version.major < 2020 or
        (version.major == 2020 and version.minor == 3 and version.patch <= 34) or
        (version.major == 2021 and version.minor == 3 and version.patch <= 2) or
        (version.major == 2022 and version.minor == 3 and version.patch <= 1);
}

const keyData = struct {
    SignatureBytes: [16]u8,
    SignatureKey: [16]u8,
};

pub fn readBundleFileFromPath(filepath: []const u8) !keyData {
    var data: [200]u8 = undefined;
    _ = try io.readFromFile(filepath, data[0..]);

    if (!std.mem.startsWith(u8, data[0..], HeaderSignature)) {
        return BundleFileError.InvalidBundleFileHeader;
    } else {
        var offset: usize = try io.skipNullterminatedString(data[0..]);
        offset += 4;
        offset += try io.skipNullterminatedString(data[offset..]);
        const unityRevisionLen = try io.skipNullterminatedString(data[offset..]);
        const unityRevision = try parseUnityRevision(data[offset .. offset + unityRevisionLen]);
        offset += unityRevisionLen;
        offset += 8;
        offset += 4;
        offset += 4;
        const flag = try io.readUInt32Be(data[offset..]);
        offset += 4;

        const unityCnMask: u32 = if (versionJudge(unityRevision)) 0x200 else 0x1400;

        if (flag & unityCnMask == 0) {
            return BundleFileError.NotUnityCNEncrypted;
        }

        var signatureBytes: [16]u8 = undefined;
        var signatureKey: [16]u8 = undefined;
        @memcpy(signatureBytes[0..], data[(offset + 37)..(offset + 53)]);
        @memcpy(signatureKey[0..], data[(offset + 53)..(offset + 69)]);

        return keyData{
            .SignatureBytes = signatureBytes,
            .SignatureKey = signatureKey,
        };
    }
}
