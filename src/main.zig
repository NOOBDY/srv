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
    _ = allocator;

    const addr = try net.Address.resolveIp(ADDR, PORT);

    const tpe: u32 = posix.SOCK.STREAM | posix.SOCK.NONBLOCK;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(addr.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &addr.any, addr.getOsSockLen());
    try posix.listen(listener, 128);

    var polls: [4096]posix.pollfd = undefined;
    polls[0] = .{
        .fd = listener,
        .events = posix.POLL.IN,
        .revents = 0,
    };
    var poll_count: usize = 1;

    while (true) {
        var active = polls[0 .. poll_count + 1];

        // -1 for infinite timeout
        _ = try posix.poll(active, -1);

        if (active[0].revents != 0) {
            const socket = try posix.accept(listener, null, null, posix.SOCK.NONBLOCK);

            polls[poll_count] = .{
                .fd = socket,
                .revents = 0,
                .events = posix.POLL.IN,
            };

            poll_count += 1;
        }

        var i: usize = 1;
        while (i < active.len) {
            const polled = active[i];

            const revents = polled.revents;
            if (revents == 0) {
                i += 1;
                continue;
            }

            var closed = false;

            if (revents & posix.POLL.IN == posix.POLL.IN) {
                var buf: [4096]u8 = undefined;
                const read = posix.read(polled.fd, &buf) catch 0;
                if (read == 0) {
                    closed = true;
                } else {
                    std.debug.print("[{d}]: {s}\n", .{ polled.fd, buf[0..read] });
                }
            }

            if (closed or (revents & posix.POLL.HUP == posix.POLL.HUP)) {
                posix.close(polled.fd);

                const last_index = active.len - 1;
                active[i] = active[last_index];
                active = active[0..last_index];
                poll_count -= 1;
            } else {
                i += 1;
            }
        }
    }
}
