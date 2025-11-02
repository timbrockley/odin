#+feature dynamic-literals

package main

import "core:encoding/json"
import "core:fmt"
import "core:mem/virtual"

//--------------------------------------------------------------------------------

Source :: struct {
	integer: int,
	string:  string,
}

Target :: struct {
	integer: int,
	byte:    u8,
}

//--------------------------------------------------------------------------------

main :: proc() {
	//--------------------------------------------------------------------------------
	source := Source {
		integer = 5,
		string  = "string_value",
	}
	//----------------------------------------
	target: Target
	//--------------------------------------------------------------------------------
	{
		//----------------------------------------
		bytes, errMarshal := json.marshal(source)
		defer delete(bytes)
		//----------------------------------------
		if errMarshal != nil {
			fmt.println("Marshal_Error:", errMarshal)
		} else {
			fmt.println(source)
		}
		//----------------------------------------
		errUnmarshal := json.unmarshal(bytes, &target)
		//----------------------------------------
		if errUnmarshal != nil {
			fmt.println("Unmarshal_Error:", errUnmarshal)
		} else {
			fmt.println(target)
		}
		//----------------------------------------
	}
	//--------------------------------------------------------------------------------
	source.integer = 10
	//--------------------------------------------------------------------------------
	arena: virtual.Arena
	arena_allocator := virtual.arena_allocator(&arena)
	defer virtual.arena_destroy(&arena)
	//----------------------------------------
	context.allocator = arena_allocator
	//--------------------------------------------------------------------------------
	{
		//----------------------------------------
		bytes, errMarshal := json.marshal(source)
		//----------------------------------------
		if errMarshal != nil {
			fmt.println("Marshal_Error:", errMarshal)
		} else {
			fmt.println(source)
		}
		//----------------------------------------
		errUnmarshal := json.unmarshal(bytes, &target)
		//----------------------------------------
		if errUnmarshal != nil {
			fmt.println("Unmarshal_Error:", errUnmarshal)
		} else {
			fmt.println(target)
		}
		//----------------------------------------
	}
	//--------------------------------------------------------------------------------
	source.integer = 20
	//--------------------------------------------------------------------------------
	{
		//----------------------------------------
		bytes, errMarshal := json.marshal(source, {}, arena_allocator)
		if errMarshal != nil {
			fmt.println("Marshal_Error:", errMarshal)
		} else {
			fmt.println(source)
		}
		//----------------------------------------
		errUnmarshal := json.unmarshal(bytes, &target, json.DEFAULT_SPECIFICATION, arena_allocator)
		if errUnmarshal != nil {
			fmt.println("Unmarshal_Error:", errUnmarshal)
		} else {
			fmt.println(target)
		}
		//----------------------------------------
	}
	//--------------------------------------------------------------------------------
}

//--------------------------------------------------------------------------------
