package main

import "core:fmt"

foreign import static_lib "libmath.a"

foreign static_lib {
	add :: proc(a: i32, b: i32) -> i32 ---
	sub :: proc(a: i32, b: i32) -> i32 ---
}

main :: proc() {
	//----------------------------------------
	a: i32 = 5
	b: i32 = 3
	result: i32
	//----------------------------------------
	result = add(a, b)
	//----------------------------------------
	fmt.printfln("add(%d, %d) = %d", a, b, result)
	//----------------------------------------
	result = sub(a, b)
	//----------------------------------------
	fmt.printfln("sub(%d, %d) = %d", a, b, result)
	//----------------------------------------
}
