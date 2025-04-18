package main

import "core:fmt"

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	dynamic_array1 := [dynamic]int{}
	// defer delete(dynamic_array1) // optional as will be freed when out of scope
	//----------------------------------------
	append(&dynamic_array1, 1, 2, 3)
	//----------------------------------------
	fmt.println("dynamic array:", dynamic_array1)
	//----------------------------------------
	dynamic_array2 := [dynamic]string{}
	// defer delete(dynamic_array2) // optional as will be freed when out of scope
	//----------------------------------------
	append(&dynamic_array2, "1", "2", "3")
	//----------------------------------------
	fmt.println("dynamic array:", dynamic_array2)
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
