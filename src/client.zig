const std = @import("std");
const net = std.net;
const linux = std.os.linux;
const posix = std.posix;

const util = @import("util.zig");

const ADDR = "127.0.0.1";
const PORT = 8080;
const BUF_SIZE = 4;

const THREAD_COUNT = 64;

fn _worker(addr: net.Address, tpe: u32, protocol: comptime_int) !void {
    const client = try posix.socket(addr.any.family, tpe, protocol);
    defer posix.close(client);

    try posix.connect(client, &addr.any, addr.getOsSockLen());

    try util.write(client, "hello");
    std.Thread.sleep(1 * std.time.ns_per_s);
    try util.write(client, "olleh");

    try posix.shutdown(client, .send);
}

fn worker(addr: net.Address, tpe: u32, protocol: comptime_int) void {
    _worker(addr, tpe, protocol) catch |err| {
        std.debug.print("{}", .{err});
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var pool: std.Thread.Pool = undefined;
    try std.Thread.Pool.init(&pool, .{
        .allocator = allocator,
        .n_jobs = THREAD_COUNT,
    });
    defer pool.deinit();

    const addr = try net.Address.parseIp(ADDR, PORT);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;

    for (0..THREAD_COUNT) |_| {
        try std.Thread.Pool.spawn(&pool, worker, .{ addr, tpe, protocol });
    }
}
