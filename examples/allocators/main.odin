package main

import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:mem/virtual"
import "core:strings"

//------------------------------------------------------------
main :: proc() {
	//----------------------------------------
	{
		// stack allocated with fixed size !!! USE WITH CAUTION !!!

		buffer: [256 * mem.Kilobyte]byte

		arena: virtual.Arena
		err := virtual.arena_init_buffer(&arena, buffer[:])
		if err != nil {fmt.panicf("%v", err)}

		arena_alloc := virtual.arena_allocator(&arena)

		err = useAllocator(arena_alloc)
		if err != nil {fmt.panicf("%v", err)}
	}
	//----------------------------------------
	{
		// heap allocated with fixed size !!! USE WITH CAUTION !!!

		arena: virtual.Arena
		err := virtual.arena_init_static(&arena, 256 * mem.Kilobyte)
		if err != nil {fmt.panicf("%v", err)}

		arena_alloc := virtual.arena_allocator(&arena)

		err = useAllocator(arena_alloc)
		if err != nil {fmt.panicf("%v", err)}

		virtual.arena_destroy(&arena)
	}
	//----------------------------------------
	{
		// heap allocated with initial size but will grow when required

		arena: virtual.Arena
		err := virtual.arena_init_growing(&arena, 256 * mem.Kilobyte)
		if err != nil {fmt.panicf("%v", err)}

		arena_alloc := virtual.arena_allocator(&arena)

		err = useAllocator(arena_alloc)
		if err != nil {fmt.panicf("%v", err)}

		virtual.arena_destroy(&arena)
	}
	//----------------------------------------
	{
		// heap allocated with dynamic allocation

		arena: virtual.Arena
		arena_alloc := virtual.arena_allocator(&arena)

		err := useAllocator(arena_alloc)
		if err != nil {fmt.panicf("%v", err)}

		virtual.arena_destroy(&arena)
	}
	//----------------------------------------
	{
		// tracking allocator

		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}

		string1 := strings.clone("string1")
		string2 := strings.clone("string2")
		string3 := strings.clone("string3")

		delete(string1)
		delete(string2)
		// delete(string2) // bad free if freed more than once
		// delete(string3) // not freed if commented out (and above not commented out)
	}
	//----------------------------------------
}
//------------------------------------------------------------
useAllocator :: proc(arena_alloc: mem.Allocator) -> mem.Allocator_Error {

	dyn_arr := make([dynamic]int, arena_alloc)

	for i in 0 ..< 10000 {
		_, err := append(&dyn_arr, rand.int_max(100000))
		if err != nil {return err}
	}

	fmt.printfln(
		"After %d appends to dynamic array, address of first element is: %v",
		len(dyn_arr),
		&dyn_arr[0],
	)

	return nil
}
//------------------------------------------------------------
