package main

import "core:fmt"

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	dynamic_array := make([dynamic]int, 0, 0)
	// defer delete(dynamic_array) // optional as will be freed when out of scope
	//----------------------------------------
	append(&dynamic_array, 1, 2, 3)
	//----------------------------------------
	fmt.println("dynamic array:", dynamic_array)
	//----------------------------------------
	dynamic_map := map[string]string{}
	// defer delete(dynamic_map) // optional as will be freed when out of scope
	//----------------------------------------
	dynamic_map["one"] = "1"
	dynamic_map["two"] = "2"
	dynamic_map["three"] = "3"
	//----------------------------------------
	fmt.println("dynamic map:", dynamic_map)
	//----------------------------------------
}

//------------------------------------------------------------
