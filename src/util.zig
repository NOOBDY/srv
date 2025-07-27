const std = @import("std");
const posix = std.posix;

const BUF_SIZE = 64;

pub const Reader = struct {
    allocator: *const std.mem.Allocator,

    buf: []u8,

    pos: usize = 0,

    start: usize = 0,

    socket: posix.socket_t,

    pub fn init(allocator: *const std.mem.Allocator, socket: posix.socket_t) !Reader {
        const init_buf = try allocator.alloc(u8, BUF_SIZE);
        return Reader{
            .allocator = allocator,
            .buf = init_buf,
            .socket = socket,
        };
    }

    pub fn deinit(self: *Reader) void {
        self.allocator.free(self.buf);
    }

    pub fn read(self: *Reader) ![]u8 {
        var buf = self.buf;

        while (true) {
            if (try self.bufferedMessage()) |msg| {
                return msg;
            }

            const pos = self.pos;
            const n = try posix.read(self.socket, buf[pos..]);
            if (n == 0) {
                return error.Closed;
            }

            self.pos = pos + n;
        }
    }

    fn bufferedMessage(self: *Reader) !?[]u8 {
        const buf = self.buf;
        const pos = self.pos;
        const start = self.start;

        std.debug.assert(pos >= start);
        const unprocessed = buf[start..pos];

        if (unprocessed.len < 4) {
            self.ensureSpace(4 - unprocessed.len) catch unreachable;
            return null;
        }

        const msg_len = std.mem.readInt(u32, unprocessed[0..4], .little);

        const total_len = msg_len + 4;

        if (unprocessed.len < total_len) {
            try self.ensureSpace(total_len);
            return null;
        }

        self.start += total_len;
        return unprocessed[4..total_len];
    }

    fn ensureSpace(self: *Reader, space: usize) !void {
        const buf = self.buf;
        if (buf.len < space) {
            self.buf = try self.allocator.realloc(self.buf, space);
            return;
        }

        const start = self.start;
        const spare = buf.len - start;
        if (spare >= space) {
            return;
        }

        // copy unprocessed data to the beginning of
        // the buffer because there's not enough space
        const unprocessed = buf[start..self.pos];
        std.mem.copyForwards(u8, buf[0..unprocessed.len], unprocessed);
        self.pos = unprocessed.len;
    }
};

pub fn write(socket: posix.socket_t, msg: []const u8) !void {
    var buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &buf, @intCast(msg.len), .little);

    var vec = [2]posix.iovec_const{
        .{ .len = 4, .base = &buf },
        .{ .len = msg.len, .base = msg.ptr },
    };

    try writeAll(socket, &vec);
}

fn writeAll(socket: posix.socket_t, vec: []posix.iovec_const) !void {
    const timeout = posix.timeval{ .sec = 2, .usec = 500_000 };
    try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.SNDTIMEO, &std.mem.toBytes(timeout));

    var i: usize = 0;
    while (true) {
        var n = try posix.writev(socket, vec[i..]);
        while (n >= vec[i].len) {
            n -= vec[i].len;
            i += 1;

            if (i >= vec.len) {
                return;
            }
        }
        vec[i].base += n;
        vec[i].len -= n;
    }
}
