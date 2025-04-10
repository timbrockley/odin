package main

import "core:fmt"

//------------------------------------------------------------

main :: proc() {
	//----------------------------------------
	dynamicArray1 := [dynamic]int{}
	// defer delete(dynamicArray1) // optional as will be freed when out of scope
	//----------------------------------------
	append(&dynamicArray1, 1, 2, 3)
	//----------------------------------------
	fmt.println("dynamic array:", dynamicArray1)
	//----------------------------------------
	dynamicArray2 := [dynamic]string{}
	// defer delete(dynamicArray2) // optional as will be freed when out of scope
	//----------------------------------------
	append(&dynamicArray2, "1", "2", "3")
	//----------------------------------------
	fmt.println("dynamic array:", dynamicArray2)
	//----------------------------------------
	dynamicMap := map[string]string{}
	// defer delete(dynamicMap) // optional as will be freed when out of scope
	//----------------------------------------
	dynamicMap["one"] = "1"
	dynamicMap["two"] = "2"
	dynamicMap["three"] = "3"
	//----------------------------------------
	fmt.println("dynamic map:", dynamicMap)
	//----------------------------------------
}

//------------------------------------------------------------
