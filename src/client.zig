const std = @import("std");
const net = std.net;
const linux = std.os.linux;
const posix = std.posix;

const util = @import("util.zig");

const ADDR = "127.0.0.1";
const PORT = 8080;
const BUF_SIZE = 4;

pub fn main() !void {
    const addr = try net.Address.parseIp(ADDR, PORT);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const client = try posix.socket(addr.any.family, tpe, protocol);
    defer posix.close(client);

    try posix.connect(client, &addr.any, addr.getOsSockLen());

    try util.write(client, "hello");
    try util.write(client, "olleh");

    try posix.shutdown(client, .send);
}
