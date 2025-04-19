package main

import "core:fmt"
import "core:testing"

add :: proc(a: int, b: int) -> int {
	return a + b
}

@(test)
add_test :: proc(t: ^testing.T) {
	result := add(5, 3)
	testing.expect_value(t, result, 8)
}

main :: proc() {
	//---- ------------------------------------
	a, b := 1, 3
	//----------------------------------------
	result := add(a, b)
	//----------------------------------------
	fmt.printfln("add(%d, %d) = %d", a, b, result)
	//----------------------------------------
}
