pub const RawKeyIterator = struct {
    data: []const u8,
    pos: usize = 0,

    pub fn init(data: []const u8) RawKeyIterator {
        return .{
            .data = data,
        };
    }

    pub fn next(self: *RawKeyIterator) ?[16]u8 {
        if (self.pos + 16 > self.data.len) {
            return null;
        }

        const key_start = self.pos;
        var key: [16]u8 = undefined;
        @memcpy(&key, self.data[key_start .. key_start + 16]);
        self.pos += 1;
        return key;
    }
};

pub const AsciiKeyIterator = struct {
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

            if (byte >= 0x20 and byte <= 0x7E) {
                self.consecutive += 1;

                if (self.consecutive >= 16) {
                    const key_start = self.pos - 16;
                    var key: [16]u8 = undefined;
                    @memcpy(&key, self.data[key_start .. key_start + 16]);
                    return key;
                }
            } else {
                self.consecutive = 0;
            }
        }
        return null;
    }
};
