package main

/*
	code inspired by Karl Zylinski (https://github.com/karl-zylinski)
*/

import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"

main :: proc() {
	//----------------------------------------
	{
		arena_mem, err := make([]u8, 1 * mem.Megabyte)
		arena: mem.Arena
		mem.arena_init(&arena, arena_mem)

		fmt.printfln("Arena starts at address: %p (%i)", &arena_mem[0], &arena_mem[0])

		arena_alloc := mem.arena_allocator(&arena)
		dyn_arr := make([dynamic]int, arena_alloc)
		append(&dyn_arr, 7)
		fmt.println(&dyn_arr[0], &dyn_arr[0])

		for i in 0 ..< 9999 {
			append(&dyn_arr, rand.int_max(100000))
		}

		fmt.println(&dyn_arr[0], &dyn_arr[0])

		delete(arena_mem)
	}
	//----------------------------------------
	{
		arena: virtual.Arena
		arena_err := virtual.arena_init_static(&arena, 4096) // 4096 bytes

		assert(arena_err == nil)

		arena_alloc := virtual.arena_allocator(&arena)

		dyn_arr := make([dynamic]int, arena_alloc)
		append(&dyn_arr, 7)
		fmt.println("After 1 append to dynamic array, address of first element is:", &dyn_arr[0])

		for i in 0 ..< 9999 {
			append(&dyn_arr, rand.int_max(100000))
		}

		fmt.println(
			"After 10000 appends to dynamic array, address of first element is:",
			&dyn_arr[0],
		)

		virtual.arena_destroy(&arena)
	}
	//----------------------------------------
	{
		arena: virtual.Arena
		arena_alloc := virtual.arena_allocator(&arena)

		dyn_arr := make([dynamic]int, arena_alloc)

		append(&dyn_arr, 7)
		fmt.println("After 1 append to dynamic array, address of first element is:", &dyn_arr[0])

		for i in 0 ..< 9999 {
			append(&dyn_arr, rand.int_max(100000))
		}

		fmt.println(
			"After 10000 appends to dynamic array, address of first element is:",
			&dyn_arr[0],
		)

		virtual.arena_destroy(&arena)
	}
	//----------------------------------------
	{
		arena: virtual.Arena
		arena_alloc := virtual.arena_allocator(&arena)

		useAllocator(arena_alloc)

		virtual.arena_destroy(&arena)
	}
	//----------------------------------------
}

//------------------------------------------------------------

useAllocator :: proc(arena_alloc: mem.Allocator) {

	dyn_arr := make([dynamic]int, arena_alloc)

	append(&dyn_arr, 7)

	fmt.println("After 1 append to dynamic array, address of first element is:", &dyn_arr[0])

	for i in 0 ..< 9999 {
		append(&dyn_arr, rand.int_max(100000))
	}

	fmt.println("After 10000 appends to dynamic array, address of first element is:", &dyn_arr[0])
}

//------------------------------------------------------------
