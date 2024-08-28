const std = @import("std");

const number_of_chopsticks = 5;
const number_of_philosophers = 5;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chopsticks: [number_of_chopsticks]Chopstick = .{.{ .held = false }} ** number_of_chopsticks;
    var chopstick_context = ChopstickContext{
        .locked = false,
        .chopsticks = &chopsticks,
        .number_available = number_of_chopsticks,
        .philosopher_eat_count = [1]usize{0} ** number_of_philosophers,
        .philosopher_wait_count = [1]usize{0} ** number_of_philosophers,
    };

    errdefer chopstick_context.print();

    var threads: [number_of_philosophers]std.Thread = undefined;
    for (0..number_of_philosophers) |i| {
        threads[i] = try std.Thread.spawn(
            .{ .allocator = allocator },
            act,
            .{ .wait, &chopstick_context, i, 10 },
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

fn act(actType: ActType, chopstick_context: *ChopstickContext, name: usize, max_runs: usize) void {
    var rnd = std.rand.DefaultPrng.init(name * number_of_philosophers);
    var nextActType = actType;
    var run_count: usize = 0;
    while (run_count < max_runs) {
        const duration = 2 + rnd.random().int(usize) % 3;
        switch (nextActType) {
            .wait => {
                std.time.sleep(duration * std.time.ns_per_s);
                nextActType = .eat;
            },
            .eat => {
                const pickup_result = chopstick_context.pickupChopsticks(name);
                if (pickup_result) |res| {
                    std.time.sleep(duration * std.time.ns_per_s);
                    while (!chopstick_context.putDownChopsticks(res, name)) {
                        std.time.sleep(100 * std.time.ns_per_ms);
                    }
                    nextActType = .wait;
                    run_count += 1;
                }
            },
        }
    }
}

const ChopstickContext = struct {
    locked: bool,
    chopsticks: []Chopstick,
    number_available: usize,
    philosopher_wait_count: [number_of_philosophers]usize,
    philosopher_eat_count: [number_of_philosophers]usize,

    const Self = @This();

    fn print(self: Self) void {
        std.debug.print("locked = {}\n", .{self.locked});
        std.debug.print("number_available = {}\n", .{self.number_available});
        std.debug.print("philosopher_wait_count, philosopher_eat_count\n", .{});
        for (self.philosopher_wait_count, self.philosopher_eat_count, 0..) |wait_count, eat_count, i| {
            std.debug.print("\t{}. wait = {} eat = {}\n", .{ i, wait_count, eat_count });
        }
    }

    // return null if operation was blocked
    // else return indices of the two chopsticks picked up
    fn pickupChopsticks(self: *Self, name: usize) ?[2]usize {
        // TODO - locked is a rubbish mutex, there's nothing to prevent you from checking it, then another thread altering it, then this thread altering it, need to replace with something atomic
        if (self.locked) {
            return null;
        }

        if (self.number_available < 2) {
            return null;
        }

        self.locked = true;
        defer self.locked = false;

        var count: usize = 0;
        var result: [2]usize = undefined;
        for (self.chopsticks, 0..) |*chopstick, i| {
            if (chopstick.held) {
                continue;
            }
            chopstick.*.held = true;
            result[count] = i;
            count += 1;
            self.*.number_available -= 1;
            self.*.philosopher_eat_count[name] += 1;
            if (count == 2) {
                return result;
            }
        }

        unreachable;
    }

    // return false if operation was blocked, else return true
    fn putDownChopsticks(self: *Self, indices: [2]usize, name: usize) bool {
        // TODO - locked is a rubbish mutex, there's nothing to prevent you from checking it, then another thread altering it, then this thread altering it, need to replace with something atomic
        if (self.locked) {
            return false;
        }

        self.locked = true;
        defer self.locked = false;

        for (indices) |idx| {
            self.*.chopsticks[idx].held = false;
            self.*.number_available += 1;
        }
        self.*.philosopher_wait_count[name] += 1;
        return true;
    }
};

const Chopstick = struct {
    held: bool,
};
