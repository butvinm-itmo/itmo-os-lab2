const std = @import("std");
const linreg = @import("linreg");

pub fn main() !void {
    const n = 5;
    const model = linreg.LinReg(n).fit(
        @Vector(n, f64){ 1, 2, 3, 4, 5 },
        @Vector(n, f64){ 2, 3, 5, 7, 8 },
    );
    std.debug.print("{d}\n", .{model.predict(0)});
}
