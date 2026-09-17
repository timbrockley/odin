//------------------------------------------------------------

package main

import "core:fmt"
import "core:sync"

//------------------------------------------------------------
once: sync.Once
value: int
//------------------------------------------------------------
initialize :: proc() {
	fmt.println("initialising...")
	value = 42
}
//------------------------------------------------------------
get_value :: proc() -> int {
	sync.once_do(&once, initialize)
	return value
}
//------------------------------------------------------------
main :: proc() {
	fmt.println(get_value())
	fmt.println(get_value())
}
//------------------------------------------------------------
