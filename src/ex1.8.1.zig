const std = @import("std");

const number_of_chopsticks = 5;
const number_of_philosophers = 5;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chopsticks: [number_of_chopsticks]Chopstick = .{.{ .held = false }} ** number_of_chopsticks;

    var threads: [number_of_philosophers]std.Thread = undefined;
    for (0..number_of_philosophers) |i| {
        threads[i] = try std.Thread.spawn(
            .{ .allocator = allocator },
            act,
            .{ .wait, &chopsticks, i, 10 },
        );
        std.time.sleep(7 * std.time.ns_per_ms);
    }

    for (threads) |thread| {
        thread.join();
    }
}

const ActType = enum {
    eat,
    wait,
};

fn act(actType: ActType, chopsticks: []Chopstick, name: usize, max_runs: usize) void {
    var rnd = std.rand.DefaultPrng.init(name * number_of_philosophers);
    var nextActType = actType;
    var run_count: usize = 0;
    _ = chopsticks;
    while (run_count < max_runs) : (run_count += 1) {
        std.debug.print("hello {} - {}\n", .{ name, run_count + 1 });
        const duration = 2 + rnd.random().int(usize) % 3;
        switch (nextActType) {
            .wait => {
                std.time.sleep(duration * std.time.ns_per_s);
                nextActType = .eat;
            },
            .eat => {
                // acquire 2 chopsticks
                std.time.sleep(duration * std.time.ns_per_s);
                // release chopsticks
                nextActType = .wait;
            },
        }
    }
}

const Chopstick = struct {
    // shared object
    held: bool,
};
