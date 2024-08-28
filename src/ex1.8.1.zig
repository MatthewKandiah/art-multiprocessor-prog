const std = @import("std");

const number_of_chopsticks = 5;
const number_of_philosophers = 5;
const number_of_eats = 10;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var chopsticks: [number_of_chopsticks]Chopstick = .{.{ .held = false }} ** number_of_chopsticks;
    var chopstick_context = ChopstickContext{
        .mutex = .{},
        .chopsticks = &chopsticks,
        .number_available = number_of_chopsticks,
        .philosopher_eat_count = [1]usize{0} ** number_of_philosophers,
        .philosopher_wait_count = [1]usize{0} ** number_of_philosophers,
    };

    var threads: [number_of_philosophers]std.Thread = undefined;
    for (0..number_of_philosophers) |i| {
        threads[i] = try std.Thread.spawn(
            .{ .allocator = allocator },
            act,
            .{ .wait, &chopstick_context, i, number_of_eats },
        );
    }

    for (threads) |thread| {
        thread.join();
    }

    std.debug.print("Finished!\n", .{});
    chopstick_context.print();
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
        const duration_ns = duration * std.time.ns_per_ms;
        switch (nextActType) {
            .wait => {
                std.time.sleep(duration * std.time.ns_per_s);
                nextActType = .eat;
            },
            .eat => {
                const pickup_result = chopstick_context.pickupChopsticks(name);
                if (pickup_result) |res| {
                    std.time.sleep(duration * duration_ns);
                    while (!chopstick_context.putDownChopsticks(res, name)) {
                        std.time.sleep(duration_ns);
                    }
                    nextActType = .wait;
                    run_count += 1;
                }
            },
        }
    }
}

const ChopstickContext = struct {
    mutex: std.Thread.Mutex,
    chopsticks: []Chopstick,
    number_available: usize,
    philosopher_wait_count: [number_of_philosophers]usize,
    philosopher_eat_count: [number_of_philosophers]usize,

    const Self = @This();

    fn print(self: Self) void {
        std.debug.print("number_available = {}\n", .{self.number_available});
        std.debug.print("philosopher_wait_count, philosopher_eat_count\n", .{});
        for (self.philosopher_wait_count, self.philosopher_eat_count, 0..) |wait_count, eat_count, i| {
            std.debug.print("\t{}. wait = {} eat = {}\n", .{ i, wait_count, eat_count });
        }
    }

    // return null if operation was blocked
    // else return indices of the two chopsticks picked up
    fn pickupChopsticks(self: *Self, name: usize) ?[2]usize {
        if (self.number_available < 2) {
            return null;
        }

        if (self.mutex.tryLock()) {
            defer self.mutex.unlock();

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
                if (count == 2) {
                    self.*.philosopher_eat_count[name] += 1;
                    return result;
                }
            }
        }
        return null;
    }

    // return false if operation was blocked, else return true
    fn putDownChopsticks(self: *Self, indices: [2]usize, name: usize) bool {
        if (self.mutex.tryLock()) {
            defer self.mutex.unlock();

            for (indices) |idx| {
                self.*.chopsticks[idx].held = false;
                self.*.number_available += 1;
            }
            self.*.philosopher_wait_count[name] += 1;
            return true;
        } else {
            return false;
        }
    }
};

const Chopstick = struct {
    held: bool,
};
