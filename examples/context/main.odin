package main

import "core:fmt"
import "core:mem"
import "core:mem/virtual"

//------------------------------------------------------------
// context used with current thread and directly called procedures
//------------------------------------------------------------
State :: struct {
	counter: int,
}
//------------------------------------------------------------
main :: proc() {
	//------------------------------------------------------------
	printLine()
	//------------------------------------------------------------
	state := State {
		counter = 1,
	}
	//------------------------------------------------------------
	context.user_ptr = &state
	context.user_index = 42
	//------------------------------------------------------------
	fmt.println("before:", state.counter)

	increment_counter()

	fmt.println("after: ", state.counter)
	//------------------------------------------------------------
	printLine()
	//------------------------------------------------------------
	values := make_data()
	fmt.println("back in main:")
	fmt.println("values:", values)

	mem.free_all(context.temp_allocator)
	fmt.println("values:", values)
	//------------------------------------------------------------
	fmt.println()
	//------------------------------------------------------------
	old_temp_allocator := context.temp_allocator
	//------------------------------------------------------------
	arena: virtual.Arena
	arena_alloc := virtual.arena_allocator(&arena)
	defer virtual.arena_destroy(&arena)
	//------------------------------------------------------------
	context.temp_allocator = arena_alloc
	//------------------------------------------------------------
	values = make_data()
	fmt.println("back in main:")
	fmt.println("values:", values)

	mem.free_all(context.temp_allocator)
	fmt.println("values:", values)
	//------------------------------------------------------------
	context.temp_allocator = old_temp_allocator
	//------------------------------------------------------------
	printLine()
	//------------------------------------------------------------
}
//------------------------------------------------------------
increment_counter :: proc() {
	//------------------------------------------------------------
	fmt.println("context.user_ptr:", context.user_ptr)
	fmt.println("context.user_index:", context.user_index)

	state := cast(^State)context.user_ptr

	fmt.println("inside:", state.counter)

	state.counter += 1
	//------------------------------------------------------------
}
//------------------------------------------------------------
make_data :: proc() -> []int {
	//------------------------------------------------------------
	values := make([]int, 5, context.temp_allocator)

	for i in 0 ..< len(values) {values[i] = (i + 1) * 10}

	fmt.println("inside make_data:")
	fmt.println("values:", values)

	return values
	//------------------------------------------------------------
}
//------------------------------------------------------------
printLine :: proc() {fmt.println(
		"--------------------------------------------------------------------------------",
	)}
//------------------------------------------------------------
