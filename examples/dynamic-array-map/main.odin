package main

import "core:fmt"

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	dynamic_array1 := [dynamic]int{}
	defer delete(dynamic_array1)
	//----------------------------------------
	append(&dynamic_array1, 1, 2, 3)
	//----------------------------------------
	fmt.println("dynamic array:", dynamic_array1)
	//----------------------------------------
	dynamic_array2 := [dynamic]string{}
	defer {
		// update defer if contain owned data like strings etc
		// for _, value in dynamic_array2 {
		// 	delete(value)
		// }
		delete(dynamic_array2)
	}
	//----------------------------------------
	append(&dynamic_array2, "1", "2", "3")
	//----------------------------------------
	fmt.println("dynamic array:", dynamic_array2)
	//----------------------------------------
	dynamic_map := make(map[string]string)
	defer {
		// update defer if contain owned data like strings etc
		// for _, value in dynamic_map {
		// 	delete(value)
		// }
		delete(dynamic_map)
	}
	//----------------------------------------
	dynamic_map["one"] = "1"
	dynamic_map["two"] = "2"
	dynamic_map["three"] = "3"
	//----------------------------------------
	fmt.println("dynamic map:", dynamic_map)
	//----------------------------------------
}

//------------------------------------------------------------
