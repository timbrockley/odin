const std = @import("std");

extern fn add(a: i32, b: i32) i32;
extern fn sub(a: i32, b: i32) i32;

pub fn main() void {
    const a: i32 = 5;
    const b: i32 = 3;

    const result_add = add(a, b);
    const result_sub = sub(a, b);

    std.debug.print("add({}, {}) = {}\n", .{ a, b, result_add });
    std.debug.print("sub({}, {}) = {}\n", .{ a, b, result_sub });
}
