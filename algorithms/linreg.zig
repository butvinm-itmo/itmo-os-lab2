const std = @import("std");

pub fn LinReg(n: comptime_int) type {
    return struct {
        const Self = @This();

        m: f64,
        b: f64,

        pub fn fit(xs: @Vector(n, f64), ys: @Vector(n, f64)) Self {
            const sum_x = @reduce(.Add, xs);
            const sum_y = @reduce(.Add, ys);
            const sum_xx = @reduce(.Add, xs * xs);
            const sum_xy = @reduce(.Add, xs * ys);
            const m = (n * sum_xy - sum_x * sum_y) / (n * sum_xx - sum_x * sum_x);
            const b = (sum_y - m * sum_x) / n;
            return .{ .m = m, .b = b };
        }

        pub fn predict(self: Self, x: f64) f64 {
            return self.m * x + self.b;
        }
    };
}

const tolerance = 1e-10;

test {
    const n = 5;
    const model = LinReg(n).fit(
        @Vector(n, f64){ 1, 2, 3, 4, 5 },
        @Vector(n, f64){ 2, 3, 5, 7, 8 },
    );

    try std.testing.expectApproxEqRel(0.2, model.predict(0), tolerance);
    try std.testing.expectApproxEqRel(1.8, model.predict(1), tolerance);
    try std.testing.expectApproxEqRel(3.4, model.predict(2), tolerance);
    try std.testing.expectApproxEqRel(5, model.predict(3), tolerance);
    try std.testing.expectApproxEqRel(6.6, model.predict(4), tolerance);
    try std.testing.expectApproxEqRel(8.2, model.predict(5), tolerance);
    try std.testing.expectApproxEqRel(9.8, model.predict(6), tolerance);
    try std.testing.expectApproxEqRel(11.4, model.predict(7), tolerance);
    try std.testing.expectApproxEqRel(13, model.predict(8), tolerance);
    try std.testing.expectApproxEqRel(14.6, model.predict(9), tolerance);
}
