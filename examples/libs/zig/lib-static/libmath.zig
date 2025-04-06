//--------------------------------------------------------------------------------

const std = @import("std");

//--------------------------------------------------------------------------------

test "test add function" {
    const result = add(3, 2);
    try std.testing.expect(result == 5);
}

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

//--------------------------------------------------------------------------------

test "test sub function" {
    const result = sub(5, 2);
    try std.testing.expect(result == 3);
}

export fn sub(a: i32, b: i32) i32 {
    return a - b;
}

//--------------------------------------------------------------------------------
