const std = @import("std");
const posix = std.posix;

const BUF_SIZE = 2;

pub fn read(allocator: *const std.mem.Allocator, socket: posix.socket_t) !std.ArrayList(u8) {
    var string = std.ArrayList(u8).init(allocator.*);
    var buf: [BUF_SIZE]u8 = undefined;

    while (true) {
        const n = try posix.read(socket, &buf);
        if (n == 0) {
            break;
        }

        try string.appendSlice(buf[0..n]);
    }

    return string;
}

pub fn write(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        const start = pos;
        const end = @min(pos + BUF_SIZE, msg.len);
        const n = try posix.write(socket, msg.ptr[start..end]);
        if (n == 0) {
            return error.Closed;
        }
        pos += n;
    }
}
