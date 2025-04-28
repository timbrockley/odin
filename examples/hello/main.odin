package main

import "core:fmt"

main :: proc() {
	fmt.println("stdout: hello world")
	fmt.eprintln("stderr: hello world")
}
