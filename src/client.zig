const std = @import("std");
const net = std.net;
const linux = std.os.linux;
const posix = std.posix;

const util = @import("util.zig");

const ADDR = "127.0.0.1";
const PORT = 8080;
const BUF_SIZE = 4;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const addr = try net.Address.parseIp(ADDR, PORT);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const client = try posix.socket(addr.any.family, tpe, protocol);
    defer posix.close(client);

    try posix.connect(client, &addr.any, addr.getOsSockLen());

    try util.write(client, "hello");

    try posix.shutdown(client, .send);

    var reader = try util.Reader.init(&allocator, client);
    defer reader.deinit();

    const res = try reader.read();
    std.debug.print("{s}\n", .{res});
}
