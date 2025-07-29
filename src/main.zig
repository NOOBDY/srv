const std = @import("std");
const net = std.net;
const linux = std.os.linux;
const posix = std.posix;

const util = @import("util.zig");

const ADDR = "127.0.0.1";
const PORT = 8080;
const POOL_SIZE = 8;

const Client = struct {
    allocator: *const std.mem.Allocator,
    socket: posix.socket_t,
    addr: std.net.Address,

    fn handle(self: Client) void {
        self._handle() catch |err| switch (err) {
            error.Closed => {},
            else => std.debug.print("{any} client handle error: {}\n", .{ self.addr, err }),
        };
    }

    fn _handle(self: Client) !void {
        const socket = self.socket;

        defer posix.close(socket);

        std.debug.print("{} connected\n", .{self.addr});

        var reader = try util.Reader.init(self.allocator, socket);
        defer reader.deinit();

        while (true) {
            const content = try reader.read();

            std.debug.print("{s}\n", .{content});
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }).init;
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var pool: std.Thread.Pool = undefined;
    try std.Thread.Pool.init(&pool, .{
        .allocator = allocator,
        .n_jobs = POOL_SIZE,
    });
    defer pool.deinit();

    const addr = try net.Address.resolveIp(ADDR, PORT);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(addr.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &addr.any, addr.getOsSockLen());
    try posix.listen(listener, 128);

    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            std.debug.print("error accept: {}\n", .{err});
            continue;
        };

        const client = Client{ .allocator = &allocator, .socket = socket, .addr = client_address };
        try pool.spawn(Client.handle, .{client});
    }
}
