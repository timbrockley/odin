const std = @import("std");

pub fn main() !void {
    const lib_path = "./libmath.so";

    var lib = try std.DynLib.open(lib_path);
    defer lib.close();

    const add = lib.lookup(*const fn (i32, i32) i32, "add") orelse return error.NoSuchFunction;
    const sub = lib.lookup(*const fn (i32, i32) i32, "sub") orelse return error.NoSuchFunction;

    const a: i32 = 5;
    const b: i32 = 3;

    const result_add = add(a, b);
    const result_sub = sub(a, b);

    std.debug.print("add({}, {}) = {}\n", .{ a, b, result_add });
    std.debug.print("sub({}, {}) = {}\n", .{ a, b, result_sub });
}
