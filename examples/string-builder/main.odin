package main

import "core:fmt"
import "core:strings"

main :: proc() {
	//----------------------------------------
	lines := []string{"line 1", "line 2", "line 3"}
	//----------------------------------------
	buffer := strings.builder_make()
	// defer strings.builder_destroy(&buffer)
	//----------------------------------------
	for line, _ in lines {
		//----------------------------------------
		strings.write_string(&buffer, fmt.tprintf("%s\n", line))
		//----------------------------------------
	}
	//----------------------------------------
	string := strings.to_string(buffer)
	//----------------------------------------
	fmt.print(string)
	//----------------------------------------
}
