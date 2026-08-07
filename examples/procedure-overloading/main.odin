package main

import "core:fmt"

add_ints :: proc(a, b: int) -> int {
	return a + b
}

add_floats :: proc(a, b: f32) -> f32 {
	return a + b
}

add :: proc {
	add_ints,
	add_floats,
}

main :: proc() {
	x := add(1, 3)
	y := add(1.5, 2.5)

	fmt.println(x)
	fmt.println(y)
}
